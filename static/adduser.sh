#!/bin/bash
true
SCRIPT_NAME="Add CLI User"
# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh

# T&M Hansson IT AB © - 2024, https://www.hanssonit.se/

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

if [[ $UNIXUSER != "ncadmin" ]]
then
    msg_box "Current user with sudo permissions is: $UNIXUSER.
This script will set up everything with that user.
If the field after ':' is blank you are probably running as a pure root user.
It's possible to install with root, but there will be minor errors.

Please create a user with sudo permissions if you want an optimal installation.
The preferred user is 'ncadmin'."
    if ! yesno_box_yes "Do you want to create a new user?"
    then
        print_text_in_color "$ICyan" "Not adding another user..."
        sleep 1
    else
        read -r -p "Enter name of the new user: " NEWUSER
        adduser --disabled-password --gecos "" "$NEWUSER"
        sudo usermod -aG sudo "$NEWUSER"
        usermod -s /bin/bash "$NEWUSER"
        while :
        do
            sudo passwd "$NEWUSER" && break
        done
        sudo -u "$NEWUSER" sudo bash "$1"
    fi
fi
