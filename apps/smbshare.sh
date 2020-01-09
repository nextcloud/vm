#!/bin/bash

# T&M Hansson IT AB © - 2019, https://www.hanssonit.se/

# shellcheck disable=2034,2059
true
# shellcheck source=lib.sh
. <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)

print_text_in_color "$ICyan" "Configuring Cookie Lifetime timeout..."

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Check if root
root_check


msg_box "This script let you manage SMBShares to access files from the host-computer or other machines in the local network."

COOKIE_LIFETIME=$(whiptail --radiolist  "Choose what you want to do.\n\nSelect one with the [ARROW] keys and select with the [SPACE] key. Confirm by pressing [ENTER]" "$WT_HEIGHT" "$WT_WIDTH" 4 \
"1800s" "30 minutes" ON \
"7200s" "2 hours" OFF \
"43200s" "12 hours" OFF \
"172800s" "2 days" OFF \
"604800s" "1 week" OFF \
"2419200s" "4 weeks" OFF \
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
