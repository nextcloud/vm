#!/bin/bash

# T&M Hansson IT AB © - 2020, https://www.hanssonit.se/
# Copyright © 2020 Simon Lindner (https://github.com/szaimen)

true
SCRIPT_NAME="PLEX Media Server"
SCRIPT_EXPLAINER="PLEX Media Server is a server application that let's \
you enjoy all your photos, music, videos, and movies in one place."
# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh || source <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Check if root
root_check

# Check if already installed
if ! is_this_installed plexmediaserver
then
    # Ask for installing
    install_popup "$SCRIPT_NAME"
else
    msg_box "It seems like PLEX Media Server is already installed.

If you want to delete PLEX Media Server and it's data to be able \
to start from scratch, run the following two commands:
'sudo apt purge plexmediaserver'
'sudo deluser plex'

Attention! This will delete the user-data:
'sudo rm -r /var/lib/plexmediaserver'"
    exit 1
fi

# Show warning
msg_box "Please note that we will add a 3rd-party repository to your server \
to be able to install and update PLEX Media Server using the apt packet manager.
This can set your server under risk, though!"
if ! yesno_box_yes "Do you want to continue nonetheless?"
then
    exit 1
fi

# Install PLEX
if curl -fsSL https://downloads.plex.tv/plex-keys/PLEXSign.key | sudo apt-key add -
then
    echo "deb https://downloads.plex.tv/repo/deb/ public main" > /etc/apt/sources.list.d/plexmediaserver.list
    apt update -q4 & spinner_loading
    check_command apt install plexmediaserver -y -o Dpkg::Options::="--force-confold"
fi

# Put the new plex user into the www-data group
check_command usermod --append --groups www-data plex

# Inform the user
msg_box "PLEX Media Server was successfully installed.
This script is not at the end yet so please continue."

# Ask if external acces shall get activated
if yesno_box_yes "Do you want to enable access for PLEX from outside of your LAN?"
then
    msg_box "You will have to open port 32400 TCP to make this work.
You will have the option to automatically open this port by using UPNP in the next step."
    if yesno_box_no "Do you want to use UPNP to open port 32400 TCP?"
    then
        unset FAIL
        open_port 32400 TCP
        cleanup_open_port
    fi
    msg_box "After you hit okay, we will check if port 32400 TCP is open."
    check_open_port 32400 "$WANIP4"
fi

msg_box "You should visit 'http://$ADDRESS:32400/web' to setup your PLEX Media Server next.
Advice: All your media should be mounted in a subfolder of '/mnt' or '/media'"

exit
