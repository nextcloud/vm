#!/bin/bash

# T&M Hansson IT AB © - 2024, https://www.hanssonit.se/

true
SCRIPT_NAME="Bitwarden Registration"
# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Must be root
root_check

# Check if Bitwarden is already installed
print_text_in_color "$ICyan" "Checking if Bitwarden is already installed..."
if is_docker_running
then
    if docker ps -a --format '{{.Names}}' | grep -Eq "bitwarden";
    then
        if [ ! -d /root/bwdata ] && [ ! -d "$BITWARDEN_HOME"/bwdata ]
        then
            msg_box "It seems like 'Bitwarden' isn't installed.\n\nYou cannot run this script."
            exit 1
        fi
    else
        msg_box "It seems like 'Bitwarden' isn't installed.\n\nYou cannot run this script."
        exit 1
    fi
else
    msg_box "It seems like 'Bitwarden' isn't installed.\n\nYou cannot run this script."
    exit 1
fi

# Yes or No?
choice=$(whiptail --title "$TITLE" --menu \
"Do you want to disable Bitwarden User Registration?
$MENU_GUIDE\n\n$RUN_LATER_GUIDE" "$WT_HEIGHT" "$WT_WIDTH" 4 \
"Yes" "(Disable public user registration)" \
"No" "(Enable public user registration)" 3>&1 1>&2 2>&3)

case "$choice" in
    "Yes")
        print_text_in_color "$ICyan" "Disabling Bitwarden User Regitration..."
        # Disable
        if [ -f /root/bwdata/env/global.override.env ]
        then
            sed -i "s|globalSettings__disableUserRegistration=.*|globalSettings__disableUserRegistration=true|g" /root/bwdata/env/global.override.env
            # Restart Bitwarden
            install_if_not curl
            cd /root
            curl_to_dir "https://raw.githubusercontent.com/bitwarden/core/master/scripts" "bitwarden.sh" "/root"
            chmod +x /root/bitwarden.sh
            check_command ./bitwarden.sh restart
        elif [ -f "$BITWARDEN_HOME"/bwdata/env/global.override.env ]
        then
            sed -i "s|globalSettings__disableUserRegistration=.*|globalSettings__disableUserRegistration=true|g" "$BITWARDEN_HOME"/bwdata/env/global.override.env
            # Restart Bitwarden
            install_if_not curl
            cd "$BITWARDEN_HOME"
            curl_to_dir "https://raw.githubusercontent.com/bitwarden/core/master/scripts" "bitwarden.sh" "$BITWARDEN_HOME"
            chown "$BITWARDEN_USER":"$BITWARDEN_USER" "$BITWARDEN_HOME"/bitwarden.sh
            chmod +x "$BITWARDEN_HOME"/bitwarden.sh
            check_command systemctl restart bitwarden
        fi
    ;;
    "No")
        print_text_in_color "$ICyan" "Enabling Bitwarden User Registration..."
        # Enable
        if [ -f /root/bwdata/env/global.override.env ]
        then
            sed -i "s|globalSettings__disableUserRegistration=.*|globalSettings__disableUserRegistration=false|g" /root/bwdata/env/global.override.env
            # Restart Bitwarden
            install_if_not curl
            cd /root
            curl_to_dir "https://raw.githubusercontent.com/bitwarden/core/master/scripts" "bitwarden.sh" "/root"
            chmod +x /root/bitwarden.sh
            check_command ./bitwarden.sh restart
        elif [ -f "$BITWARDEN_HOME"/bwdata/env/global.override.env ]
        then
            sed -i "s|globalSettings__disableUserRegistration=.*|globalSettings__disableUserRegistration=false|g" "$BITWARDEN_HOME"/bwdata/env/global.override.env
            # Restart Bitwarden
            install_if_not curl
            cd "$BITWARDEN_HOME"
            curl_to_dir "https://raw.githubusercontent.com/bitwarden/core/master/scripts" "bitwarden.sh" "$BITWARDEN_HOME"
            chown "$BITWARDEN_USER":"$BITWARDEN_USER" "$BITWARDEN_HOME"/bitwarden.sh
            chmod +x "$BITWARDEN_HOME"/bitwarden.sh
            check_command systemctl restart bitwarden
        fi
    ;;
    "")
        exit
    ;;
    *)
    ;;
esac

msg_box "Bitwarden is now restarting. This can take a few minutes. Please wait until it is done."
