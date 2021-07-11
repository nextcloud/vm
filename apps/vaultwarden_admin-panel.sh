#!/bin/bash

# T&M Hansson IT AB © - 2021, https://www.hanssonit.se/

true
SCRIPT_NAME="Vaultwarden Admin"
# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh || source <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Check if root
root_check

if [ ! -d /home/vaultwarden ]
then
    msg_box "Please install Vaultwarden before changing this option."
    exit 1
elif [ ! -f /home/vaultwarden/config.json ]
then
    msg_box "Please configure your smtp settings before changing this option."
    exit 1
fi

# Yes or No?
choice=$(whiptail --title "$TITLE" --menu \
"Do you want to disable the Vaultwarden admin-panel?
$MENU_GUIDE\n\n$RUN_LATER_GUIDE" "$WT_HEIGHT" "$WT_WIDTH" 4 \
"Yes" "(Disable the admin-panel)" \
"No" "(Enable the admin-panel and change the password for the admin-panel)" 3>&1 1>&2 2>&3)

case "$choice" in
    "Yes")
        print_text_in_color "$ICyan" "Stopping vaultwarden..."
        docker stop vaultwarden
        if grep -q '"admin_token":' /home/vaultwarden/config.json
        then
            sed -i 's|"admin_token":.*|"admin_token": "",|g' /home/vaultwarden/config.json
        else
            sed -i '0,/{/a \ \ "admin_token": "",' /home/vaultwarden/config.json
        fi
        print_text_in_color "$ICyan" "Starting vaultwarden..."
        docker start vaultwarden
        msg_box "The admin-panel for Vaultwarden is now disabled."
    ;;
    "No")
        print_text_in_color "$ICyan" "Stopping vaultwarden..."
        docker stop vaultwarden
        ADMIN_PASS=$(gen_passwd "$SHUF" "A-Za-z0-9")
        if grep -q '"admin_token":' /home/vaultwarden/config.json
        then
            sed -i "s|\"admin_token\":.*|\"admin_token\": \"$ADMIN_PASS\",|g" /home/vaultwarden/config.json
        else
            sed -i "0,/{/a \ \ \"admin_token\": \"$ADMIN_PASS\"," /home/vaultwarden/config.json
        fi
        print_text_in_color "$ICyan" "Starting vaultwarden..."
        docker start vaultwarden
        msg_box "The admin-panel for Vaultwarden is now enabled.\n
Please note the new admin-panel password: $ADMIN_PASS\n
Otherwise you will be unable to login to the admin-panel.\n
To change the password again, you can simply run this option (enable admin-panel) again."
    ;;
    *)
    ;;
esac
