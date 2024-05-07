#!/bin/bash

# T&M Hansson IT AB © - 2024, https://www.hanssonit.se/

true
SCRIPT_NAME="Bitwarden"
SCRIPT_EXPLAINER="Bitwarden is a free and open-source password management service \
that stores sensitive information such as website credentials in an encrypted vault.
The Bitwarden platform offers a variety of client applications including a \
web interface, desktop applications, browser extensions, mobile apps, and a CLI. 
Bitwarden offers a cloud-hosted service as well as the ability to deploy the solution on-premises."
# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Check if root
root_check

# Show explainer
msg_box "$SCRIPT_EXPLAINER"

# Check if Bitwarden is already installed
print_text_in_color "$ICyan" "Checking if Bitwarden is already installed..."
if is_docker_running
then
    if docker ps -a --format '{{.Names}}' | grep -Eq "bitwarden";
    then
        if is_this_installed apache2
        then
            if [ -d /root/bwdata ] || [ -d "$BITWARDEN_HOME"/bwdata ]
            then
                msg_box "It seems like Bitwarden is already installed.
You cannot install it again because you would lose all your data and passwords.

If you are certain that you definitely want to delete Bitwarden and all
its data to be able to reinstall it, you can execute the following commands:

systemctl stop bitwarden
docker volume prune -f
docker system prune -af
rm -rf ${BITWARDEN_HOME:?}/bwdata"
                exit 1
            fi
        fi
    fi
fi

msg_box "Bitwarden is a password manager that is separate from Nextcloud, \
though we provide this service because it's self hosted and secure.

To be able to use Bitwarden, you need a separate subdomain.
Please create a DNS record and point it to this server, e.g: bitwarden.yourdomain.com.
After Bitwarden is setup, we will automatically generate a TLS cert with Let's Encrypt.
There's no need to get your own prior to this setup, nor during the Bitwarden setup.

The script is based on this documentation: https://help.bitwarden.com/article/install-on-premise/
It's a good idea to read that before you start this script.

Please also report any issues regarding this script setup to $ISSUES"

msg_box "The necessary preparations to run expose Bitwarden to the internet are:
1. Please open port 443 and 80 and point to this server.
(You will be asked if you want to use UPNP to open those ports automatically in the next step.)
2. Please create a DNS record for your subdomain and point that to this server.
3. Raise the amount of RAM to this server to at least 4 GB."

if ! yesno_box_yes "Have you made the necessary preparations?"
then
    msg_box "OK, please do the necessary preparations before you \
run this script and then simply run it again once you're done.

To run this script again, execute $SCRIPTS/menu.sh and choose Additional Apps --> Bitwarden"
    exit
fi

# Test RAM size (3 GB min) + CPUs (min 2)
ram_check 4 Bitwarden
cpu_check 2 Bitwarden

msg_box "IMPORTANT, PLEASE READ!

In the next steps you will be asked to answer some questions.
The questions are from the Bitwarden setup script, and therefore nothing that we control.

It's important that you answer the questions correctly for the rest of the setup to work properly,
and to be able to generate a valid TLS certificate automatically with our own (this) script.

Basically:
1. Enter the domain for Bitwarden
2. Answer 'no' to the question if you want Let's Encrypt
3. Enter the name for your Database (could be anything)
4. Enter your installation id and keys
5. Continue to answer 'no' to everything related to SSL/TLS.

Please have a look at how the questions are answered here if you are uncertain:
https://imgur.com/a/3ytwvp6"

# Install Docker
install_docker

# Create bitwarden user
if ! id "$BITWARDEN_USER" >/dev/null 2>&1
then
    print_text_in_color "$ICyan" "Specifying a certain user for Bitwarden: $BITWARDEN_USER..."
    useradd -s /bin/bash -d "$BITWARDEN_HOME" -m -G docker "$BITWARDEN_USER"
else
    userdel "$BITWARDEN_USER"
    rm -rf "${BITWARDEN_HOME:?}/"
    print_text_in_color "$ICyan" "Specifying a certain user for Bitwarden: $BITWARDEN_USER..."
    useradd -s /bin/bash -d "$BITWARDEN_HOME/" -m -G docker "$BITWARDEN_USER"
fi

# Wait for home to be created
while :
do
    if ! ls "$BITWARDEN_HOME" >/dev/null 2>&1
    then
        print_text_in_color "$ICyan" "Waiting for $BITWARDEN_HOME to be created"
        sleep 1
    else
       break
    fi
done

# Create the service
print_text_in_color "$ICyan" "Creating the Bitwarden service..."

cat << BITWARDEN_SERVICE > /etc/systemd/system/bitwarden.service
[Unit]
Description=Bitwarden
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
User=$BITWARDEN_USER
Group=$BITWARDEN_USER
ExecStart=$BITWARDEN_HOME/bitwarden.sh start
RemainAfterExit=true
ExecStop=$BITWARDEN_HOME/bitwarden.sh stop

[Install]
WantedBy=multi-user.target
BITWARDEN_SERVICE

# Set permissions and enable the service
sudo chmod 644 /etc/systemd/system/bitwarden.service
check_command systemctl enable bitwarden

# Install Bitwarden
install_if_not curl
check_command cd "$BITWARDEN_HOME"
curl_to_dir "https://raw.githubusercontent.com/bitwarden/self-host/master" "bitwarden.sh" "$BITWARDEN_HOME"
chmod +x "$BITWARDEN_HOME"/bitwarden.sh
chown -R "$BITWARDEN_USER":"$BITWARDEN_USER" "$BITWARDEN_HOME"
check_command sudo -u "$BITWARDEN_USER" ./bitwarden.sh install
check_command systemctl daemon-reload

# Check if all ssl settings were entered correctly
if grep ^url "$BITWARDEN_HOME"/bwdata/config.yml | grep -q https || grep ^url "$BITWARDEN_HOME"/bwdata/config.yml | grep -q localhost
then
    msg_box "It seems like some of the settings you entered are wrong.
We will now remove Bitwarden so that you can start over with the installation."
    check_command systemctl stop bitwarden
    docker volume prune -f
    docker system prune -af
    rm -rf "${BITWARDEN_HOME:?}/"bwdata
    exit 1
fi

# Continue with the installation
sed -i "s|http_port.*|http_port: 5178|g" "$BITWARDEN_HOME"/bwdata/config.yml
sed -i "s|https_port.*|https_port: 5179|g" "$BITWARDEN_HOME"/bwdata/config.yml
USERID=$(id -u $BITWARDEN_USER)
USERGROUPID=$(id -g $BITWARDEN_USER)
sed -i "s|database_docker_volume:.*|database_docker_volume: true|g" "$BITWARDEN_HOME"/bwdata/config.yml
sed -i "s|LOCAL_UID=.*|LOCAL_UID=$USERID|g" "$BITWARDEN_HOME"/bwdata/env/uid.env
sed -i "s|LOCAL_GID=.*|LOCAL_GID=$USERGROUPID|g" "$BITWARDEN_HOME"/bwdata/env/uid.env
# Get subdomain from config.yml and change it to https
SUBDOMAIN=$(grep ^url "$BITWARDEN_HOME"/bwdata/config.yml)
SUBDOMAIN=${SUBDOMAIN##*url: http://}
sed -i "s|^url: .*|url: https://$SUBDOMAIN|g" "$BITWARDEN_HOME"/bwdata/config.yml
sed -i 's|http://|https://|g' "$BITWARDEN_HOME"/bwdata/env/global.override.env
check_command sudo -u "$BITWARDEN_USER" ./bitwarden.sh rebuild
print_text_in_color "$ICyan" "Starting Bitwarden for the first time, please be patient..."
check_command sudo -u "$BITWARDEN_USER" ./bitwarden.sh start
# We don't need this for Bitwarden to start, but it's a great way to find out if the DB is online or not.
countdown "Waiting for the DB to come online..." 15
check_command sudo -u "$BITWARDEN_USER" ./bitwarden.sh updatedb

# Produce reverse-proxy config and get lets-encrypt certificate
msg_box "We'll now set up the Apache Proxy that will act as TLS front for your Bitwarden installation."

msg_box "Before continuing, please make sure that you have you have \
edited the DNS settings for $SUBDOMAIN, and opened port 80 and 443 \
directly to this servers IP. A full extensive guide can be found here:
https://www.techandme.se/open-port-80-443

This can be done automatically if you have UPNP enabled in your firewall/router.
You will be offered to use UPNP in the next step.

PLEASE NOTE:
Using other ports than the default 80 and 443 is not supported, \
though it may be possible with some custom modification:
https://help.nextcloud.com/t/domain-refused-to-connect-collabora/91303/17"

if yesno_box_no "Do you want to use UPNP to open port 80 and 443?"
then
    unset FAIL
    open_port 80 TCP
    open_port 443 TCP
    cleanup_open_port
fi

# Curl the lib another time to get the correct HTTPS_CONF
# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh

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

# Only add TLS 1.3 on Ubuntu later than 22.04
if version 22.04 "$DISTRO" 24.04.10
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
    CustomLog \${APACHE_LOG_DIR}/access.log combined
    ErrorLog \${APACHE_LOG_DIR}/error.log

    # Just in case - see below
    SSLProxyEngine On
    SSLProxyVerify None
    SSLProxyCheckPeerCN Off
    SSLProxyCheckPeerName Off
    # contra mixed content warnings
    RequestHeader set X-Forwarded-Proto "https"
    # basic proxy settings
    ProxyRequests off
    ProxyPassMatch (.*)(\/websocket)$ "ws://127.0.0.1:5178/$1$2"
    ProxyPass / "http://127.0.0.1:5178/"
    ProxyPassReverse / "http://127.0.0.1:5178/"
    # Extra (remote) headers
    RequestHeader set X-Real-IP %{REMOTE_ADDR}s
    Header set X-XSS-Protection "1; mode=block"
    Header set Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
    Header set X-Content-Type-Options nosniff
    Header set Content-Security-Policy "frame-ancestors 'self'"
    <Location />
        ProxyPassReverse /
    </Location>
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
    # Generate DHparams cipher
    if [ ! -f "$DHPARAMS_SUB" ]
    then
        openssl dhparam -out "$DHPARAMS_SUB" 2048
    fi
    print_text_in_color "$IGreen" "Certs are generated!"
    a2ensite "$SUBDOMAIN.conf"
    restart_webserver
else
    # remove settings to be able to start over again
    rm -f "$HTTPS_CONF"
    last_fail_tls "$SCRIPTS"/apps/tmbitwarden.sh
    systemctl stop bitwarden
    docker volume prune -f
    docker system prune -af
    rm -rf "${BITWARDEN_HOME:?}/"bwdata
    exit 1
fi

# Remove Watchtower
if is_docker_running
then
    # To fix https://github.com/nextcloud/vm/issues/1459 we need to remove Watchtower to avoid updating Bitwarden again, and only update the specified docker images above
    if docker ps -a --format '{{.Names}}' | grep -Eq "bitwarden";
    then
        if [ -d "$BITWARDEN_HOME"/bwdata ]
        then
            if does_this_docker_exist 'containrrr/watchtower'
            then
                docker stop watchtower
            elif does_this_docker_exist 'v2tec/watchtower'
            then
                docker stop watchtower
            fi
            docker container prune -f
            docker image prune -a -f
            docker volume prune -f
            notify_admin_gui "Watchtower removed" "Due to compatibility issues with Bitwarden and Watchtower, we have removed Watchtower from this server. Updates will now happen for each container separately instead."
        fi
    fi
fi

# Add prune command
add_dockerprune

msg_box "Bitwarden was successfully installed! Please visit $SUBDOMAIN to set up your account.

After the account is registered, please disable user registration by running sudo bash $SCRIPTS/menu.sh and choose:
Additional Apps --> Bitwarden --> Bitwarden Registration

Some notes to the Bitwarden service:
to START Bitwarden, simply execute: 'systemctl start bitwarden'
to STOP Bitwarden, simply execute: 'systemctl stop bitwarden'
to RESTART Bitwarden, simply execute: 'systemctl restart bitwarden'"

msg_box "In case you want to backup Bitwarden, you should know that the MSSQL files are stored here:
/var/lib/docker/volumes/docker_mssql_data/_data

This is because we run the database as a Docker container, and not \
directly on the filesystem - which otherwise would be the default.
Reason? We found it to be more stable running in a container, \
several sources in their issue tracker also confirms the same thing."

exit
