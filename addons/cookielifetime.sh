#!/bin/bash

# T&M Hansson IT AB © - 2020, https://www.hanssonit.se/

true
SCRIPT_NAME="Set Cookie Lifetime"
# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh || source <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)

print_text_in_color "$ICyan" "Configuring Cookie Lifetime timeout..."

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Check if root
root_check

choice=$(whiptail --title "$TITLE" --menu \
"Configure the logout time (in seconds) which will forcefully logout \
the Nextcloud user from the web browser when the timeout is reached.
$MENU_GUIDE\n\n$RUN_LATER_GUIDE" "$WT_HEIGHT" "$WT_WIDTH" 4 \
"1800s" "30 minutes" \
"7200s" "2 hours" \
"43200s" "12 hours" \
"172800s" "2 days" \
"604800s" "1 week" \
"2419200s" "4 weeks" \
"Custom" "setup a custom time" 3>&1 1>&2 2>&3)

case "$choice" in
    "1800s")
        nextcloud_occ config:system:set remember_login_cookie_lifetime --value="1800"
    ;;
    "7200s")
        nextcloud_occ config:system:set remember_login_cookie_lifetime --value="7200"
    ;;
    "43200s")
        nextcloud_occ config:system:set remember_login_cookie_lifetime --value="43200"
    ;;
    "172800s")
        nextcloud_occ config:system:set remember_login_cookie_lifetime --value="172800"
    ;;
    "604800s")
        nextcloud_occ config:system:set remember_login_cookie_lifetime --value="604800"
    ;;
    "2419200s")
        nextcloud_occ config:system:set remember_login_cookie_lifetime --value="2419200"
    ;;
    "Custom")
        while :
        do
            COOKIE_LIFETIME=$(input_box "Configure the logout time (in seconds) which \
will forcefully logout the Nextcloud user from the web browser when the timeout is reached.

Please enter the Cookie Lifetime in seconds, so e.g. 1800 for 30 minutes or 3600 for 1 hour

You can not set a value below 30 minutes (1800 seconds).")
            if ! check_if_number "$COOKIE_LIFETIME"
            then
                msg_box "The value you entered doesn't seem to be a number between 0-9, please enter a valid number."
            elif [ "$COOKIE_LIFETIME" -lt "1800" ]
            then
                msg_box "Please choose a value more than 1800 seconds."
            elif ! yesno_box_yes "Is this correct? $COOKIE_LIFETIME seconds"
            then
                msg_box "It seems like you weren't satisfied with your setting of ($COOKIE_LIFETIME) seconds. Please try again."
            else
                if nextcloud_occ config:system:set remember_login_cookie_lifetime --value="$COOKIE_LIFETIME"
                then
                    msg_box "Cookie Lifetime is now successfully set to $COOKIE_LIFETIME seconds."
                fi
                break
            fi
        done
    ;;
    *)
    ;;
esac
