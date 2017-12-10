#!/bin/bash
# shellcheck disable=2034,2059
true
# shellcheck source=lib.sh
. <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/postgresql/lib.sh)

# Tech and Me © - 2017, https://www.techandme.se/

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

if [[ $UNIXUSER != "ncadmin" ]]
then
    echo
    echo "Current user with sudo permissions is: $UNIXUSER".
    echo "This script will set up everything with that user."
    echo "If the field after ':' is blank you are probably running as a pure root user."
    echo "It's possible to install with root, but there will be minor errors."
    echo
    echo "Please create a user with sudo permissions if you want an optimal installation."
    echo "The preferred user is 'ncadmin'."
    if [[ "no" == $(ask_yes_or_no "Do you want to create a new user?") ]]
    then
        echo "Not adding another user..."
        sleep 1
    else
        read -r -p "Enter name of the new user: " NEWUSER
        adduser --disabled-password --gecos "" "$NEWUSER"
        sudo usermod -aG sudo "$NEWUSER"
        usermod -s /bin/bash "$NEWUSER"
        while true
        do
            sudo passwd "$NEWUSER" && break
        done
        sudo -u "$NEWUSER" sudo bash "$1"
    fi
fi
