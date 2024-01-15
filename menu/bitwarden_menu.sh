#!/bin/bash

# T&M Hansson IT AB © - 2024, https://www.hanssonit.se/

true
SCRIPT_NAME="Bitwarden Menu"
# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Must be root
root_check

# Set the startup switch
if [ -f "$SCRIPTS/nextcloud-startup-script.sh" ]
then
    STARTUP_SWITCH="ON"
else
    STARTUP_SWITCH="OFF"
fi

choice=$(whiptail --title "$TITLE" --checklist \
"Automatically configure and install the Bitwarden or configure some aspects of it.
$CHECKLIST_GUIDE\n\n$RUN_LATER_GUIDE" "$WT_HEIGHT" "$WT_WIDTH" 4 \
"Bitwarden  " "(External password manager [4GB RAM] - subdomain required)" OFF \
"Bitwarden Registration" "(Enable or disable public user registration for Bitwarden)" OFF \
"Bitwarden Mail-Configuration" "(Configure the mailserver settings for Bitwarden)" OFF \
"Vaultwarden  " "(Unofficial Bitwarden password manager - subdomain required)" OFF \
"Vaultwarden Admin-panel" "(Enable or disable the admin-panel for Vaultwarden)" OFF 3>&1 1>&2 2>&3)

case "$choice" in
    *"Bitwarden  "*)
        print_text_in_color "$ICyan" "Downloading the Bitwarden script..."
        run_script APP tmbitwarden
    ;;&
    *"Bitwarden Registration"*)
        print_text_in_color "$ICyan" "Downloading the Bitwarden Registration script..."
        run_script APP bitwarden_registration
    ;;&
    *"Bitwarden Mail-Configuration"*)
        print_text_in_color "$ICyan" "Downloading the Bitwarden Mailconfig script..."
        run_script APP bitwarden_mailconfig
    ;;&
    *"Vaultwarden  "*)
        print_text_in_color "$ICyan" "Downloading the Vaultwarden script..."
        run_script APP vaultwarden
    ;;&
    *"Vaultwarden Admin-panel"*)
        print_text_in_color "$ICyan" "Downloading the Vaultwarden Admin-panel script..."
        run_script APP vaultwarden_admin-panel
    ;;&
    *)
    ;;
esac
exit
