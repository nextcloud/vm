#!/bin/bash
# shellcheck disable=2034,2059
true
# see https://github.com/koalaman/shellcheck/wiki/Directive

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
        print_text_in_color "$IRed" "You don't seem to have an internet connection and the local lib isn't available. Hence you cannot run this script."
        exit 1
    fi
elif test "$(find /var/scripts/lib.sh -mmin +30)"
    print_text_in_color "$ICyan" "Updating lib..."
    curl -sfL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh -o /var/scripts/lib.sh
fi

# shellcheck source=lib.sh
source /var/scripts/lib.sh &>/dev/null
