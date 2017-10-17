#!/bin/bash
# shellcheck disable=2034,2059
true
# shellcheck source=lib.sh
OO_INSTALL=1 . <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)
unset OO_INSTALL

# Tech and Me © - 2017, https://www.techandme.se/

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Check if root
if ! is_root
then
    printf "\n${Red}Sorry, you are not root.\n${Color_Off}You must type: ${Cyan}sudo ${Color_Off}bash $SCRIPTS/onlyoffice.sh\n"
    exit 1
fi

# Test RAM size (4GB min) + CPUs (min 2)
ram_check 4 OnlyOffice
cpu_check 2 OnlyOffice

# Check if Collabora is running
if [ -d "$NCPATH"/apps/richdocuments ]
then
    echo "It seems like Collabora is running."
    echo "You can't run Collabora at the same time as you run OnlyOffice."
    exit 1
fi

# Notification
whiptail --msgbox "Please before you start, make sure that port 443 is directly forwarded to this machine!" "$WT_HEIGHT" "$WT_WIDTH"

# Get the latest packages
apt update -q4 & spinner_loading

# Check if Nextcloud is installed
echo "Checking if Nextcloud is installed..."
if ! curl -s https://"${NCDOMAIN//\\/}"/status.php | grep -q 'installed":true'
then
    echo
    echo "It seems like Nextcloud is not installed or that you don't use https on:"
    echo "${NCDOMAIN//\\/}."
    echo "Please install Nextcloud and make sure your domain is reachable, or activate SSL"
    echo "on your domain to be able to run this script."
    echo
    echo "If you use the Nextcloud VM you can use the Let's Encrypt script to get SSL and activate your Nextcloud domain."
    echo "When SSL is activated, run these commands from your terminal:"
    echo "sudo wget $APP/onlyoffice.sh"
    echo "sudo bash onlyoffice.sh"
    any_key "Press any key to continue... "
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
   echo "Nope, it's not there. You have to create $SUBDOMAIN and point"
   echo "it to this server before you can run this script."
   any_key "Press any key to continue... "
   exit 1
fi

# Check open ports with NMAP
check_open_port 443 "$SUBDOMAIN"

# Install Docker
if [ "$(dpkg-query -W -f='${Status}' docker-ce 2>/dev/null | grep -c "ok installed")" == "1" ]
then
    docker -v
else
    apt update -q4 & spinner_loading
    apt install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    software-properties-common
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
    apt-key fingerprint 0EBFCD88
    add-apt-repository \
    "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) \
    stable"
    apt update
    apt install docker-ce -y
    docker -v
fi

# Load aufs
apt-get install linux-image-extra-"$(uname -r)" -y
# apt install aufs-tools -y # already included in the docker-ce package
AUFS=$(grep -r "aufs" /etc/modules)
if ! [ "$AUFS" = "aufs" ]
then
    echo "aufs" >> /etc/modules
fi

# Set docker storage driver to AUFS
AUFS2=$(grep -r "aufs" /etc/default/docker)
if ! [ "$AUFS2" = 'DOCKER_OPTS="--storage-driver=aufs"' ]
then
    echo 'DOCKER_OPTS="--storage-driver=aufs"' >> /etc/default/docker
    service docker restart
fi

# Check of docker runs and kill it
DOCKERPS=$(docker ps -a -q)
if [ "$DOCKERPS" != "" ]
then
    echo "Removing old Docker instance(s)... ($DOCKERPS)"
    any_key "Press any key to continue. Press CTRL+C to abort"
    docker stop "$DOCKERPS"
    docker rm "$DOCKERPS"
fi

# Disable Onlyoffice if activated
if [ -d "$NCPATH"/apps/onlyoffice ]
then
    sudo -u www-data php "$NCPATH"/occ app:disable onlyoffice
    rm -r "$NCPATH"/apps/onlyoffice
fi

# Install Onlyoffice docker
docker pull onlyoffice/documentserver:latest
docker run -i -t -d -p 127.0.0.3:9090:80 --restart always onlyoffice/documentserver

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
    SSLCipherSuite ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-SHA384:ECDHE-RSA-AES128-SHA256:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES128-SHA256:ECDHE-ECDSA-AES128-SHA:ECDHE-RSA-AES128-SHA:ECDHE-ECDSA-AES256-SHA384:ECDHE-ECDSA-AES256-SHA:ECDHE-RSA-AES256-SHA:DHE-RSA-AES128-SHA256:DHE-RSA-AES128-SHA:DHE-RSA-AES256-SHA256:DHE-RSA-AES256-SHA:ECDHE-ECDSA-DES-CBC3-SHA:ECDHE-RSA-DES-CBC3-SHA:EDH-RSA-DES-CBC3-SHA:AES128-GCM-SHA256:AES256-GCM-SHA384:AES128-SHA256:AES256-SHA256:AES128-SHA:AES256-SHA:DES-CBC3-SHA:!DSS
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
    printf "${ICyan}\n"
    printf "Certs are generated!\n"
    printf "${Color_Off}\n"
    a2ensite "$SUBDOMAIN.conf"
    service apache2 restart
# Install Onlyoffice App
    cd $NCPATH/apps
    check_command git clone https://github.com/ONLYOFFICE/onlyoffice-owncloud.git onlyoffice
else
    printf "${ICyan}\nIt seems like no certs were generated, please report this issue here: $ISSUES\n"
    any_key "Press any key to continue... "
    service apache2 restart
fi

# Enable Onlyoffice
if [ -d "$NCPATH"/apps/onlyoffice ]
then
# Enable OnlyOffice
    check_command sudo -u www-data php "$NCPATH"/occ app:enable onlyoffice
    check_command sudo -u www-data php "$NCPATH"/occ config:app:set onlyoffice DocumentServerUrl --value="https://$SUBDOMAIN/"
    chown -R www-data:www-data $NCPATH/apps
    check_command sudo -u www-data php "$NCPATH"/occ config:system:set trusted_domains 3 --value="$SUBDOMAIN"
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
    echo "OnlyOffice is now succesfylly installed."
    echo "You may have to reboot before Docker will load correctly."
    any_key "Press any key to continue... "
fi
