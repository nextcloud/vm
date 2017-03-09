#!/bin/bash

# This runs the startup script with a new user that has sudo permissions 

function ask_yes_or_no() {
    read -p "$1 ([y]es or [N]o): "
    case $(echo $REPLY | tr '[A-Z]' '[a-z]') in
        y|yes) echo "yes" ;;
        *)     echo "no" ;;
    esac
}
if [[ "no" == $(ask_yes_or_no "Do you want to create a new user?") ]]
then
echo "Not adding another user..."
sleep 1
else
echo "Enter name of the new user:"
read NEWUSER
echo "Enter password of the new user"
read NEWPASS
echo "User: $NEWUSER"
echo "Pass: $NEWPASS"
echo "Continues in 5 seconds..."
sleep 5
adduser --disabled-password --gecos "" $NEWUSER
echo -e "$NEWUSER:$NEWPASS" | chpasswd
gpasswd -a $NEWUSER sudo
sudo -u $NEWUSER sudo bash nextcloud_install_production.sh
fi
