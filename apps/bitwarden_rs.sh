#!/bin/bash

# T&M Hansson IT AB © - 2020, https://www.hanssonit.se/

# shellcheck disable=2034,2059
true

# shellcheck source=lib.sh
. <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)

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
    msg_box "It seems like you have already installed Bitwarden_rs.
You cannot install it again because you would loose all your data.

If you are certain that you definitely want to delete Bitwarden_rs and all 
its data to be able to reinstall it, you can execute the following commands:

'sudo docker stop bitwarden_rs'
'sudo docker rm bitwarden_rs'
'sudo rm -r /home/bitwarden_rs'"
    exit 1
fi

# Inform what bitwarden_rs is
msg_box "Bitwarden_rs is an unofficial Bitwarden server API implementation in Rust.

It has less hardware requirements and runs on nearly any hardware.
For company usecase it is recommended to install the official Bitwarden.

Please report issues only to https://github.com/dani-garcia/bitwarden_rs"

if [[ "no" == $(ask_yes_or_no "Do you want to install Bitwarden_rs?") ]]
then
    exit
fi

SUBDOMAIN=$(whiptail --title "T&M Hansson IT - Bitwarden_rs" --inputbox "Please enter the Domain that you want to use for Bitwarden_rs." "$WT_HEIGHT" "$WT_WIDTH" 3>&1 1>&2 2>&3)

# curl the lib another time to get the correct https_conf
# shellcheck source=lib.sh
. <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)

msg_box "Please make sure that you have you have edited the dns-settings of your domain and open ports 80 and 443."

if [[ "no" == $(ask_yes_or_no "Have you made the necessary preparations?") ]]
then
    exit
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
    SSLEngine on
    ServerSignature On
    SSLHonorCipherOrder on
    SSLCertificateChainFile $CERTFILES/$SUBDOMAIN/chain.pem
    SSLCertificateFile $CERTFILES/$SUBDOMAIN/cert.pem
    SSLCertificateKeyFile $CERTFILES/$SUBDOMAIN/privkey.pem
    SSLOpenSSLConfCmd DHParameters $DHPARAMS_SUB

    SSLProtocol TLSv1.2
    SSLCipherSuite ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA256:ECDHE-ECDSA-AES128-SHA:ECDHE-RSA-AES256-SHA384:ECDHE-RSA-AES128-SHA:ECDHE-ECDSA-AES256-SHA384:ECDHE-ECDSA-AES256-SHA:ECDHE-RSA-AES256-SHA:DHE-RSA-AES128-SHA256:DHE-RSA-AES128-SHA:DHE-RSA-AES256-SHA256:DHE-RSA-AES256-SHA:ECDHE-ECDSA-DES-CBC3-SHA:ECDHE-RSA-DES-CBC3-SHA:EDH-RSA-DES-CBC3-SHA:AES128-GCM-SHA256:AES256-GCM-SHA384:AES128-SHA256:AES256-SHA256:AES128-SHA:AES256-SHA:DES-CBC3-SHA:!DSS
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

# Create dir for bitwarden_rs
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
  -e TZ="$TIME_ZONE" \
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
# bitwarden_rs conf
cat << BW_CONF > /etc/fail2ban/filter.d/bitwarden_rs.local
[INCLUDES]
before = common.conf

[Definition]
failregex = ^.*Username or password is incorrect\. Try again\. IP: <ADDR>\. Username:.*$
ignoreregex =
BW_CONF

# bitwarden_rs jail
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

check_command systemctl start fail2ban
countdown "Waiting for fail2ban to start... " 5
check_command fail2ban-client reload

msg_box "Bitwarden_rs with fail2ban have been sucessfully installed! 
Please visit https://$SUBDOMAIN/admin to manage all your settings.

Attention! Please note down the password for the admin panel: $ADMIN_PASS
Otherwise you will not have access to your Bitwarden_rs installation and have to reinstall it completely!

It is highly recommended to configure and test the smtp settings for mails first.
Then, if it works, you can easily invite all your user with an e-mail address from this admin-panel.
(You have to click on users in the top-panel)

Please remember to report issues only to https://github.com/dani-garcia/bitwarden_rs"

any_key "Press any key if you are certain to exit the script..."

exit
