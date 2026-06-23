#!/bin/bash

# T&M Hansson IT AB © - 2026, https://www.hanssonit.se/

true
SCRIPT_NAME="Documentserver menu"
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
"Which Documentserver for online editing do you want to install?\n\nWe recommend Collabora with Docker. The subdomain could look like this:\noffice.your-nextcloud.tld\n\nAutomatically configure and install the selected Documentserver.
$MENU_GUIDE\n\n$RUN_LATER_GUIDE" "$WT_HEIGHT" "$WT_WIDTH" 3 \
"Collabora (Docker)" "(Extra Subdomain required)" \
"Collabora (Integrated)" "(No Subdomain required)" \
"EuroOffice (Docker)" "(Extra Subdomain required)" 3>&1 1>&2 2>&3)

case "$choice" in
    "Collabora (Docker)")
        print_text_in_color "$ICyan" "Downloading the Collabora (Docker) script..."
        run_script APP collabora_docker
    ;;
    "Collabora (Integrated)")
        print_text_in_color "$ICyan" "Downloading the Collabora (Integrated) script..."
        run_script APP collabora_integrated
    ;;
    "EuroOffice (Docker)")
        print_text_in_color "$ICyan" "Downloading the EuroOffice (Docker) script..."
        run_script APP eurooffice_docker
    ;;
    *)
    ;;
esac
exit
