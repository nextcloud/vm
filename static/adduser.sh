#!/bin/bash
# shellcheck disable=2034,2059
true
# shellcheck source=lib.sh
. <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/rewrite/lib.sh)

# Tech and Me © - 2017, https://www.techandme.se/

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

if [[ "no" == $(ask_yes_or_no "Do you want to create a new user?") ]]
then
    echo "Not adding another user..."
    sleep 1
else
    read -r -p "Enter name of the new user: " NEWUSER
    useradd -m "$NEWUSER" -G sudo
    while true
    do
        sudo passwd "$NEWUSER" && break
    done
    sudo -u "$NEWUSER" sudo bash nextcloud_install_production.sh
fi
