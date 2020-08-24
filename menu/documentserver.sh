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

choice=$(whiptail --title "Which Documentserver do you want to install?" --radiolist "Automatically configure and install the selected Documentserver.\nSelect by pressing the spacebar and ENTER\nYou can view this menu later by running 'sudo bash $SCRIPTS/menu.sh'" "$WT_HEIGHT" "$WT_WIDTH" 4 \
"Collabora (Docker)" "(Online editing - Extra Subdomain required)" OFF \
"Collabora (Integrated)" "(Online editing - No Subdomain required)" OFF \
"OnlyOffice (Docker)" "(Online editing - Extra Subdomain required)" OFF \
"OnlyOffice (Integrated)" "(Online editing - No Subdomain required)" OFF 3>&1 1>&2 2>&3)

case "$choice" in
    "Collabora (Docker)")
        clear
        print_text_in_color "$ICyan" "Downloading the Collabora (Docker) script..."
        run_script APP collabora_docker
    ;;
    "Collabora (Integrated)")
        clear
        print_text_in_color "$ICyan" "Downloading the Collabora (Integrated) script..."
        run_script APP collabora_integrated
    ;;
    "OnlyOffice (Docker)")
        clear
        print_text_in_color "$ICyan" "Downloading the OnlyOffice (Docker) script..."
        run_script APP onlyoffice_docker
    ;;
    "OnlyOffice (Integrated)")
        clear
        print_text_in_color "$ICyan" "Downloading the OnlyOffice (Integrated) script..."
        run_script APP onlyoffice_integrated
    ;;
    *)
    ;;
esac
exit
