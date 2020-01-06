#!/bin/bash

# shellcheck disable=2034,2059
true
# shellcheck source=lib.sh
. <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Check if root
root_check

COOKIE_LIFETIME=$(whiptail --radiolist  "Configure after what time (in seconds) after every Login every Nextcloud user gets logged out in the Browser\nSelect one with the [ARROW] Keys and the [SPACE] key and confirm by pressing [ENTER]" "$WT_HEIGHT" "$WT_WIDTH" 4 \
"1800s" "half an hour" ON \
"7200s" "two hours" OFF \
"43200s" "half a day" OFF \
"172800s" "two days" OFF \
"604800s" "one week" OFF \
"2419200s" "four weeks" OFF \
"Custom" "setup a custom time" OFF 3>&1 1>&2 2>&3)

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
        COOKIE_LIFETIME=$(whiptail --inputbox "Configure after what time (in seconds) after every Login every Nextcloud user gets logged out in the Browser\nPlease enter the Cookie Lifetime in seconds, so e.g. 1800 for half an hour or 3600 for an hour\nIt is not recommended to set it to less than half an hour!" "$WT_HEIGHT" "$WT_WIDTH" 1800 3>&1 1>&2 2>&3)
        COOKIE_LIFETIME=${COOKIE_LIFETIME//[!0-9]/}
        if [ "$COOKIE_LIFETIME" -lt "1800" ]
        then
            msg_box "It seems like you have chosen a value below half an hour, which is not recommended. So please try again."
        elif [[ "no" == $(ask_yes_or_no "Is this correct? $COOKIE_LIFETIME seconds")  ]]
        then
            msg_box "It seems like you weren't satisfied with your setting of ($COOKIE_LIFETIME) seconds. So please try again."
        else
            occ_command config:system:set remember_login_cookie_lifetime --value="$COOKIE_LIFETIME"
            break
        fi 
    done
fi
