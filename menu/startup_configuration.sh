#!/bin/bash

# T&M Hansson IT AB © - 2020, https://www.hanssonit.se/

# shellcheck disable=2034,2059
true
SCRIPT_NAME="Startup Configuration Menu"
# shellcheck source=lib.sh
. <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Must be root
root_check

# Get the correct keyboard layout switch
if [ "$KEYBOARD_LAYOUT" = "us" ]
then
    KEYBOARD_LAYOUT_SWITCH="ON"
else
    KEYBOARD_LAYOUT_SWITCH="OFF"
fi

# Get the correct timezone switch
if [ "$(cat /etc/timezone)" = "Etc/UTC" ]
then
    TIMEZONE_SWITCH="ON"
else
    TIMEZONE_SWITCH="OFF"
fi

# Show a msg_box during the startup script
if [ -f "$SCRIPTS/nextcloud-startup-script.sh" ]
then
msg_box "Running a server, it's important that certain things are correct. 
In the following menu you will be asked to setup the most basic stuff of your server. 

The script is smart, and have already pre-selected the values that you'd want to change based on the current settings."
fi

# Startup configurations
choice=$(whiptail --title "$TITLE" --checklist "Choose what you want to change.\n$CHECKLIST_GUIDE\n$MENU_GUIDE" "$WT_HEIGHT" "$WT_WIDTH" 4 \
"Keyboard Layout" "(Change the keyboard layout from '$KEYBOARD_LAYOUT')" "$KEYBOARD_LAYOUT_SWITCH" \
"Timezone" "(Change the timezone from $(cat /etc/timezone))" "$TIMEZONE_SWITCH" \
"Locate Mirror" "(Change the apt-mirror for faster updates)" OFF 3>&1 1>&2 2>&3)

case "$choice" in
    *"Keyboard Layout"*)
        clear
        SUBTITLE="Keyboard Layout"
        msg_box "Current keyboard layout is $KEYBOARD_LAYOUT." "$SUBTITLE"
        if ! yesno_box_yes "Do you want to change keyboard layout?" "$SUBTITLE"
        then
            print_text_in_color "$ICyan" "Not changing keyboard layout..."
            sleep 1
            clear
        else
            dpkg-reconfigure keyboard-configuration
            setupcon --force
            # Set locales
            if ! [ -f "$SCRIPTS/nextcloud-startup-script.sh" ]
            then
                run_script ADDONS locales
            fi
            input_box "The Keyboard Layout was changed.\nPlease try out all buttons (e.g: @ # \$ : y n) to find out if the keyboard settings were correctly applied.\nIf the keyboard is still wrong, you will be offered to reboot the server in the next step.\n\nPlease continue by hitting [ENTER]" "$SUBTITLE" >/dev/null
            if ! yesno_box_yes "Did the keyboard work as expected??\n\nIf you choose 'No' the server will be rebooted. After the reboot, please login as usual and run this script again." "$SUBTITLE"
            then
                reboot
            fi
        fi
    ;;&
    *"Timezone"*)
        clear
        SUBTITLE="Timezone"
        msg_box "Current timezone is $(cat /etc/timezone)" "$SUBTITLE"
        if ! yesno_box_yes "Do you want to change the timezone?" "$SUBTITLE"
        then
            print_text_in_color "$ICyan" "Not changing timezone..."
            sleep 1
            clear
        else
            dpkg-reconfigure tzdata
        fi
        # Change timezone in php and logging if the startup script not exists
        if ! [ -f "$SCRIPTS/nextcloud-startup-script.sh" ]
        then
            # Change timezone in PHP
            sed -i "s|;date.timezone.*|date.timezone = $(cat /etc/timezone)|g" "$PHP_INI"

            # Change timezone for logging
            occ_command config:system:set logtimezone --value="$(cat /etc/timezone)"
            msg_box "The timezone was changed successfully." "$SUBTITLE"
            clear
        fi
    ;;&
    *"Locate Mirror"*)
        clear
        print_text_in_color "$ICyan" "Downloading the Locate Mirror script..."
        run_script ADDONS locate_mirror
    ;;&
    *)
    ;;
esac
exit
