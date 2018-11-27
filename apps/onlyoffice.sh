#!/bin/bash

echo "Installing OnlyOffice..."

# T&M Hansson IT AB © - 2018, https://www.hanssonit.se/

# shellcheck disable=2034,2059
true
# shellcheck source=lib.sh
NC_UPDATE=1 && OO_INSTALL=1 . <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)
unset NC_UPDATE
unset OO_INSTALL

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Check if root
root_check

# Nextcloud 13 is required.
lowest_compatible_nc 13

# Test RAM size (4GB min) + CPUs (min 2)
ram_check 4 OnlyOffice
cpu_check 2 OnlyOffice

# Check if Collabora is running
if [ -d "$NCPATH"/apps/richdocuments ]
then
msg_box "It seems like Collabora is running.
You can't run Collabora at the same time as you run OnlyOffice."
    exit 1
fi

# Notification
msg_box "Before you start, please make sure that port 80+443 is directly forwarded to this machine!"

# Get the latest packages
apt update -q4 & spinner_loading

# Check if Nextcloud is installed
echo "Checking if Nextcloud is installed..."
if ! curl -s https://"${NCDOMAIN//\\/}"/status.php | grep -q 'installed":true'
then
msg_box "It seems like Nextcloud is not installed or that you don't use https on:
${NCDOMAIN//\\/}.
Please install Nextcloud and make sure your domain is reachable, or activate SSL
on your domain to be able to run this script.
If you use the Nextcloud VM you can use the Let's Encrypt script to get SSL and activate your Nextcloud domain.
When SSL is activated, run these commands from your terminal:
sudo wget $APP/onlyoffice.sh
sudo bash onlyoffice.sh"
    exit 1
fi

# Check if $SUBDOMAIN exists and is reachable
echo
echo "Checking if $SUBDOMAIN exists and is reachable..."
if wget -q -T 10 -t 2 --spider "$SUBDOMAIN"; then
   sleep 0.1
elif wget -q -T 10 -t 2 --spider --no-check-certificate "https://$SUBDOMAIN"; then
   sleep 0.1
elif curl -s -k -m 10 "$SUBDOMAIN"; then
   sleep 0.1
elif curl -s -k -m 10 "https://$SUBDOMAIN" -o /dev/null; then
   sleep 0.1
else
msg_box "Nope, it's not there. You have to create $SUBDOMAIN and point
it to this server before you can run this script."
   exit 1
fi

# Check open ports with NMAP
check_open_port 80 "$SUBDOMAIN"
check_open_port 443 "$SUBDOMAIN"

# Install Docker
install_docker

# Check if OnlyOffice or Collabora is previously installed
# If yes, then stop and prune the docker container
docker_prune_this 'collabora/code' 'onlyoffice/documentserver'

# Disable Onlyoffice if activated
if [ -d "$NCPATH"/apps/onlyoffice ]
then
    occ_command app:disable onlyoffice
    rm -r "$NC_APPS_PATH"/onlyoffice
fi

# Install Onlyoffice docker
docker pull onlyoffice/documentserver:latest
docker run -i -t -d -p 127.0.0.3:9090:80 --restart always --name onlyoffice onlyoffice/documentserver

# Install apache2 
install_if_not apache2

# Enable Apache2 module's
a2enmod proxy
a2enmod proxy_wstunnel
a2enmod proxy_http
a2enmod ssl

# Create Vhost for OnlyOffice online in Apache2
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
    SSLOpenSSLConfCmd DHParameters $DHPARAMS
    
    SSLProtocol             all -SSLv2 -SSLv3
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

    # basic proxy settings
    ProxyRequests off

    ProxyPassMatch (.*)(\/websocket)$ "ws://127.0.0.3:9090/$1$2"
    ProxyPass / "http://127.0.0.3:9090/"
    ProxyPassReverse / "http://127.0.0.3:9090/"
        
    <Location />
        ProxyPassReverse /
    </Location>
</VirtualHost>
HTTPS_CREATE

    if [ -f "$HTTPS_CONF" ];
    then
        echo "$HTTPS_CONF was successfully created"
        sleep 1
    else
        echo "Unable to create vhost, exiting..."
        echo "Please report this issue here $ISSUES"
        exit 1
    fi
fi

# Install certbot (Let's Encrypt)
install_certbot

# Generate certs
if le_subdomain
then
    # Generate DHparams chifer
    if [ ! -f "$DHPARAMS" ]
    then
        openssl dhparam -dsaparam -out "$DHPARAMS" 4096
    fi
    printf "%b" "${IGreen}Certs are generated!\n${Color_Off}"
    a2ensite "$SUBDOMAIN.conf"
    restart_webserver
# Install Onlyoffice App
    cd "$NC_APPS_PATH"
    check_command git clone https://github.com/ONLYOFFICE/onlyoffice-nextcloud.git onlyoffice
else
    printf "%b" "${IRed}It seems like no certs were generated, please report this issue here: $ISSUES\n${Color_Off}"
    any_key "Press any key to continue... "
    restart_webserver
fi

# Enable Onlyoffice
if [ -d "$NC_APPS_PATH"/onlyoffice ]
then
# Enable OnlyOffice
    occ_command app:enable onlyoffice
    occ_command config:app:set onlyoffice DocumentServerUrl --value=https://"$SUBDOMAIN/"
    chown -R www-data:www-data "$NC_APPS_PATH"
    occ_command config:system:set trusted_domains 3 --value="$SUBDOMAIN"
# Add prune command
    {
    echo "#!/bin/bash"
    echo "docker system prune -a --force"
    echo "exit"
    } > "$SCRIPTS/dockerprune.sh"
    chmod a+x "$SCRIPTS/dockerprune.sh"
    crontab -u root -l | { cat; echo "@weekly $SCRIPTS/dockerprune.sh"; } | crontab -u root -
    echo "Docker automatic prune job added."
    echo
    service docker restart
    docker restart onlyoffice
    echo "OnlyOffice is now successfully installed."
    any_key "Press any key to continue... "
fi

exit
