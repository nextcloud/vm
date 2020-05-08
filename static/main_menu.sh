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
choice=$(whiptail --title "Main Menu" --radiolist "Choose the menu you want to see or execute updates.\nSelect by pressing the spacebar and ENTER" "$WT_HEIGHT" "$WT_WIDTH" 4 \
"Additional Apps" "(See a list of available Apps)" OFF \
"Nextcloud Configuration" "(See a list of available Nextcloud Configuration)" OFF \
"Server Configuration" "(See a list of available Server Configuration)" OFF \
"Update Nextcloud" "(Update Nextcloud to the latest release)" OFF 3>&1 1>&2 2>&3)

case "$choice" in
    "Additional Apps")
        if [ -f $SCRIPTS/apps.sh ]
        then
            bash $SCRIPTS/apps.sh
        else
            if network_ok
            then
                run_app_script additional_apps
            fi
        fi
    ;;
    "Nextcloud Configuration")
        if [ -f $SCRIPTS/configuration.sh ]
        then
            bash $SCRIPTS/configuration.sh
        else
            if network_ok
            then
                run_static_script nextcloud_configuration
            fi
        fi
    ;;
    "Server Configuration")
        if [ -f $SCRIPTS/server_configuration.sh ]
        then
            bash $SCRIPTS/server_configuration.sh
        else
            if network_ok
            then
                run_static_script server_configuration
            fi
        fi
    ;;
    "Update Nextcloud")
        if [ -f $SCRIPTS/update.sh ]
        then
            bash $SCRIPTS/update.sh
        else
            if network_ok
            then
                run_main_script nextcloud_update
            fi
        fi
    ;;
    *)
    ;;
esac
exit
