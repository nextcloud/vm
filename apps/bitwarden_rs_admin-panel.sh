#!/bin/bash

# T&M Hansson IT AB © - 2020, https://www.hanssonit.se/

# shellcheck disable=2034,2059
true

# shellcheck source=lib.sh
. <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Check if root
root_check

if [ ! -d /home/bitwarden_rs ]
then
    msg_box "Please install Bitwarden_rs before changing this option."
    exit 1
elif [ ! -f /home/bitwarden_rs/config.json ]
then
    msg_box "Please configure your smtp settings before changing this option."
    exit 1
fi

# Yes or No?
choice=$(whiptail --title "Bitwarden_rs admin-panel" --radiolist "Do you want to disable the Bitwarden_rs admin-panel?\nSelect by pressing the spacebar\nYou can view this menu later by running 'sudo bash $SCRIPTS/menu.sh'" "$WT_HEIGHT" "$WT_WIDTH" 4 \
"Yes" "(Disable the admin-panel)" OFF \
"No" "(Enable the admin-panel and change the password for the admin-panel)" OFF 3>&1 1>&2 2>&3)

case "$choice" in
    "Yes")
        clear
        print_text_in_color "$ICyan" "Stopping bitwarden_rs..."
        docker stop bitwarden_rs
        if grep -q '"admin_token":' /home/bitwarden_rs/config.json
        then
            sed -i 's|"admin_token":.*|"admin_token": "",|g' /home/bitwarden_rs/config.json
        else
            sed -i '0,/{/a \ \ "admin_token": "",' /home/bitwarden_rs/config.json
        fi
        docker start bitwarden_rs
        msg_box "The admin-panel for Bitwarden_rs is now disabled."
    ;;
    "No")
        clear
        print_text_in_color "$ICyan" "Stopping bitwarden_rs..."
        docker stop bitwarden_rs
        ADMIN_PASS=$(gen_passwd "$SHUF" "A-Za-z0-9")
        if grep -q '"admin_token":' /home/bitwarden_rs/config.json
        then
            sed -i "s|\"admin_token\":.*|\"admin_token\": \"$ADMIN_PASS\",|g" /home/bitwarden_rs/config.json
        else
            sed -i "0,/{/a \ \ \"admin_token\": \"$ADMIN_PASS\"," /home/bitwarden_rs/config.json
        fi
        docker start bitwarden_rs
msg_box "The admin-panel for Bitwarden_rs is now enabled.\n
Please note down the new admin-panel password: $ADMIN_PASS\n
Otherwise you will not be able to login to the admin-panel.\n
To change the password again, you can simply run this option (enable admin-panel) again."
    ;;
    *)
    ;;
esac
