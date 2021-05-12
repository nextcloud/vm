#!/bin/bash

# T&M Hansson IT AB © - 2021, https://www.hanssonit.se/

true
SCRIPT_NAME="Documentserver Menu"
# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh || source <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Must be root
root_check

choice=$(whiptail --title "$TITLE" --menu \
"Which Documentserver do you want to install?\n\nAutomatically configure and install the selected Documentserver.
$MENU_GUIDE\n\n$RUN_LATER_GUIDE" "$WT_HEIGHT" "$WT_WIDTH" 4 \
"Collabora (Docker)" "(Online editing - Extra Subdomain required)" \
"OnlyOffice (Docker)" "(Online editing - Extra Subdomain required)" 3>&1 1>&2 2>&3)

case "$choice" in
    "Collabora (Docker)")
        print_text_in_color "$ICyan" "Downloading the Collabora (Docker) script..."
        run_script APP collabora_docker
    ;;
    "OnlyOffice (Docker)")
        print_text_in_color "$ICyan" "Downloading the OnlyOffice (Docker) script..."
        run_script APP onlyoffice_docker
    ;;
    *)
    ;;
esac
exit
