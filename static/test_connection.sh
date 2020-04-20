#!/bin/bash
# shellcheck disable=2034,2059
true
# shellcheck source=lib.sh
. <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)

# T&M Hansson IT AB © - 2020, https://www.hanssonit.se/

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

curl_to_dir() {
    check_command curl -sSL "$1"/"$2" -o "$3"/"$2"
}

# Colors
Color_Off='\e[0m'
IRed='\e[0;91m'
IGreen='\e[0;92m'
ICyan='\e[0;96m'

print_text_in_color() {
        printf "%b%s%b\n" "$1" "$2" "$Color_Off"
}

curl_to_dir google.com google.connectiontest /tmp
if [ ! -s /tmp/google.connectiontest ]
then
    print_text_in_color "$IRed" "Not connected!"
else
    print_text_in_color "$IGreen" "Connected!"
fi
