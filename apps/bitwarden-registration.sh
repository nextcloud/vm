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

# Must be root
root_check

# Check if Bitwarden is already installed
print_text_in_color "$ICyan" "Checking if Bitwarden is already installed..."
if [ is_docker_running ]
then
    if docker ps -a --format '{{.Names}}' | grep -Eq "bitwarden";
    then
        if is_this_installed apache2
        then
            if [ -d /root/bwdata ]
            then
                sleep 0.1
            else
                msg_box "Bitwarden doesn't seem to be installed. You can not run this script."
                exit 1
            fi
        fi
    fi
fi

# Yes or No?
choice=$(whiptail --title "Bitwarden Registration" --checklist "Do you want to disable Bitwarden User Registration?\nSelect by pressing the spacebar\nYou can view this menu later by running 'sudo bash $SCRIPTS/menu.sh'" "$WT_HEIGHT" "$WT_WIDTH" 4 \
"Yes" "(Disable public user registration)" OFF \
"No" "(Enable public user registration)" OFF \
"Cancel" "(Exit this menu)" OFF 3>&1 1>&2 2>&3)

case "$choice" in
    *"Yes"*)
        clear
        print_text_in_color "$ICyan" "Disabling Bitwarden User Regitration..."
        # Disable
        sed -i "s|globalSettings__disableUserRegistration=.*|globalSettings__disableUserRegistration=true|g" /root/bwdata/env/global.override.env
    ;;&
    *"No"*)
        clear
        print_text_in_color "$ICyan" "Enabling Bitwarden User Registration..."
        # Enable
        sed -i "s|globalSettings__disableUserRegistration=.*|globalSettings__disableUserRegistration=false|g" /root/bwdata/env/global.override.env
    ;;&
    *"Cancel"*)
        clear
        exit 1
    ;;&
    *)
    ;;
esac

# Restart Bitwarden
install_if_not curl
cd /root
curl_to_dir "https://raw.githubusercontent.com/bitwarden/core/master/scripts" "bitwarden.sh" "/root"
chmod +x /root/bitwarden.sh
check_command ./bitwarden.sh restart
