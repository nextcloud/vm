#!/bin/bash

# T&M Hansson IT AB © - 2023, https://www.hanssonit.se/

true
SCRIPT_NAME="Locales"
# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Must be root
root_check

# Install locales (doesn't exist on "minimal")
install_if_not locales

# Set locales
print_text_in_color "$ICyan" "Setting locales..."
if [ "$KEYBOARD_LAYOUT" = "us" ]
then
    print_text_in_color "$ICyan" "US locales are already set."
elif [ "$KEYBOARD_LAYOUT" = "se" ]
then
    sudo locale-gen "sv_SE.UTF-8" && sudo dpkg-reconfigure --frontend=noninteractive locales
elif [ "$KEYBOARD_LAYOUT" = "de" ]
then
    sudo locale-gen "de_DE.UTF-8" && sudo dpkg-reconfigure --frontend=noninteractive locales
elif [ "$KEYBOARD_LAYOUT" = "fr" ]
then
    sudo locale-gen "fr_FR.UTF-8" && sudo dpkg-reconfigure --frontend=noninteractive locales
elif [ "$KEYBOARD_LAYOUT" = "ch" ]
then
    sudo locale-gen "de_CH.UTF-8" && sudo dpkg-reconfigure --frontend=noninteractive locales
fi

# TODO: "localectl list-x11-keymap-layouts" and pair with "cat /etc/locale.gen | grep UTF-8"
