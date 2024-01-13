#!/bin/bash

# T&M Hansson IT AB © - 2024, https://www.hanssonit.se/
# Copyright © 2021 Simon Lindner (https://github.com/szaimen)

true
SCRIPT_NAME="Whiteboard for Nextcloud"
SCRIPT_EXPLAINER="$SCRIPT_NAME makes it possible to collaborative work on a whiteboard.
It integrates Spacedeck whiteboard server and lets Nextcloud users create .whiteboard files which \
can then be opened in the Files app and in Talk. Those files can be shared to other users or via \
public links. Everyone having access with write permissions to such a file can edit it collaboratively."
# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Check if root
root_check

# NC 21 is required
lowest_compatible_nc 21

# Check if whiteboard is already installed
if ! is_app_installed integration_whiteboard
then
    # Ask for installing
    install_popup "$SCRIPT_NAME"
else
    # Ask for removal or reinstallation
    reinstall_remove_menu "$SCRIPT_NAME"
    # Removal
    nextcloud_occ app:remove integration_whiteboard
    for packet in graphicsmagick ghostscript
    do
        if is_this_installed "$packet"
        then
            apt-get purge "$packet" -y
        fi
    done
    if is_this_installed ffmpeg && ! nextcloud_occ config:system:get enabledPreviewProviders | grep -q "Movie"
    then
        apt-get purge ffmpeg -y
    fi
    apt-get autoremove -y
    # Show successful uninstall if applicable
    removal_popup "$SCRIPT_NAME"
fi

# Install packages for whiteboard
install_if_not graphicsmagick
install_if_not ffmpeg
install_if_not ghostscript

# Install whiteboard
install_and_enable_app integration_whiteboard

if is_app_enabled integration_whiteboard
then
    msg_box "$SCRIPT_NAME was successfully installed!"
else
    msg_box "The installation wasn't successful. Please try again by running this script again!"
fi
