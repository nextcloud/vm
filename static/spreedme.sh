#!/bin/bash

# Tech and Me, ©2016 - www.techandme.se
#
# This install from Nextcloud official stable build with PHP 7, MySQL 5.7 and Apche 2.4.
# Ubuntu 16.04 is required.

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0

# Directories
SCRIPTS=/var/scripts
HTML=/var/www
NCPATH=$HTML/nextcloud
SNAPDIR=/var/snap/spreedme

# DEBUG mode
if [ $DEBUG -eq 1 ]
then
    set -e
    set -x
else
    sleep 1
fi

# Check if root
if [ "$(whoami)" != "root" ]
then
    echo
    echo -e "\e[31mSorry, you are not root.\n\e[0mYou must type: \e[36msudo \e[0mbash $SCRIPTS/nextcloud_install_production.sh"
    echo
    exit 1
fi

# Check if Nextcloud exists
if [ -d $NCPATH ]
then
    sleep 1
else
    echo "Nextcloud does not seem to be installed. This script will exit..."
    exit
fi

# Check if apache is installed
if [ $(dpkg-query -W -f='${Status}' apache2 2>/dev/null | grep -c "ok installed") -eq 1 ]
then
    echo "Apache2 is installed."
    sleep 1
else
    echo "Apache is not installed, the script will exit."
    exit 1
fi

# Install Nextcloud Spreedme Snap
if [ -d $SNAPDIR ]
then
    echo "SpreeMe snap already seems to be installed. This script will remove the old snap and install the new one in 10 seconds."
    sleep 10
    snap remove spreedme
    snap install spreedme
else
    snap install spreedme
fi

# Install and activate the SpreedMe app
SPREEDME_VER=$(wget -q https://raw.githubusercontent.com/strukturag/nextcloud-spreedme/master/appinfo/info.xml && grep -Po "(?<=<version>)[^<]*(?=</version>)" info.xml && rm info.xml)
SPREEDME_FILE=v$SPREEDME_VER.tar.gz
SPREEDME_REPO=https://github.com/strukturag/nextcloud-spreedme/archive

if [ -d $NCPATH/apps/spreedme ]
then
    echo "SpreedMe app already installed"
    sleep 1
else
    wget -q $SPREEDME_REPO/$SPREEDME_FILE -P $NCPATH/apps
    tar -zxf $NCPATH/apps/$SPREEDME_FILE -C $NCPATH/apps
    cd $NCPATH/apps
    rm $SPREEDME_FILE
    mv nextcloud-spreedme-$SPREEDME_VER spreedme
fi
sudo -u www-data php $NCPATH/occ app:enable spreedme

# Generate secret keys
SHAREDSECRET=$(openssl rand -hex 32)
sed -i "s|sharedsecret_secret = .*|sharedsecret_secret = '$SHAREDSECRET'|g" "$SNAPDIR/current/server.conf"

# Populate the else empty config file (uses database for content by default)
cp "$NCPATH/apps/spreedme/config/config.php.in" "$NCPATH/apps/spreedme/config/config.php"

# Place the key in the NC app config
sed -i "s/.*SPREED_WEBRTC_SHAREDSECRET.*/       const SPREED_WEBRTC_SHAREDSECRET = '$SHAREDSECRET';/g" "$NCPATH/apps/spreedme/config/config.php"

# Enable Apache mods
a2enmod proxy \
        proxy_wstunnel \
        proxy_http \
        headers

# Add config to vhost

# Just in case we want to get the activated hosts, save it for later:
#ACTIVE_VHOST=$(apache2ctl -S | grep 80 | cut -f5,5 -d"/" | cut -f1 -d":")
#ACTIVE_VHOST_SSL=$(apache2ctl -S | grep 443 | cut -f5,5 -d"/" | cut -f1 -d":")

VHOST=/etc/apache2/spreedme.conf

cat << VHOST > "$VHOST"
<Location /webrtc>
    ProxyPass http://127.0.0.1:8080/webrtc
    ProxyPassReverse /webrtc
</Location>

<Location /webrtc/ws>
    ProxyPass ws://127.0.0.1:8080/webrtc/ws
</Location>

    ProxyVia On
    ProxyPreserveHost On
    RequestHeader set X-Forwarded-Proto 'https' env=HTTPS
VHOST
if grep -Fxq "Include $VHOST" /etc/apache2/apache2.conf
then
    echo "Include directive are enabled in apache2.conf"
    sleep 1
else
    sed -i "145i Include $VHOST" "/etc/apache2/apache2.conf"
fi

# Restart services
service apache2 restart
systemctl restart snap.spreedme.spreed-webrtc.service
if [[ $? > 0 ]]
then
    echo "Something is wrong, the installation did not finish correctly"
    exit 1
else
    echo
    echo "Success! SpreedMe is now installed and configured."
    echo
    exit 0
fi
echo -e "\e[32m"
read -p "Press any key to continue..." -n1 -s
clear
echo -e "\e[0m"

