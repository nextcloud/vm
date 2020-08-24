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

# Main menu
choice=$(whiptail --title "Main Menu" --radiolist "Choose what you want to do.\nSelect by pressing the spacebar and ENTER\nYou can view this menu later by running 'sudo bash $SCRIPTS/menu.sh" "$WT_HEIGHT" "$WT_WIDTH" 4 \
"Additional Apps" "(Choose which apps to install)" OFF \
"Nextcloud Configuration" "(Choose between available Nextcloud configurations)" OFF \
"Server Configuration" "(Choose between available server configurations)" OFF \
"Update Nextcloud" "(Update Nextcloud to the latest release)" OFF 3>&1 1>&2 2>&3)

case "$choice" in
    "Additional Apps")
        print_text_in_color "$ICyan" "Downloading the Additional Apps script..."
        run_script MENU additional_apps
    ;;
    "Nextcloud Configuration")
        print_text_in_color "$ICyan" "Downloading the Nextcloud Configuration script..."
        run_script MENU nextcloud_configuration
    ;;
    "Server Configuration")
        print_text_in_color "$ICyan" "Downloading the Server Configuration script..."
        run_script MENU server_configuration
    ;;
    "Update Nextcloud")
        if [ -f $SCRIPTS/update.sh ]
        then
            bash $SCRIPTS/update.sh
        else
            print_text_in_color "$ICyan" "Downloading the Update script..."
            download_script STATIC update
            bash $SCRIPTS/update.sh
        fi
    ;;
    *)
    ;;
esac
exit
