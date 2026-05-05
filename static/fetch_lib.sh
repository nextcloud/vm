#!/bin/bash
true
# see https://github.com/koalaman/shellcheck/wiki/Directive

IRed='\e[0;91m'         # Red
IGreen='\e[0;92m'       # Green
IYellow='\e[0;93m'      # Yellow
ICyan='\e[0;96m'        # Cyan
Color_Off='\e[0m'       # Text Reset
print_text_in_color() {
    printf "%b%s%b\n" "$1" "$2" "$Color_Off"
}

if [[ "$EUID" -ne 0 ]]
then
    print_text_in_color "$IRed" "You must run fetch_lib with sudo privileges, or directly as root!"
    print_text_in_color "$ICyan" "Please report this to https://github.com/nextcloud/vm/issues if you think it's a bug."
    exit 1
fi

mkdir -p /var/scripts
if ! [ -f /var/scripts/lib.sh ]
then
    if ! curl -sfL https://raw.githubusercontent.com/nextcloud/vm/main/lib.sh -o /var/scripts/lib.sh
    then
        # Try Statically.io CDN
        if curl -sfL https://cdn.statically.io/gh/nextcloud/vm/main/lib.sh -o /var/scripts/lib.sh
        then
            print_text_in_color "$IGreen" "✓ Used Statically.io CDN"
        # Try local backup
        elif [ -f /var/scripts/vm-repo-backup/lib.sh ]
        then
            print_text_in_color "$IYellow" "⚠ GitHub unavailable, using local backup: lib.sh"
            cp /var/scripts/vm-repo-backup/lib.sh /var/scripts/lib.sh
        else
            print_text_in_color "$IRed" "You don't seem to have an internet \
connection and the local lib isn't available. Hence you cannot run this script."
            exit 1
        fi
    fi
elif ! [ -f /var/scripts/nextcloud-startup-script.sh ]
then
    if ! curl -sfL https://raw.githubusercontent.com/nextcloud/vm/main/lib.sh -o /var/scripts/lib.sh
    then
        # Try Statically.io CDN
        if curl -sfL https://cdn.statically.io/gh/nextcloud/vm/main/lib.sh -o /var/scripts/lib.sh
        then
            print_text_in_color "$IGreen" "✓ Used Statically.io CDN"
        # Try local backup
        elif [ -f /var/scripts/vm-repo-backup/lib.sh ]
        then
            print_text_in_color "$IYellow" "⚠ GitHub unavailable, using local backup: lib.sh"
            cp /var/scripts/vm-repo-backup/lib.sh /var/scripts/lib.sh
        fi
    fi
fi

# shellcheck source=lib.sh
source /var/scripts/lib.sh
