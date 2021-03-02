#!/bin/bash

# T&M Hansson IT AB © - 2021, https://www.hanssonit.se/
# Copyright © 2021 Simon Lindner (https://github.com/szaimen)

true
SCRIPT_NAME="PDF Annotations"
SCRIPT_EXPLAINER="This script allows to easily install PDF Annotations, \
a tool to annotate any PDF document collaboratively inside Nextcloud"
# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh || source <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Check if root
root_check

# Variables
SERVICE_PATH="/etc/systemd/system/pdfdraw.service"

# Check requirements
if is_app_enabled files_external || is_app_enabled groupfolders
then
    msg_box "The app is unfortunately not yet compatible with Nextcloud's external storage and groupfolders. \
Cannot proceed!\n
(The download of changed pdf files doesn't work.)
You can track this here: 'https://github.com/strukturag/pdfdraw/issues/25'"
    exit 1
fi
# Nextcloud Main Domain
NCDOMAIN=$(nextcloud_occ_no_check config:system:get overwrite.cli.url | sed 's|https://||;s|/||')
# Check if Nextcloud is installed
print_text_in_color "$ICyan" "Checking if Nextcloud is installed..."
if ! curl -s https://"$NCDOMAIN"/status.php | grep -q 'installed":true'
then
    msg_box "It seems like Nextcloud is not installed or that you don't use https on:
$NCDOMAIN
Please install Nextcloud and make sure your domain is reachable, or activate TLS \
on your domain to be able to run this script.
If you use the Nextcloud VM you can use the Let's Encrypt script to get TLS and activate your Nextcloud domain."
    exit 1
fi
# Check apache conf
if ! [ -f "$SITES_AVAILABLE/$NCDOMAIN.conf" ]
then
    msg_box "The apache conf for $NCDOMAIN isn't available. This is not supported!"
    exit 1
elif ! grep -q "<VirtualHost \*:443>" "$SITES_AVAILABLE/$NCDOMAIN.conf"
then
    msg_box "The virtualhost config doesn't seem to be the default. Cannot proceed."
    exit 1
fi

# Check if pdfdraw is already installed
if ! is_app_installed pdfdraw && ! [ -f "$SERVICE_PATH" ]
then
    # Ask for installing
    install_popup "$SCRIPT_NAME"
else
    # Ask for removal or reinstallation
    reinstall_remove_menu "$SCRIPT_NAME"
    # Removal
    sed -i '/<VirtualHost \*:443>/r /tmp/apache.conf' "$SITES_AVAILABLE/$NCDOMAIN.conf"
    systemctl restart apache2
    systemctl stop pdfdraw &>/dev/null
    systemctl disable pdfdraw &>/dev/null
    rm -f "$SERVICE_PATH"
    pip uninstall svglib -y &>/dev/null
    python2 -m pip uninstall pip -y &>/dev/null
    for packet in nodejs npm pdftk python-pypdf2
    do
        if is_this_installed "$packet"
        then
            apt purge "$packet" -y
        fi
    done
    apt autoremove -y
    if is_app_installed pdfdraw
    then
        nextcloud_occ config:app:delete pdfdraw backend
        nextcloud_occ app:remove pdfdraw
    fi
    # Show successful uninstall if applicable
    removal_popup "$SCRIPT_NAME"
fi

# Install pdfdraw
install_and_enable_app pdfdraw
if ! is_app_enabled pdfdraw
then
    msg_box "Could not install/enable pdfdraw."
    exit 1
fi

# Install dependencies
# https://github.com/strukturag/pdfdraw/tree/master/server#requirements
install_if_not nodejs
install_if_not npm
install_if_not pdftk
install_if_not python2
install_if_not python-pypdf2
# Install python2-pip
# https://linuxize.com/post/how-to-install-pip-on-ubuntu-20.04/
curl https://bootstrap.pypa.io/2.7/get-pip.py --output get-pip.py
python2 get-pip.py
rm -f get-pip.py
pip install svglib 

# Install all needed node dependencies
cd "$NC_APPS_PATH/pdfdraw/server"
# The packages.json file is unfortunately not part of the release file. Don't know why.
# Is tracked here: https://github.com/strukturag/pdfdraw/issues/23
# TODO: delete this when package.json is included in the apps release.
wget https://raw.githubusercontent.com/strukturag/pdfdraw/master/server/package.json
npm install
# Adjust config
PDFDRAW_SECRET=$(gen_passwd "$SHUF" "a-zA-Z0-9@#*=")
check_command cp config.js.in config.js
check_command grep -q "^config.secret" config.js
sed -i "s|^config.secret.*|config.secret = '$PDFDRAW_SECRET';|" config.js
check_command grep -q "^config.port" config.js
sed -i "s|^config.port.*|config.port = 8090;|" config.js
# Configure rights
chmod 770 -R "$NC_APPS_PATH/pdfdraw"
chown www-data:www-data -R "$NC_APPS_PATH/pdfdraw"
# Create service
check_command cp pdfdraw.service "$SERVICE_PATH"
chown root:root "$SERVICE_PATH"
chmod 644 "$SERVICE_PATH"
check_command grep -q "^User=" "$SERVICE_PATH"
sed -i 's|^User=.*|User=www-data|' "$SERVICE_PATH"
check_command grep -q "^WorkingDirectory=" "$SERVICE_PATH"
sed -i "s|^WorkingDirectory=.*|WorkingDirectory=$NC_APPS_PATH/pdfdraw/server|" "$SERVICE_PATH"

# Start and enable server
sleep 1
if ! systemctl start pdfdraw
then
    msg_box "Something failed while starting the pdfdraw server.
Please try again by running this script again!"
fi
systemctl enable pdfdraw

# Apache config
sudo a2enmod proxy
sudo a2enmod proxy_http
cat << APACHE_PUSH_CONF > /tmp/apache.conf
    #pdfdraw-start - Please don't remove or change this line
    ProxyPass /socket.io http://localhost:8090/socket.io
    ProxyPassReverse /socket.io http://localhost:8090/socket.io
    ProxyPass /download/ http://localhost:8090/download/
    ProxyPassReverse /download/ http://localhost:8090/download/
    #pdfdraw-end - Please don't remove or change this line"
APACHE_PUSH_CONF
sed -i '/<VirtualHost \*:443>/r /tmp/apache.conf' "$SITES_AVAILABLE/$NCDOMAIN.conf"
rm -f /tmp/apache.conf
if ! systemctl restart apache2
then
    msg_box "Failed to restart apache2. Will restore the old NCDOMAIN config now."
    sed -i "/#pdfdraw-start/,/#pdfdraw-end/d" "$SITES_AVAILABLE/$NCDOMAIN.conf"
    systemctl stop pdfdraw
    rm "$SERVICE_PATH"
    systemctl restart apache2
    nextcloud_occ_no_check app:remove pdfdraw
    exit 1
fi

# Add the values to the app
nextcloud_occ config:app:set pdfdraw backend \
--value="{\"server\":\"https://$NCDOMAIN\",\"secret\":\"$PDFDRAW_SECRET\"}"

# Restart the webserver
restart_webserver

msg_box "PDF Annotations was successfully installed!
You can check it out by right clicking on a pdf file in Nextcloud and selecting 'Annotate'"
