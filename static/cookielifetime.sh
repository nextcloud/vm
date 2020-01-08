#!/bin/bash

# T&M Hansson IT AB © - 2019, https://www.hanssonit.se/

# shellcheck disable=2034,2059
true
# shellcheck source=lib.sh
. <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)

print_text_in_color "$ICyan" "Configuring automatic updates..."

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Check if root
root_check

COOKIE_LIFETIME=$(whiptail --radiolist  "Configure the logout time (in seconds) which will forcefully logout the Nextcloud user from the web browser when the timeout is reached.\n\nSelect one with the [ARROW] keys and select with the [SPACE] key. Confirm by pressing [ENTER]" "$WT_HEIGHT" "$WT_WIDTH" 4 \
"1800s" "30 minutes" ON \
"7200s" "2 hours" OFF \
"43200s" "12 hours" OFF \
"172800s" "2 days" OFF \
"604800s" "1 week" OFF \
"2419200s" "4 weeks" OFF \
"Custom" "Setup a custom time" OFF 3>&1 1>&2 2>&3)

if [ "$COOKIE_LIFETIME" == "1800s" ]
then
    occ_command config:system:set remember_login_cookie_lifetime --value="1800"
elif [ "$COOKIE_LIFETIME" == "7200s" ]
then
    occ_command config:system:set remember_login_cookie_lifetime --value="7200"
elif [ "$COOKIE_LIFETIME" == "43200s" ]
then
    occ_command config:system:set remember_login_cookie_lifetime --value="43200"
elif [ "$COOKIE_LIFETIME" == "172800s" ]
then
    occ_command config:system:set remember_login_cookie_lifetime --value="172800"
elif [ "$COOKIE_LIFETIME" == "604800s" ]
then
    occ_command config:system:set remember_login_cookie_lifetime --value="604800"
elif [ "$COOKIE_LIFETIME" == "2419200s" ]
then
    occ_command config:system:set remember_login_cookie_lifetime --value="2419200"
elif [ "$COOKIE_LIFETIME" == "Custom" ]
then
    while true
    do
        COOKIE_LIFETIME=$(whiptail --inputbox "Configure the logout time (in seconds) which will forcefully logout the Nextcloud user from the web browser when the timeout is reached.\n\nPlease enter the Cookie Lifetime in seconds, so e.g. 1800 for 30 minutes or 3600 for 1 hour\n\n You can not set a value below 30 minutes (1800 seconds)." "$WT_HEIGHT" "$WT_WIDTH" 1800 3>&1 1>&2 2>&3)
        if ! check_if_number "$COOKIE_LIFETIME"
        then
            msg_box "The value you entered doesn't seem to be a number between 0-9, please enter a valid number."
        else
            break
        fi
    done
    while true
    do
        if [ "$COOKIE_LIFETIME" -lt "1800" ] || [ "$COOKIE_LIFETIME" == "" ]
        then
            msg_box "It seems like you have chosen a value below 30 minutes. Please try again."
        elif [[ "no" == $(ask_yes_or_no "Is this correct? $COOKIE_LIFETIME seconds")  ]]
        then
            msg_box "It seems like you weren't satisfied with your setting of ($COOKIE_LIFETIME) seconds. Please try again."
        else
            occ_command config:system:set remember_login_cookie_lifetime --value="$COOKIE_LIFETIME"
            break
        fi
    done
fi
