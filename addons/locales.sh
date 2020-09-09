#!/bin/bash

# T&M Hansson IT AB © - 2020, https://www.hanssonit.se/

SCRIPT_NAME="Locales"

### TODO Remove this after some releases
# Curl fetch_lib.sh to be able to use it
if ! [ -f /var/scripts/fetch_lib.sh ]
then
    curl -so /var/scripts/fetch_lib.sh https://raw.githubusercontent.com/nextcloud/vm/master/static/fetch_lib.sh
fi

###########################################################################
# shellcheck disable=2034,2059
true
# shellcheck source=fetch_lib.sh
if ! source /var/scripts/fetch_lib.sh >/dev/null 2>&1
then
# shellcheck source=lib.sh
. <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)
fi
###########################################################################

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
