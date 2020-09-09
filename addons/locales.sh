#!/bin/bash

# T&M Hansson IT AB © - 2020, https://www.hanssonit.se/

# shellcheck disable=2034,2059
true
SCRIPT_NAME="Locales"
# shellcheck source=fetch_lib.sh
source /var/scripts/fetch_lib.sh &>/dev/null || source <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh) &>/dev/null

### TODO Remove this after some releases
# Download fetch_lib.sh to be able to use it
if ! [ -f "$SCRIPTS"/fetch_lib.sh ]
then
    download_script STATIC fetch_lib
fi

# Must be root
root_check

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

# TODO: "localectl list-x11-keymap-layouts" and pair with "cat /etc/locale.gen | grep UTF-8"
