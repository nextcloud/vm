#!/bin/bash

# Tech and Me, ©2017 - www.techandme.se
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
    set -ex
fi

# Check if root
if [[ "$EUID" -ne 0 ]]
then
    echo
    printf "\e[31mSorry, you are not root.\n\e[0mYou must type: \e[36msudo \e[0mbash %s/nextcloud_install_production.sh" "$SCRIPTS"
    echo
    exit 1
fi

# Check if Nextcloud exists
if [ ! -d "$NCPATH" ]
then
    echo "Nextcloud does not seem to be installed. This script will exit..."
    exit
fi

# Check if apache is installed
if ! [ "$(dpkg-query -W -f='${Status}' apache2 2>/dev/null | grep -c "ok installed")" -eq 1 ]
then
    echo "Apache is not installed, the script will exit."
    exit 1
fi

# Install Nextcloud Spreedme Snap
if [ -d "$SNAPDIR" ]
then
    echo "SpreeMe Snap already seems to be installed and wil now be re-installed..."
    snap remove spreedme
    snap install spreedme
else
    snap install spreedme
fi

# Install and activate the SpreedMe app
SPREEDME_VER=$(wget -q https://raw.githubusercontent.com/strukturag/nextcloud-spreedme/master/appinfo/info.xml && grep -Po "(?<=<version>)[^<]*(?=</version>)" info.xml && rm info.xml)
SPREEDME_FILE="v$SPREEDME_VER.tar.gz"
SPREEDME_REPO=https://github.com/strukturag/nextcloud-spreedme/archive

if [ -d "$NCPATH/apps/spreedme" ]
then
    # Remove
    sudo -u www-data php "$NCPATH/occ" app:disable spreedme
    echo "SpreedMe app already seems to be installed and will now be re-installed..."
    rm -R "$NCPATH/apps/spreedme"
    # Reinstall
    wget -q "$SPREEDME_REPO/$SPREEDME_FILE" -P "$NCPATH/apps"
    tar -zxf "$NCPATH/apps/$SPREEDME_FILE" -C "$NCPATH/apps"
    cd "$NCPATH/apps"
    rm "$SPREEDME_FILE"
    mv "nextcloud-spreedme-$SPREEDME_VER" spreedme
else
    wget -q "$SPREEDME_REPO/$SPREEDME_FILE" -P "$NCPATH/apps"
    tar -zxf "$NCPATH/apps/$SPREEDME_FILE" -C "$NCPATH/apps"
    cd "$NCPATH/apps"
    rm "$SPREEDME_FILE"
    mv "nextcloud-spreedme-$SPREEDME_VER" spreedme
fi
sudo -u www-data php $NCPATH/occ app:enable spreedme

# Generate secret keys
SHAREDSECRET=$(openssl rand -hex 32)
TEMPLINK=$(openssl rand -hex 32)
sed -i "s|sharedsecret_secret = .*|sharedsecret_secret = $SHAREDSECRET|g" "$SNAPDIR/current/server.conf"

# Populate the else empty config file (uses database for content by default)
cp "$NCPATH/apps/spreedme/config/config.php.in" "$NCPATH/apps/spreedme/config/config.php"

# Place the key in the NC app config
sed -i "s|.*SPREED_WEBRTC_SHAREDSECRET.*|       const SPREED_WEBRTC_SHAREDSECRET = '$SHAREDSECRET';|g" "$NCPATH/apps/spreedme/config/config.php"

# Allow to create temporary links
sed -i "s|const OWNCLOUD_TEMPORARY_PASSWORD_LOGIN_ENABLED.*|const OWNCLOUD_TEMPORARY_PASSWORD_LOGIN_ENABLED = true;|g" "$NCPATH/apps/spreedme/config/config.php"

#  Set temporary links hash
sed -i "s|const OWNCLOUD_TEMPORARY_PASSWORD_SIGNING_KEY.*|const OWNCLOUD_TEMPORARY_PASSWORD_SIGNING_KEY = '$TEMPLINK';|g" "$NCPATH/apps/spreedme/config/config.php"


# Enable Apache mods
a2enmod proxy \
        proxy_wstunnel \
        proxy_http \
        headers

# Add config to vhost
VHOST=/etc/apache2/spreedme.conf
if [ ! -f $VHOST ]
then
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
    # RequestHeader set X-Forwarded-Proto 'https' # Use this if you are behind a (Nginx) reverse proxy with http backends
VHOST
fi

if ! grep -Fxq "Include $VHOST" /etc/apache2/apache2.conf
then
    sed -i "145i Include $VHOST" "/etc/apache2/apache2.conf"
fi

# Restart services
service apache2 restart
if ! systemctl restart snap.spreedme.spreed-webrtc.service
then
    echo "Something is wrong, the installation did not finish correctly"
    exit 1
else
    echo
    echo "Success! SpreedMe is now installed and configured."
    echo "You may have to change SPREED_WEBRTC_ORIGIN in:" 
    echo "(sudo nano) $NCPATH/apps/spreedme/config/config.php"
    echo
    exit 0
fi
read -p $'\n\e[32mPress any key to continue...\e[0m\n' -n1 -s
clear
