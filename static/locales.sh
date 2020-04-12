#!/bin/bash

# T&M Hansson IT AB © - 2020, https://www.hanssonit.se/

# Use local lib file in case there is no internet connection
if [ -f /var/scripts/lib.sh ]
then
# shellcheck disable=2034,2059
true
# shellcheck source=lib.sh
source /var/scripts/lib.sh
 # If we have internet, then use the latest variables from the lib remote file
elif print_text_in_color "$ICyan" "Testing internet connection..." && ping github.com -c 2
then
true
# shellcheck source=lib.sh
. <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/20.04_testing/lib.sh)
else
    print_text_in_color "$IRed" "You don't seem to have a working internet connection, and /var/scripts/lib.sh is missing so you can't run this script."
    print_text_in_color "$ICyan" "Please report this to https://github.com/nextcloud/vm/issues/"
    exit 1
fi

# Set locales
print_text_in_color "$ICyan" "Setting locales..."
KEYBOARD_LAYOUT=$(localectl status | grep "Layout" | awk '{print $3}')
if [ "$KEYBOARD_LAYOUT" = "us" ]
then
    print_text_in_color "$ICyan" "US locales are set."
elif [ "$KEYBOARD_LAYOUT" = "se" ]
then 
    sudo locale-gen "sv_SE.UTF-8" && sudo dpkg-reconfigure --frontend=noninteractive locales
elif [ "$KEYBOARD_LAYOUT" = "de" ]
then 
    sudo locale-gen "de_DE.UTF-8" && sudo dpkg-reconfigure --frontend=noninteractive locales
elif [ "$KEYBOARD_LAYOUT" = "us" ]
then
    sudo locale-gen "en_US.UTF-8" && sudo dpkg-reconfigure --frontend=noninteractive locales
elif [ "$KEYBOARD_LAYOUT" = "fr" ]
then
    sudo locale-gen "fr_FR.UTF-8" && sudo dpkg-reconfigure --frontend=noninteractive locales
elif [ "$KEYBOARD_LAYOUT" = "ch" ]
then
    sudo locale-gen "de_CH.UTF-8" && sudo dpkg-reconfigure --frontend=noninteractive locales
fi
