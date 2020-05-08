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
        bash $SCRIPTS/apps.sh
    ;;
    "Nextcloud Configuration")
        bash $SCRIPTS/config.sh
    ;;
    "Server Configuration")
        bash $SCRIPTS/server_configuration.sh
    ;;
    "Update Nextcloud")
        bash $SCRIPTS/update.sh
    ;;
    *)
    ;;
esac
exit
