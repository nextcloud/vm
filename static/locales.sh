#!/bin/bash

# T&M Hansson IT AB © - 2020, https://www.hanssonit.se/

# shellcheck disable=2034,2059
true
# shellcheck source=lib.sh
. <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/20.04_testing/lib.sh)

# Set locales
print_text_in_color "$ICyan" "Setting locales..."
KEYBOARD_LAYOUT=$(localectl status | grep "Layout" | awk '{print $3}')
if [ "$KEYBOARD_LAYOUT" = "us" ]
then
    print_text_in_color "$ICyan" "US locales are already set."
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
