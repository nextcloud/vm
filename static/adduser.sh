#!/bin/bash

. <(curl -sL https://cdn.rawgit.com/morph027/vm/color-vars/lib.sh)

# This runs the startup script with a new user that has sudo permissions 

if [[ "no" == $(ask_yes_or_no "Do you want to create a new user?") ]]
then
echo "Not adding another user..."
sleep 1
else
echo "Enter name of the new user:"
read NEWUSER
useradd -m "$NEWUSER" -G sudo
while true
do
    sudo passwd "$NEWUSER" && break
done
sudo -u "$NEWUSER" sudo bash nextcloud_install_production.sh
fi
