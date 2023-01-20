#!/bin/bash

# T&M Hansson IT AB © - 2023, https://www.hanssonit.se/

true
SCRIPT_NAME="Documentserver Menu"
# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh

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
"Collabora (Integrated)" "(Online editing - No Subdomain required)" \
"OnlyOffice (Docker)" "(Online editing - Extra Subdomain required)" \
"OnlyOffice (Integrated)" "(Online editing - No Subdomain required)" 3>&1 1>&2 2>&3)

case "$choice" in
    "Collabora (Docker)")
        print_text_in_color "$ICyan" "Downloading the Collabora (Docker) script..."
        run_script APP collabora_docker
    ;;
    "Collabora (Integrated)")
        print_text_in_color "$ICyan" "Downloading the Collabora (Integrated) script..."
        run_script APP collabora_integrated
    ;;
    "OnlyOffice (Docker)")
        print_text_in_color "$ICyan" "Downloading the OnlyOffice (Docker) script..."
        run_script APP onlyoffice_docker
    ;;
    "OnlyOffice (Integrated)")
        print_text_in_color "$ICyan" "Downloading the OnlyOffice (Integrated) script..."
        run_script APP onlyoffice_integrated
    ;;
    *)
    ;;
esac
exit
