#!/bin/bash

# T&M Hansson IT AB © - 2020, https://www.hanssonit.se/

# shellcheck disable=2034,2059
true
SCRIPT_NAME="Bitwarden Menu"
# shellcheck source=lib.sh
. <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Must be root
root_check

choice=$(whiptail --title "$TITLE" --checklist "Automatically configure and install the Bitwarden or configure some aspects of it.\n$CHECKLIST_GUIDE\n$MENU_GUIDE" "$WT_HEIGHT" "$WT_WIDTH" 4 \
"Bitwarden  " "(External password manager [4GB RAM] - subdomain required)" OFF \
"Bitwarden Registration" "(Enable or disable public user registration for Bitwarden)" OFF \
"Bitwarden Mail-Configuration" "(Configure the mailserver settings for Bitwarden)" OFF \
"Bitwarden-RS  " "(Unofficial Bitwarden password manager - subdomain required)" OFF \
"Bitwarden-RS Admin-panel" "(Enable or disable the admin-panel for Bitwarden-RS)" OFF 3>&1 1>&2 2>&3)

case "$choice" in
    *"Bitwarden  "*)
        clear
        print_text_in_color "$ICyan" "Downloading the Bitwarden script..."
        run_script APP tmbitwarden
    ;;&
    *"Bitwarden Registration"*)
        clear
        print_text_in_color "$ICyan" "Downloading the Bitwarden Registration script..."
        run_script APP bitwarden_registration
    ;;&
    *"Bitwarden Mail-Configuration"*)
        clear
        print_text_in_color "$ICyan" "Downloading the Bitwarden Mailconfig script..."
        run_script APP bitwarden_mailconfig
    ;;&
    *"Bitwarden-RS  "*)
        clear
        print_text_in_color "$ICyan" "Downloading the Bitwarden-RS script..."
        run_script APP bitwarden-rs
    ;;&
    *"Bitwarden-RS Admin-panel"*)
        clear
        print_text_in_color "$ICyan" "Downloading the Bitwarden-RS Admin-panel script..."
        run_script APP bitwarden-rs_admin-panel
    ;;&
    *)
    ;;
esac
exit
