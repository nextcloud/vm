#!/bin/bash

# T&M Hansson IT AB © - 2024, https://www.hanssonit.se/

true
SCRIPT_NAME="Spreedme"
# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh

# Get all needed variables from the library
nc_update

print_text_in_color "$ICyan" "Installing Spreed.ME..."

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Check if root
if ! is_root
then
    printf "\n${Red}Sorry, you are not root.\n${Color_Off}You must type: ${ICyan}sudo ${Color_Off}bash %s/nextcloud_install_production.sh\n" "$SCRIPTS"
    exit 1
fi

# Check if Nextcloud exists
root_check

# Nextcloud 13 is required.
lowest_compatible_nc 13

# Install if missing
install_if_not apache2
install_if_not snapd

# Install Nextcloud Spreed.ME Snap
if [ -d "$SNAPDIR" ]
then
    print_text_in_color "$ICyan" "Spreed.ME Snap already seems to be installed and will now be re-installed..."
    snap remove spreedme
    rm -rf "$SNAPDIR"
    snap install --edge spreedme
else
    snap install --edge spreedme
fi

# Install and activate the Spreed.ME app
if [ -d "$NC_APPS_PATH/spreedme" ]
then
    # Remove
    nextcloud_occ app:disable spreedme
    print_text_in_color "$ICyan" "Spreed.ME app already seems to be installed and will now be re-installed..."
    rm -R "$NC_APPS_PATH/spreedme"
    # Reinstall
    nextcloud_occ app:install spreedme
else
    nextcloud_occ app:install spreedme
fi
nextcloud_occ app:enable spreedme
chown -R www-data:www-data "$NC_APPS_PATH"

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
restart_webserver
if ! systemctl restart snap.spreedme.spreed-webrtc.service
then
    msg_box "Something is wrong, the installation did not finish correctly.

Please report this to $ISSUES"
    exit 1
else
    msg_box "Success! Spreed.ME is now installed and configured.

You may have to change SPREED_WEBRTC_ORIGIN in:
(sudo nano) $NCPATH/apps/spreedme/config/config.php"
    exit 0
fi
