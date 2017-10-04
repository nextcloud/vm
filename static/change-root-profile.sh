#!/bin/bash

# Tech and Me © - 2017, https://www.techandme.se/

# shellcheck disable=2034,2059
true
# shellcheck source=lib.sh
. <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

[ -f /root/.profile ] && rm -f /root/.profile

cat <<ROOT-PROFILE > "$ROOT_PROFILE"

# ~/.profile: executed by Bourne-compatible login shells.

if [ "$BASH" ]
then
    if [ -f ~/.bashrc ]
    then
        . ~/.bashrc
    fi
fi

if [[ "$(whoami)" == "root" ]]
then
    echo
    echo "You seem to be running this as root"
    echo "You must run this as a regular user with sudo permissions"
    echo "Please log out and login again as a regular user with sudo and run this command:"
    echo "sudo -u [user] sudo bash /var/scripts/nextcloud-startup-script.sh"
    echo "Please press CTRL+C within 60 seconds"
    sleep 10
fi

if [ -x /var/scripts/nextcloud-startup-script.sh ]
then
    /var/scripts/nextcloud-startup-script.sh
fi

if [ -x /var/scripts/history.sh ]
then
    /var/scripts/history.sh
fi

mesg n

ROOT-PROFILE
