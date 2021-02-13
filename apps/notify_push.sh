#!/bin/bash

# T&M Hansson IT AB © - 2021, https://www.hanssonit.se/
# Copyright © 2021 Simon Lindner (https://github.com/szaimen)

true
SCRIPT_NAME="Notify Push for Nextcloud"
SCRIPT_EXPLAINER="Notify Push for Nextcloud attempts to solve the issue where Nextcloud clients have to \
periodically check the server if any files have been changed which increases the load on the server. \
By providing a way for the server to send update notifications to the clients, \
the need for the clients to make these checks can be greatly reduced."
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
SERVICE_PATH="/etc/systemd/system/notify_push.service"

# Test prequesites
print_text_in_color "$ICyan" "Checking if Nextcloud is installed..."
# Get all needed variables from the library
nc_update
if [ "${CURRENTVERSION%%.*}" -lt "21" ]
then
    msg_box "This app is only supported from NC 21 and higher. Cannot proceed!"
    exit 1
fi
# Check TLS
NCDOMAIN=$(nextcloud_occ_no_check config:system:get overwrite.cli.url | sed 's|https://||;s|/||')
if ! curl -s https://"$NCDOMAIN"/status.php | grep -q 'installed":true'
then
    msg_box "It seems like Nextcloud is not installed or that you don't use https on:
$NCDOMAIN.
Please install Nextcloud and make sure your domain is reachable, or activate TLS
on your domain to be able to run this script.
If you use the Nextcloud VM you can use the Let's Encrypt script to get TLS and activate your Nextcloud domain."
    exit 1
fi
# Check apache conf
if ! [ -f "$SITES_AVAILABLE/$NCDOMAIN.conf" ]
then
    msg_box "The apache conf for $NCDOMAIN isn't availabe. This is not supported!"
    exit 1
fi

# Check if notify_push is already installed
if ! [ -f "$SERVICE_PATH" ] && ! is_app_installed notify_push
then
    # Ask for installing
    install_popup "$SCRIPT_NAME"
else
    # Ask for removal or reinstallation
    reinstall_remove_menu "$SCRIPT_NAME"
    # Removal
    if is_app_installed notify_push
    then
        nextcloud_occ_no_check app:remove notify_push
    fi
    sed -i "/^#Notify-push-start/,/^#Notify-push-end/d" "$SITES_AVAILABLE/$NCDOMAIN.conf"
    systemctl stop notify_push &>/dev/null
    rm -f "$SERVICE_PATH"
    # Show successful uninstall if applicable
    removal_popup "$SCRIPT_NAME"
fi

# Install the app
install_and_enable_app notify_push
# The app needs to be disabled before the setup
nextcloud_occ_no_check app:disable notify_push

# Setting up the service
cat << NOTIFY_PUSH > "$SERVICE_PATH"
[Unit]
Description = Push daemon for Nextcloud clients

[Service]
Environment = PORT=7867
ExecStart = $NC_APPS_PATH/notify_push $NCPATH/config/config.php
User = www-data

[Install]
WantedBy = multi-user.target
NOTIFY_PUSH

# Starting and enabling the service
systemctl start notify_push
systemctl enable notify_push

# Apache config
sudo a2enmod proxy
sudo a2enmod proxy_http
sudo a2enmod proxy_wstunnel
NOTIFY_PUSH_CONF="    #Notify-push-start - Please don't remove or change this line
    ProxyPass /push/ws ws://localhost:7867/ws
    ProxyPass /push/ http://localhost:7867/
    ProxyPassReverse /push/ http://localhost:7867/
    #Notify-push-end - Please don't remove or change this line"
NOTIFY_PUSH_CONF=${NOTIFY_PUSH_CONF//\//\\/}
sed -i "/<VirtualHost \*:443>/a $NOTIFY_PUSH_CONF" "$SITES_AVAILABLE/$NCDOMAIN.conf"
if ! systemctl restart apache2
then
    msg_box "Failed to restart apache2. Will restore the old NCDOMAIN config now."
    sed -i "/^#Notify-push-start/,/^#Notify-push-end/d" "$SITES_AVAILABLE/$NCDOMAIN.conf"
    systemctl stop notify_push
    rm "$SERVICE_PATH"
    systemctl restart apache2
    nextcloud_occ_no_check app:remove notify_push
    exit 1
fi

# Enable and configure the Nextcloud app
install_and_enable_app notify_push
nextcloud_occ_no_check notify_push:setup "https://$NCDOMAIN/push"

# TODO: test if it works? how?
