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

choice=$(whiptail --title "Bitwarden" --checklist "Automatically configure and install the Bitwarden or configure some aspects of it.\nSelect by pressing the spacebar\nYou can view this menu later by running 'sudo bash $SCRIPTS/menu.sh'" "$WT_HEIGHT" "$WT_WIDTH" 4 \
"Bitwarden " "(External password manager [4GB RAM] - subdomain required)" OFF \
"Bitwarden-Registration" "(Enable or disable public user registration for Bitwarden)" OFF \
"Bitwarden-Mail-Configuration" "(Configure the mailserver settings for Bitwarden)" OFF 3>&1 1>&2 2>&3)

case "$choice" in
    *"Bitwarden "*)
        clear
        print_text_in_color "$ICyan" "Downloading Bitwarden.sh..."
        run_script APP tmbitwarden
    ;;&
    *"Bitwarden-Registration"*)
        clear
        print_text_in_color "$ICyan" "Downloading Bitwarden-registration.sh..."
        run_script APP bitwarden-registration
    ;;&
    *"Bitwarden-Mail-Configuration"*)
        clear
        print_text_in_color "$ICyan" "Downloading Bitwarden-Mailconfig.sh..."
        run_script APP bitwarden-mailconfig
    ;;&
    *)
    ;;
esac
exit
