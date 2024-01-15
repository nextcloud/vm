#!/bin/bash

# T&M Hansson IT AB © - 2024, https://www.hanssonit.se/

true
SCRIPT_NAME="deSEC Menu"
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
"Please choose one of the deSEC options below.
$MENU_GUIDE\n\n$RUN_LATER_GUIDE" "$WT_HEIGHT" "$WT_WIDTH" 4 \
"Install deSEC" "(Setup deSEC fully automated: yourdomain.dedyn.io)" \
"deSEC Subdomain" "(Add or delete subdomains to an existing deSEC domain)" \
"Remove deSEC" "(Remove your deSEC account completely" 3>&1 1>&2 2>&3)

case "$choice" in
    "Install deSEC")
        print_text_in_color "$ICyan" "Downloading the deSEC install script..."
        run_script DESEC desec
    ;;
    "deSEC Subdomain")
        print_text_in_color "$ICyan" "Downloading the deSEC subdomain script..."
        run_script DESEC desec_subdomain
    ;;
    "Remove deSEC")
        print_text_in_color "$ICyan" "Downloading the remove deSEC script..."
        run_script DESEC remove_desec
    ;;
    *)
    ;;
esac
exit
