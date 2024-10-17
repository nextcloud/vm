#!/bin/bash

# T&M Hansson IT AB © - 2024, https://www.hanssonit.se/

true
SCRIPT_NAME="Startup Configuration Menu"
# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Update the lib once during the startup script
# TODO: delete this again e.g. with NC 20.0.1
# download_script GITHUB_REPO lib #### removed in 21.0.0, delete it completely in a later version

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

# Get the correct apt-mirror
# Handle several sources
FIND_SOURCES="$(find /etc/apt/ -type f -name "*sources*")"
for source in $FIND_SOURCES
do
  REPO=$(grep "URIs:" "$source" | grep http | awk '{print $2}' | head -1)
done
# Check if it matches
if [ "$REPO" = 'http://archive.ubuntu.com/ubuntu' ]
then
    MIRROR_SWITCH="ON"
else
    MIRROR_SWITCH="OFF"
fi

# Show a msg_box during the startup script
if [ -f "$SCRIPTS/nextcloud-startup-script.sh" ]
then
    msg_box "Running a server, it's important that certain things are correct.
In the following menu you will be asked to set up the most basic stuff of your server.

The script is smart, and have already pre-selected the values that you'd want to change based on the current settings."
fi

# Startup configurations
choice=$(whiptail --title "$TITLE" --checklist \
"Choose what you want to change.
$CHECKLIST_GUIDE\n\n$RUN_LATER_GUIDE" "$WT_HEIGHT" "$WT_WIDTH" 4 \
"Keyboard Layout" "(Change the keyboard layout from '$KEYBOARD_LAYOUT')" "$KEYBOARD_LAYOUT_SWITCH" \
"Timezone" "(Change the timezone from $(cat /etc/timezone))" "$TIMEZONE_SWITCH" \
"Locate Mirror" "(Change the apt repo for better download performance)" "$MIRROR_SWITCH" 3>&1 1>&2 2>&3)

case "$choice" in
    *"Keyboard Layout"*)
        SUBTITLE="Keyboard Layout"
        msg_box "Current keyboard layout is $KEYBOARD_LAYOUT." "$SUBTITLE"
        if ! yesno_box_yes "Do you want to change keyboard layout?" "$SUBTITLE"
        then
            print_text_in_color "$ICyan" "Not changing keyboard layout..."
            sleep 1
        else
            # Change layout
            dpkg-reconfigure keyboard-configuration
            setupcon --force
            # Set locales
            run_script ADDONS locales
            input_box "Please try out all buttons (e.g: @ # \$ : y n) \
to find out if the keyboard settings were correctly applied.
If the keyboard is still wrong, you will be offered to reboot the server in the next step.

Please continue by hitting [ENTER]" "$SUBTITLE" >/dev/null
            if ! yesno_box_yes "Did the keyboard work as expected?\n\nIf you choose 'No' \
the server will be rebooted. After the reboot, please login as usual and run this script again." "$SUBTITLE"
            then
                reboot
            fi
        fi
    ;;&
    *"Timezone"*)
        SUBTITLE="Timezone"
        msg_box "Current timezone is $(cat /etc/timezone)" "$SUBTITLE"
        if ! yesno_box_yes "Do you want to change the timezone?" "$SUBTITLE"
        then
            print_text_in_color "$ICyan" "Not changing timezone..."
            sleep 1
        else
            if dpkg-reconfigure tzdata
            then
                # Change timezone in php and logging if the startup script not exists
                if ! [ -f "$SCRIPTS/nextcloud-startup-script.sh" ]
                then
                    # Change timezone in PHP
                    sed -i "s|;date.timezone.*|date.timezone = $(cat /etc/timezone)|g" "$PHP_INI"

                    # Change timezone for logging
                    nextcloud_occ config:system:set logtimezone --value="$(cat /etc/timezone)"
                    msg_box "The timezone was changed successfully." "$SUBTITLE"
                fi
            fi
        fi
    ;;&
    *"Locate Mirror"*)
        SUBTITLE="apt-mirror"
        print_text_in_color "$ICyan" "Downloading the Locate Mirror script..."
        run_script ADDONS locate_mirror
    ;;&
    *)
    ;;
esac
exit
