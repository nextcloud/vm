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

# Startup configurations
choice=$(whiptail --title "$TITLE" --checklist "Choose what you want to change\n$CHECKLIST_GUIDE" "$WT_HEIGHT" "$WT_WIDTH" 4 \
"Keyboard Layout" "(Change the keyboard layout)" "$KEYBOARD_LAYOUT_SWITCH" \
"Timezone" "(Change the timezone)" "$TIMEZONE_SWITCH" \
"Locate Mirror" "(Change the apt-mirror for faster udpates)" OFF 3>&1 1>&2 2>&3)

case "$choice" in
    *"Keyboard Layout"*)
        clear
        msg_box "Current keyboard layout is English (United States)."
        if ! yesno_box_yes "Do you want to change keyboard layout?"
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
            input_box "Please try out all buttons to find out if the keyboard settings were correctly applied.\nIf this isn't the case, you will have the chance to reboot the server in the next step.\n\nPlease continue by hitting [ENTER]" >/dev/null
            if yesno_box_no "Do you want to reboot the server?\nPlease only choose 'Yes' if the keyboard settings weren't correctly applied.\n\nIf you choose 'Yes' and the server is rebooted, please login as usual and run this script again."
            then
                reboot
            fi
        fi
    ;;&
    *"Timezone"*)
        clear
        msg_box "Current timezone is $(cat /etc/timezone)"
        if ! yesno_box_yes "Do you want to change the timezone?"
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
