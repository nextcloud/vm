#!/bin/bash

# T&M Hansson IT AB © - 2023, https://www.hanssonit.se/

true
SCRIPT_NAME="Recognize for Nextcloud"
SCRIPT_EXPLAINER="$SCRIPT_NAME enables [local] AI detection of photos in your Nextcloud. Recognize improves the Photos app."
# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Check if root
root_check

# Check if recognize is already installed
if ! is_app_installed recognize
then
    # Ask for installing
    install_popup "$SCRIPT_NAME"
else
    # Ask for removal or reinstallation
    reinstall_remove_menu "$SCRIPT_NAME"
    # Removal
    if yesno_box_no "Do you want to remove all facerecognitions and tags that were generated until now?"
    then
        print_text_in_color "$ICyan" "This will take some time..."
        nextcloud_occ recognize:remove-legacy-tags
        nextcloud_occ recognize:cleanup-tags
        nextcloud_occ recognize:reset-face-clusters
        nextcloud_occ recognize:reset-faces
        nextcloud_occ recognize:reset-tags
    fi
    nextcloud_occ app:remove recognize
    # Show successful uninstall if applicable
    removal_popup "$SCRIPT_NAME"
fi

# Install recognize
# Enough recouces?
ram_check 8
cpu_check 4

# Check if suspicios_login are installed
# https://github.com/nextcloud/recognize/issues/676
if is_app_installed suspicios_login
then
    msg_box "Since you have the app Suspicios Login installed, you can't install Recognize since it will cause issues with cron.php."
    if yesno_box_no "Do you want to remove Suspicios Login to be able to install Recognize?"
       then
            nextcloud_occ app:remove suspicios_login
   fi
fi

install_and_enable_app recognize
nextcloud_occ recognize:download-models

# Check if it was installed
if is_app_enabled recognize
then
    msg_box "$SCRIPT_NAME was successfully installed!"
else
    msg_box "The installation wasn't successful. Please try again by running this script again!"
fi
