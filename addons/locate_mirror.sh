#!/bin/bash

# T&M Hansson IT AB © - 2023, https://www.hanssonit.se/

true
SCRIPT_NAME="Locate Mirror"
# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh

# Must be root
root_check

# Use another method if the new one doesn't work
if [ -z "$REPO" ]
then
    REPO=$(apt-get update -q4 && apt-cache policy | grep http | tail -1 | awk '{print $2}')
fi

# Check where the best mirrors are and update
msg_box "To make downloads as fast as possible when updating Ubuntu \
you should download mirrors that are as geographically close to you as possible.

Please note that there are no guarantees that the download mirrors \
this script finds will remain for the lifetime of this server.
Because of this, we don't recommend that you change the mirror unless you live far away from the default.

This is the method used: https://github.com/jblakeman/apt-select"
msg_box "Your current server repository is: $REPO"

if ! yesno_box_no "Do you want to try to find a better mirror?"
then
    print_text_in_color "$ICyan" "Keeping $REPO as mirror..."
    sleep 1
else
    if [[ "$KEYBOARD_LAYOUT" =~ ,|/|_ ]]
    then
        msg_box "Your keymap contains more than one language, or a special character. ($KEYBOARD_LAYOUT)
This script can only handle one keymap at the time.\nThe default mirror ($REPO) will be kept."
        exit 1
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
    msg_box "The apt-mirror was successfully changed."
fi
