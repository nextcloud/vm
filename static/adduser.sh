#!/bin/bash
# shellcheck disable=2034,2059
true
# shellcheck source=lib.sh
. <(curl -sL https://cdn.rawgit.com/morph027/vm/master/lib.sh)

# This runs the startup script with a new user that has sudo permissions 

if [[ "no" == $(ask_yes_or_no "Do you want to create a new user?") ]]
then
echo "Not adding another user..."
sleep 1
else
echo "Enter name of the new user:"
read -r NEWUSER
useradd -m "$NEWUSER" -G sudo
while true
do
    sudo passwd "$NEWUSER" && break
done
sudo -u "$NEWUSER" sudo bash nextcloud_install_production.sh
fi
