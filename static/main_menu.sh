#!/bin/bash

# T&M Hansson IT AB © - 2020, https://www.hanssonit.se/

# shellcheck disable=2034,2059
true
SCRIPT_NAME="Main Menu"
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
choice=$(whiptail --title "$TITLE" --menu \
"Choose what you want to do.
$MENU_GUIDE\n\n$RUN_LATER_GUIDE" "$WT_HEIGHT" "$WT_WIDTH" 4 \
"Additional Apps" "(Choose which apps to install)" \
"Nextcloud Configuration" "(Choose between available Nextcloud configurations)" \
"Server Configuration" "(Choose between available server configurations)" \
"Update Nextcloud" "(Update Nextcloud to the latest release)" 3>&1 1>&2 2>&3)

case "$choice" in
    "Additional Apps")
        if network_ok
        then
            run_script MENU additional_apps
        fi
    ;;
    "Nextcloud Configuration")
        if network_ok
        then
            run_script MENU nextcloud_configuration
        fi
    ;;
    "Server Configuration")
        if network_ok
        then
            run_script MENU server_configuration
        fi
    ;;
    "Update Nextcloud")
        if [ -f $SCRIPTS/update.sh ]
        then
            bash $SCRIPTS/update.sh
        else
            if network_ok
            then
                download_script STATIC update
                bash $SCRIPTS/update.sh
            fi
        fi
    ;;
    *)
    ;;
esac
exit
