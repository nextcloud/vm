#!/bin/bash

# T&M Hansson IT AB © - 2024, https://www.hanssonit.se/

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

# Encryption may not be enabled
if is_app_enabled encryption || is_app_enabled end_to_end_encryption
then
    msg_box "It seems like you have encryption enabled which is unsupported by the $SCRIPT_NAME app!"
    exit 1
fi

# Compatible with NC26 and above
lowest_compatible_nc 26

# Check if face-recognition is installed and ask to remove it
if is_app_installed facerecognition
then
    msg_box "It seems like Face Recognition is installed. This app doesn't work with both installed at the same time. Please uninstall Face Recognition and try again:

1. Hit OK here.
2. Choose 'Uninstall'
3. Run sudo bash $SCRIPTS/menu.sh --> Additional Apps --> Recognize
4. Install

We will run the uninstaller for you now, then exit."
    wget https://raw.githubusercontent.com/nextcloud/vm/main/old/face-recognition.sh && bash face-recognition.sh && rm -f face-recognition.sh
    exit
fi

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
        nextcloud_occ_no_check recognize:remove-legacy-tags
        nextcloud_occ_no_check recognize:cleanup-tags
        nextcloud_occ_no_check recognize:reset-face-clusters
        nextcloud_occ_no_check recognize:reset-faces
        nextcloud_occ_no_check recognize:reset-tags
    fi
    nextcloud_occ app:remove recognize
    # Show successful uninstall if applicable
    removal_popup "$SCRIPT_NAME"
fi

# Install recognize
# Enough recouces?
ram_check 8
cpu_check 4

install_and_enable_app recognize
nextcloud_occ recognize:download-models

# Check if it was installed
if is_app_enabled recognize
then
    msg_box "$SCRIPT_NAME was successfully installed!"
else
    msg_box "The installation wasn't successful. Please try again by running this script again!"
fi
