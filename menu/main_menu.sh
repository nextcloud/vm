#!/bin/bash

# T&M Hansson IT AB © - 2021, https://www.hanssonit.se/

true
SCRIPT_NAME="Main Menu"
# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh || source <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)

# Needed for Update option
nc_update

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Must be root
root_check

# Main menu
choice=$(whiptail --title "$TITLE" --menu \
"Choose what you want to do.
$MENU_GUIDE\n\n$RUN_LATER_GUIDE" "$WT_HEIGHT" "$WT_WIDTH" 4 \
"Additional Apps" "(Choose which apps to install)" \
"Nextcloud Configuration" "(Choose between available Nextcloud configurations)" \
"Startup Configuration" "(Choose between available startup configurations)" \
"Server Configuration" "(Choose between available server configurations)" \
"Update Nextcloud" "(Update Nextcloud to the latest release)" 3>&1 1>&2 2>&3)

case "$choice" in
    "Additional Apps")
        print_text_in_color "$ICyan" "Downloading the Additional Apps Menu..."
        run_script MENU additional_apps
    ;;
    "Nextcloud Configuration")
        print_text_in_color "$ICyan" "Downloading the Nextcloud Configuration Menu..."
        run_script MENU nextcloud_configuration
    ;;
    "Startup Configuration")
        print_text_in_color "$ICyan" "Downloading the Startup Configuration Menu..."
        run_script MENU startup_configuration
    ;;
    "Server Configuration")
        print_text_in_color "$ICyan" "Downloading the Server Configuration Menu..."
        run_script MENU server_configuration
    ;;
    "Update Nextcloud")
do_the_update() {
    chmod +x "$SCRIPTS"/update.sh
    bash "$SCRIPTS"/update.sh minor
    if version_gt "$NCVERSION" "$CURRENTVERSION"
    then
        if yesno_box_yes "We will now run the update script a second time to update to the latest major version ($NCVERSION). Do you want to continue?"
        then
            bash "$SCRIPTS"/update.sh
        fi
    fi
}
    if [ -f "$SCRIPTS"/update.sh ]
    then
        # Check if automated updates are set
        REBOOT_SET=$(grep -r "shutdown -r" "$SCRIPTS"/update.sh)
        # Check if it's older than 60 days (60 seconds * 60 minutes * 24 hours * 60 days)
        if [ "$(stat --format=%Y "$SCRIPTS"/update.sh)" -le "$(( $(date +%s) - ((60*60*24*60)) ))" ]
        then
            print_text_in_color "$ICyan" "Downloading the latest update script..."
            download_script STATIC update
            if [ -n "$REBOOT_SET" ]
            then
                sed -i "s|exit|/sbin/shutdown -r +1|g" "$SCRIPTS"/update.sh
            fi
            do_the_update
        else
            do_the_update
        fi
    else
        print_text_in_color "$ICyan" "Downloading the latest update script..."
        download_script STATIC update
        do_the_update
    fi
    ;;
    *)
    ;;
esac
exit
