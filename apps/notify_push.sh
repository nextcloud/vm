#!/bin/bash

# T&M Hansson IT AB © - 2024, https://www.hanssonit.se/
# Copyright © 2021 Simon Lindner (https://github.com/szaimen)

true
SCRIPT_NAME="Push Notifications for Nextcloud"
SCRIPT_EXPLAINER="$SCRIPT_NAME attempts to solve the issue where Nextcloud clients have to \
periodically check the server if any files have been changed, new activities were created, \
or a notification was created/processed/dismissed, which increases the load on the server. \
By providing a way for the server to send update notifications to the clients, \
the need for the clients to make these checks can be greatly reduced, \
which reduces the load on the servern and delivers notifications to the clients in some cases faster."
# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Check if root
root_check

# NC 21 required
lowest_compatible_nc 21

# Variables
NOTIFY_PUSH_SERVICE_PATH="/etc/systemd/system/notify_push.service"
ARCHITECTURE=$(uname -p)

# Test prequesites
print_text_in_color "$ICyan" "Checking if Nextcloud is installed..."
# Check redis
if ! php -m | grep -q redis
then
    msg_box "The redis php extension isn't enabled. Please run the an update to fix this."
    exit 1
fi
# Check TLS
check_nextcloud_https "Notify Push"

# Get the NCDOMAIN variable
if [ -z "$NCDOMAIN" ]
then
    ncdomain
fi

# Check apache conf
if ! [ -f "$SITES_AVAILABLE/$NCDOMAIN.conf" ]
then
    msg_box "It seems like you haven't used the built-in 'Activate TLS' script to enable 'Let's Encrypt!' \
on your instance. Unfortunately is this a requirement to be able to configure $SCRIPT_NAME successfully.
The installation will be aborted."
    exit 1
elif ! grep -q "<VirtualHost \*:443>" "$SITES_AVAILABLE/$NCDOMAIN.conf"
then
    msg_box "The virtualhost config doesn't seem to be the default. Cannot proceed."
    exit 1
fi
# Check processor architecture
if [ "$ARCHITECTURE" != "x86_64" ] && [ "$ARCHITECTURE" != "aarch64" ] && [ "$ARCHITECTURE" != "armv7" ]
then
    msg_box "No compatible processor architecture found. Cannot proceed."
    exit 1
fi

# Check if notify_push is already installed
if ! [ -f "$NOTIFY_PUSH_SERVICE_PATH" ] && ! is_app_installed notify_push
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
    sed -i "/#Notify-push-start/,/#Notify-push-end/d" "$SITES_AVAILABLE/$NCDOMAIN.conf"
    systemctl restart apache2
    systemctl stop notify_push &>/dev/null
    systemctl disable notify_push &>/dev/null
    rm -f "$NOTIFY_PUSH_SERVICE_PATH"
    count=0
    while [ "$count" -lt 10 ]
    do
        if [ "$(nextcloud_occ_no_check config:system:get trusted_proxies "$count")" = "127.0.0.1" ]
        then
            nextcloud_occ_no_check config:system:delete trusted_proxies "$count"
            break
        else
            count=$((count+1))
        fi
    done
    # Show successful uninstall if applicable
    removal_popup "$SCRIPT_NAME"
fi

# Install the app
install_and_enable_app notify_push
# The app needs to be disabled before the setup
nextcloud_occ_no_check app:disable notify_push
# configure correct rights (otherwise the daemon might fail to start)
chmod 770 -R "$NC_APPS_PATH/notify_push" 

# Setting up the service
cat << NOTIFY_PUSH > "$NOTIFY_PUSH_SERVICE_PATH"
[Unit]
Description = Push daemon for Nextcloud clients

[Service]
Environment = PORT=7867
ExecStart = $NC_APPS_PATH/notify_push/bin/$ARCHITECTURE/notify_push $NCPATH/config/config.php
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
cat << APACHE_PUSH_CONF > /tmp/apache.conf
    #Notify-push-start - Please don't remove or change this line
    ProxyPass /push/ws ws://localhost:7867/ws
    ProxyPass /push/ http://localhost:7867/
    ProxyPassReverse /push/ http://localhost:7867/
    #Notify-push-end - Please don't remove or change this line"
APACHE_PUSH_CONF
sed -i '/<VirtualHost \*:443>/r /tmp/apache.conf' "$SITES_AVAILABLE/$NCDOMAIN.conf"
rm -f /tmp/apache.conf
if ! systemctl restart apache2
then
    msg_box "Failed to restart apache2. Will restore the old NCDOMAIN config now."
    sed -i "/#Notify-push-start/,/#Notify-push-end/d" "$SITES_AVAILABLE/$NCDOMAIN.conf"
    systemctl stop notify_push
    rm "$NOTIFY_PUSH_SERVICE_PATH"
    systemctl restart apache2
    nextcloud_occ_no_check app:remove notify_push
    exit 1
fi

# Add localhost to trusted proxies
count=0
while [ "$count" -lt 10 ]
do
    if [ "$(nextcloud_occ_no_check config:system:get trusted_proxies "$count")" = "127.0.0.1" ]
    then
        break
    elif [ -z "$(nextcloud_occ_no_check config:system:get trusted_proxies "$count")" ]
    then
        nextcloud_occ_no_check config:system:set trusted_proxies "$count" --value="127.0.0.1"
        break
    else
        count=$((count+1))
    fi
done

# Enable Nextcloud app
install_and_enable_app notify_push

# Configure the Nextcloud app and test if it works
countdown "Waiting for the setup check to take place..." "3"
if ! nextcloud_occ_no_check notify_push:setup "https://$NCDOMAIN/push"
then
    msg_box "Something didn't work while testing $SCRIPT_NAME.
Please try again by running this script again!"
    exit 1
else
    msg_box "Congratulations! $SCRIPT_NAME was set up correctly!"
fi
