#!/bin/bash

# T&M Hansson IT AB © - 2020, https://www.hanssonit.se/

# shellcheck disable=2034,2059
true
# shellcheck source=lib.sh
. <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Must be root
root_check

# Check if Bitwarden is already installed
print_text_in_color "$ICyan" "Checking if Bitwarden is already installed..."
if is_docker_running
then
    if docker ps -a --format '{{.Names}}' | grep -Eq "bitwarden";
    then
        if [ ! -d /root/bwdata ] [ ! -d "$BITWARDEN_HOME"/bwdata ]
        then
            msg_box "It seems like 'Bitwarden' isn't installed.\n\nYou cannot run this script."
            exit 1
        fi
    else
        msg_box "It seems like 'Bitwarden' isn't installed.\n\nYou cannot run this script."
        exit 1
    fi
else
    msg_box "It seems like 'Bitwarden' isn't installed.\n\nYou cannot run this script."
    exit 1
fi

msg_box "This script lets you configure your mailserver settings for Bitwarden."
if [[ "no" == $(ask_yes_or_no "Do you want to continue?") ]]
then
    exit
fi

# Enter Mailserver

# Enter Port

# Enter if you want to use ssl

# Enter your mail username

# Enter your mailuser password

# Present what we gathered, if everything okay, write to files

# Stop bitwarden
# Write to files
# Start bitwarden; is this really enough, does it need to get rebuilt?
