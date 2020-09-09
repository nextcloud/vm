#!/bin/bash
# shellcheck disable=2034,2059
true
# see https://github.com/koalaman/shellcheck/wiki/Directive

# Functions
msg_box() {
    [ -n "$2" ] && local SUBTITLE=" - $2"
    whiptail --title "$TITLE$SUBTITLE" --msgbox "$1" "$WT_HEIGHT" "$WT_WIDTH"
}


IRed='\e[0;91m'         # Red
IGreen='\e[0;92m'       # Green
ICyan='\e[0;96m'        # Cyan
Color_Off='\e[0m'       # Text Reset
print_text_in_color() {
        printf "%b%s%b\n" "$1" "$2" "$Color_Off"
}

mkdir -p /var/scripts
if ! [ -f /var/scripts/lib.sh ]
then
    if ! curl -sfL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh -o /var/scripts/lib.sh
    then
        msg_box "You don't seem to have an internet connection and the local lib isn't available. Hence you cannot run this script."
        exit 1
    fi
else
    print_text_in_color "$ICyan" "Updating lib..."
    curl -sfL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh -o /var/scripts/lib.sh
fi

# shellcheck source=lib.sh
source /var/scripts/lib.sh &>/dev/null
