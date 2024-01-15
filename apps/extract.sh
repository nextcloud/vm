#!/bin/bash

# T&M Hansson IT AB © - 2024, https://www.hanssonit.se/
# Copyright © 2021 Simon Lindner (https://github.com/szaimen)

true
SCRIPT_NAME="Extract for Nextcloud"
SCRIPT_EXPLAINER="$SCRIPT_NAME enables archive extraction inside your Nextcloud."
# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Check if root
root_check

# Check if extract is already installed
if ! is_app_installed extract
then
    # Ask for installing
    install_popup "$SCRIPT_NAME"
else
    # Ask for removal or reinstallation
    reinstall_remove_menu "$SCRIPT_NAME"
    # Removal
    nextcloud_occ app:remove extract
    for packet in unrar p7zip "p7zip-full"
    do
        if is_this_installed "$packet"
        then
            apt-get purge "$packet" -y
        fi
    done
    apt-get autoremove -y
    # Show successful uninstall if applicable
    removal_popup "$SCRIPT_NAME"
fi

# Install packages for extract
install_if_not unrar
install_if_not p7zip
install_if_not p7zip-full

# Install extract
install_and_enable_app extract

# Check if it was installed
if is_app_enabled extract
then
    msg_box "$SCRIPT_NAME was successfully installed!"
else
    msg_box "The installation wasn't successful. Please try again by running this script again!"
fi
