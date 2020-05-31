#!/bin/bash

# T&M Hansson IT AB © - 2020, https://www.hanssonit.se/

# shellcheck disable=2034,2059
true
# shellcheck source=lib.sh
[ -f /var/scripts/main/lib.sh ] && source /var/scripts/main/lib.sh || . <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)

# Must be root
root_check

# Use another method if the new one doesn't work
if [ -z "$REPO" ]
then
    REPO=$(apt update -q4 && apt-cache policy | grep http | tail -1 | awk '{print $2}')
fi

# Check where the best mirrors are and update
msg_box "To make downloads as fast as possible when updating Ubuntu you should have download mirrors that are as close to you as possible.

Please note that there are no gurantees that the download mirrors this script will find are staying up for the lifetime of this server.

This is the method used: https://github.com/jblakeman/apt-select"
print_text_in_color "$ICyan" "Checking current mirror..."
print_text_in_color "$ICyan" "Your current server repository is: $REPO"

if [[ "no" == $(ask_yes_or_no "Do you want to try to find a better mirror?") ]]
then
    print_text_in_color "$ICyan" "Keeping $REPO as mirror..."
    sleep 1
else
    if [[ "$KEYBOARD_LAYOUT" =~ ,|/|_ ]]
    then
        msg_box "Your keymap contains more than one language, or a special character. ($KEYBOARD_LAYOUT)\nThis script can only handle one keymap at the time.\nThe default mirror ($REPO) will be kept."
        exit 1
    fi

    # Check if local script is available
    if [ -f "$SCRIPTS"/static/locate_mirror.sh ]
    then
        msg_box "It seems like you have chosen the option 'Security' during the startup script and are using all files locally.\nPlease note that continuing will download files from pypa.io for locating the best server, that will not be checked for integrity."
        if [[ "no" == $(ask_yes_or_no "Do you want to find the best server anyway?") ]]
        then
            exit
        fi
    fi

    print_text_in_color "$ICyan" "Locating the best mirrors..."
    curl_to_dir https://bootstrap.pypa.io get-pip.py /tmp
    install_if_not python3
    install_if_not python3-testresources
    install_if_not python3-distutils
    cd /tmp && python3 get-pip.py
    pip install \
        --upgrade pip \
        apt-select
    check_command apt-select -m up-to-date -t 4 -c -C "$KEYBOARD_LAYOUT"
    sudo cp /etc/apt/sources.list /etc/apt/sources.list.backup && \
    if [ -f sources.list ]
    then
        sudo mv sources.list /etc/apt/
    fi
fi
clear
