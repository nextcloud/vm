#!/bin/bash

# T&M Hansson IT AB © - 2024, https://www.hanssonit.se/
# Copyright © 2021 Simon Lindner (https://github.com/szaimen)

true
SCRIPT_NAME="PDF Annotations"
SCRIPT_EXPLAINER="This script allows to easily install PDF Annotations, \
a tool to annotate any PDF document inside Nextcloud."
# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Check if root
root_check

# Check if pdfannotate is already installed
if ! is_app_installed pdfannotate
then
    # Ask for installing
    install_popup "$SCRIPT_NAME"
else
    # Ask for removal or reinstallation
    reinstall_remove_menu "$SCRIPT_NAME"
    # Removal
    pip3 uninstall svglib -y &>/dev/null
    for packet in pdftk ghostscript
    do
        if is_this_installed "$packet"
        then
            apt purge "$packet" -y
        fi
    done
    apt autoremove -y
    nextcloud_occ app:remove pdfannotate
    # Show successful uninstall if applicable
    removal_popup "$SCRIPT_NAME"
fi

# Install all needed dependencies
install_if_not ghostscript
install_if_not pdftk
install_if_not python3-pip
pip3 install svglib

# Get the app
check_command cd "$NC_APPS_PATH"
rm -rf pdfannotate
install_if_not git
check_command git clone https://gitlab.com/nextcloud-other/nextcloud-annotate pdfannotate
chown -R www-data:www-data pdfannotate
chmod -R 770 pdfannotate

# Install the app
install_and_enable_app pdfannotate
if ! is_app_enabled pdfannotate
then
    msg_box "Could not install $SCRIPT_NAME!"
else
    msg_box "$SCRIPT_NAME was successfully installed!"
fi
