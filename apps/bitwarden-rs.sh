#!/bin/bash

# T&M Hansson IT AB © - 2020, https://www.hanssonit.se/

true
SCRIPT_NAME="Bitwarden RS"
SCRIPT_EXPLAINER="Bitwarden RS is an unofficial Bitwarden server API implementation in Rust.
It has less hardware requirements and therefore runs on nearly any hardware."
# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh || source <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Check if root
root_check

# Check if bitwarden_rs is already installed
if [ -d /home/bitwarden_rs ] || docker ps -a --format '{{.Names}}' | grep -Eq "bitwarden_rs";
then
    msg_box "It seems like you have already installed Bitwarden RS.
You cannot install it again because you would loose all your data and passwords.

If you are certain that you definitely want to delete Bitwarden RS and all \
its data to be able to reinstall it, you can execute the following commands:

'sudo docker stop bitwarden_rs'
'sudo docker rm bitwarden_rs'
'sudo rm -r /home/bitwarden_rs'"
    exit 1
fi

# Ask for installing
install_popup "$SCRIPT_NAME"

# Second info box
msg_box "Since it's unofficial, you need to really trust the maintainer of the project to install it:
https://github.com/dani-garcia/bitwarden_rs
You never know what could hide in an unofficial release.

It's always is recommended to install the official Bitwarden by running:
sudo bash /var/scripts/menu.sh --> Additional Apps --> Bitwarden --> Bitwarden

Please only report issues to https://github.com/dani-garcia/bitwarden_rs"

# Show a second waring
msg_box "Are you really sure?

It's always is recommended to install the official Bitwarden by running:
sudo bash /var/scripts/menu.sh --> Additional Apps --> Bitwarden

You will be offered to abort in the next step"

# Let the user cancel
if ! yesno_box_yes "Are you really sure you want to install $SCRIPT_NAME?"
then
    exit
fi

# Ask for domain
SUBDOMAIN=$(input_box_flow "Please enter the Domain that you want to use for Bitwarden RS.")

# curl the lib another time to get the correct https_conf
# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh || source <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)

# Inform the user
msg_box "Before continuing, please make sure that you have you have \
edited the DNS settings for $SUBDOMAIN, and opened port 80 and 443 \
directly to this servers IP. A full exstensive guide can be found here:
https://www.techandme.se/open-port-80-443

This can be done automatically if you have UPNP enabled in your firewall/router.
You will be offered to use UPNP in the next step.

PLEASE NOTE:
Using other ports than the default 80 and 443 is not supported, \
though it may be possible with some custom modification:
https://help.nextcloud.com/t/domain-refused-to-connect-collabora/91303/17"

# Ask for UPNP
if yesno_box_no "Do you want to use UPNP to open port 80 and 443?"
then
    unset FAIL
    open_port 80 TCP
    open_port 443 TCP
    cleanup_open_port
fi

# Check if $SUBDOMAIN exists and is reachable
print_text_in_color "$ICyan" "Checking if $SUBDOMAIN exists and is reachable..."
domain_check_200 "$SUBDOMAIN"

# Check open ports with NMAP
check_open_port 80 "$SUBDOMAIN"
check_open_port 443 "$SUBDOMAIN"

# Install Apache2
install_if_not apache2

# Enable Apache2 module's
a2enmod proxy
a2enmod proxy_wstunnel
a2enmod proxy_http
a2enmod ssl
a2enmod headers
a2enmod remoteip

# Only add TLS 1.3 on Ubuntu later than 20.04
if version 20.04 "$DISTRO" 20.04.10
then
    TLS13="+TLSv1.3"
fi

if [ -f "$HTTPS_CONF" ]
then
    a2dissite "$SUBDOMAIN.conf"
    rm -f "$HTTPS_CONF"
fi

if [ ! -f "$HTTPS_CONF" ];
then
    cat << HTTPS_CREATE > "$HTTPS_CONF"
<VirtualHost *:443>
    ServerName $SUBDOMAIN:443
    SSLCertificateChainFile $CERTFILES/$SUBDOMAIN/chain.pem
    SSLCertificateFile $CERTFILES/$SUBDOMAIN/cert.pem
    SSLCertificateKeyFile $CERTFILES/$SUBDOMAIN/privkey.pem
    SSLOpenSSLConfCmd DHParameters $DHPARAMS_SUB

    # Intermediate configuration
    SSLEngine               on
    SSLCompression          off
    SSLProtocol             -all +TLSv1.2 $TLS13
    SSLCipherSuite          ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384 
    SSLHonorCipherOrder     off
    SSLSessionTickets       off
    ServerSignature         off

    # Logs
    LogLevel warn
    CustomLog ${APACHE_LOG_DIR}/access.log combined
    ErrorLog ${APACHE_LOG_DIR}/error.log

    # Just in case - see below
    SSLProxyEngine On
    SSLProxyVerify None
    SSLProxyCheckPeerCN Off
    SSLProxyCheckPeerName Off
    # contra mixed content warnings
    RequestHeader set X-Forwarded-Proto "https"
    RewriteEngine On
    RewriteCond %{HTTP:Upgrade} =websocket [NC]
    RewriteRule /notifications/hub(.*) ws://127.0.0.1:3012/$1 [P,L]
    # basic proxy settings
    ProxyRequests off
    ProxyPassMatch (.*)(\/websocket)$ "ws://127.0.0.1:1024/$1$2"
    ProxyPass / "http://127.0.0.1:1024/"
    ProxyPassReverse / "http://127.0.0.1:1024/"
    # Extra (remote) headers
    RequestHeader set X-Real-IP %{REMOTE_ADDR}s
    Header set X-XSS-Protection "1; mode=block"
    Header set Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
    Header set X-Content-Type-Options nosniff
    Header set Content-Security-Policy "frame-ancestors 'self'"
</VirtualHost>
HTTPS_CREATE

    if [ -f "$HTTPS_CONF" ];
    then
        print_text_in_color "$IGreen" "$HTTPS_CONF was successfully created."
        sleep 1
    else
        print_text_in_color "$IRed" "Unable to create vhost, exiting..."
        print_text_in_color "$IRed" "Please report this issue here $ISSUES"
        exit 1
    fi
fi

# Install certbot (Let's Encrypt)
install_certbot

# Generate certs and  auto-configure  if successful
if generate_cert  "$SUBDOMAIN"
then
    # Generate DHparams chifer
    if [ ! -f "$DHPARAMS_SUB" ]
    then
        openssl dhparam -dsaparam -out "$DHPARAMS_SUB" 4096
    fi
    print_text_in_color "$IGreen" "Certs are generated!"
    a2ensite "$SUBDOMAIN.conf"
    restart_webserver
else
    # remove settings to be able to start over again
    rm -f "$HTTPS_CONF"
    last_fail_tls "$SCRIPTS"/apps/tmbitwarden.sh
    exit 1
fi

# Install docker
install_docker

# Create dir for Bitwarden RS
mkdir -p /home/bitwarden_rs
chown nobody -R /home/bitwarden_rs
chmod -R 0770 /home/bitwarden_rs

# Generate admin password
ADMIN_PASS=$(gen_passwd "$SHUF" "A-Za-z0-9")

# Install docker-container
docker pull bitwardenrs/server:latest
docker run -d --name bitwarden_rs \
  --user nobody \
  -e ADMIN_TOKEN="$ADMIN_PASS" \
  -e SIGNUPS_VERIFY=true \
  -e DOMAIN="https://$SUBDOMAIN" \
  -e SIGNUPS_ALLOWED=false \
  -p 1024:1024 \
  -e ROCKET_PORT=1024 \
  -e WEBSOCKET_ENABLED=true \
  -p 3012:3012 \
  -e LOG_FILE=/data/bitwarden.log \
  -e LOG_LEVEL=warn \
  -v /home/bitwarden_rs/:/data/ \
  -v /etc/timezone:/etc/timezone:ro \
  -v /etc/localtime:/etc/localtime:ro \
  --restart always \
  bitwardenrs/server:latest

# Add prune command
add_dockerprune

# Inform about fail2ban
msg_box "We will now set up fail2ban for you.
You can unban ip addresses by executing the following command:
sudo fail2ban-client set bitwarden_rs unbanip XX.XX.XX.XX
sudo fail2ban-client set bitwarden_rs-admin unbanip XX.XX.XX.XX"

# Install fail2ban
install_if_not fail2ban
systemctl stop fail2ban

# Create all needed files
# Bitwarden RS conf
cat << BW_CONF > /etc/fail2ban/filter.d/bitwarden_rs.local
[INCLUDES]
before = common.conf

[Definition]
failregex = ^.*Username or password is incorrect\. Try again\. IP: <ADDR>\. Username:.*$
ignoreregex =
BW_CONF

# Bitwarden RS jail
cat << BW_JAIL_CONF > /etc/fail2ban/jail.d/bitwarden_rs.local
[bitwarden_rs]
enabled = true
port = 80,443,8081
filter = bitwarden_rs
action = iptables-allports[name=bitwarden_rs]
logpath = /home/bitwarden_rs/bitwarden.log
maxretry = 20
bantime = 1209600
findtime = 1800
ignoreip = 127.0.0.1/8 192.168.0.0/16 172.16.0.0/12 10.0.0.0/8
BW_JAIL_CONF

# bitwarden_rs-admin conf
cat << BWA_CONF > /etc/fail2ban/filter.d/bitwarden_rs-admin.local
[INCLUDES]
before = common.conf

[Definition]
failregex = ^.*Invalid admin token\. IP: <ADDR>.*$
ignoreregex =
BWA_CONF

# bitwarden_rs-admin jail
cat << BWA_JAIL_CONF > /etc/fail2ban/jail.d/bitwarden_rs-admin.local
[bitwarden_rs-admin]
enabled = true
port = 80,443
filter = bitwarden_rs-admin
action = iptables-allports[name=bitwarden_rs]
logpath = /home/bitwarden_rs/bitwarden.log
maxretry = 5
bantime = 1209600
findtime = 1800
ignoreip = 127.0.0.1/8 192.168.0.0/16 172.16.0.0/12 10.0.0.0/8
BWA_JAIL_CONF

start_if_stopped fail2ban
countdown "Waiting for fail2ban to start... " 5
check_command fail2ban-client reload

while :
do
    # Inform the user
    msg_box "Bitwarden_rs with fail2ban have been sucessfully installed! 
Please visit https://$SUBDOMAIN/admin to manage all your settings.

Attention! Please note down the password for the admin panel: $ADMIN_PASS
Otherwise you will not have access to your Bitwarden_rs installation and have to reinstall it completely!

It is highly recommended to configure and test the smtp settings for mails first.
Then, if it works, you can easily invite all your user with an e-mail address from this admin-panel.
(You have to click on users in the top-panel)

Please remember to report issues only to https://github.com/dani-garcia/bitwarden_rs"

    # Ask for password
    if yesno_box_no "Do you have the admin password now and know how to access the admin-panel?"
    then
        break
    fi
done

exit
