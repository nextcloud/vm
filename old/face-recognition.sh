#!/bin/bash

# T&M Hansson IT AB © - 2024, https://www.hanssonit.se/
# Copyright © 2021 Simon Lindner (https://github.com/szaimen)

true
SCRIPT_NAME="Face Recognition"
SCRIPT_EXPLAINER="The $SCRIPT_NAME app allows to automatically scan for faces inside your Nextcloud."
# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Check if root
root_check

# Check compatibility
check_distro_version
check_php
if [[ "$PHPVER" != "8.1" ]] && [[ "$PHPVER" != "7.4" ]]
then
    msg_box "Currently only PHP 7.4 and PHP 8.1 is supported by this script."
    exit 1
fi

# Encryption may not be enabled
if is_app_enabled encryption || is_app_enabled end_to_end_encryption
then
    msg_box "It seems like you have encryption enabled which is unsupported by the $SCRIPT_NAME app!"
    exit 1
fi

# Compatible with NC21 and above
lowest_compatible_nc 21

# Hardware requirements
# https://github.com/matiasdelellis/facerecognition/wiki/Requirements-and-Limitations#hardware-requirements
# https://github.com/matiasdelellis/facerecognition/wiki/Models#model-3
ram_check 2
cpu_check 2

# Check if facerecognition is already installed
if ! is_app_installed facerecognition && ! is_this_installed php7.4-pdlib && ! is_this_installed php8.1-pdli
then
    # Ask for installing
    install_popup "$SCRIPT_NAME"
else
    # Ask for removal or reinstallation
    reinstall_remove_menu "$SCRIPT_NAME"
    # Removal
    if is_this_installed php7.4-pdlib
    then
        apt-get purge php7.4-pdlib -y
        rm -f /etc/apt/sources.list.d/20-pdlib.list
        apt-get update -q4 & spinner_loading
        apt-get autoremove -y
        rm -f /etc/apt/trusted.gpg.d/facerecognition.gpg
    elif is_this_installed php8.1-pdlib
    then
        apt-get purge php8.1-pdlib -y
        rm -f /etc/apt/sources.list.d/facerecognition-pdlib.list
        apt-get update -q4 & spinner_loading
        apt-get autoremove -y
        rm -f /etc/apt/keyrings/repo.gpg.key
    fi
    crontab -u www-data -l | grep -v "face_background_job.log" | crontab -u www-data -
    crontab -u www-data -l | grep -v "face:background_job" | crontab -u www-data -
    if is_app_enabled facerecognition
    then
        if yesno_box_no "Do you want to reset all face data?
The background scanner will then have to rescan all files for faces when you install the app again."
        then
            echo y | nextcloud_occ face:reset --all
        fi
        nextcloud_occ config:app:set facerecognition handle_external_files --value false
        nextcloud_occ config:app:set facerecognition handle_group_files --value false
        nextcloud_occ config:app:set facerecognition handle_shared_files --value false
    fi
    if is_app_installed facerecognition
    then
        nextcloud_occ app:remove facerecognition
    fi
    rm -f "$VMLOGS"/face_background_job.log
    # Show successful uninstall if applicable
    removal_popup "$SCRIPT_NAME"
fi

# Inform about dependencies
msg_box "Please note that the $SCRIPT_NAME app needs an additional PHP dependency \
to work which will need to be installed from an external repository.
This can set your server under risk."
if ! yesno_box_yes "Do you want to install the required dependency?
If you choose 'No', the installation will be aborted."
then
    exit 1
fi

# Install requirements
if version 22.04 "$DISTRO" 22.04.10
then
    # https://github.com/matiasdelellis/facerecognition/wiki/PDlib-Installation#ubuntu-jammy
    add_trusted_key_and_repo "repo.gpg.key" \
    "https://repo.delellis.com.ar" \
    "https://repo.delellis.com.ar" \
    "focal focal" \
    "facerecognition-pdlib.list"
    install_if_not php"$PHPVER"-pdlib
elif version 24.04 "$DISTRO" 24.04.10
then
    # https://github.com/matiasdelellis/facerecognition/wiki/PDlib-Installation#ubuntu-noble
    add_trusted_key_and_repo "repo.gpg.key" \
    "https://repo.delellis.com.ar" \
    "https://repo.delellis.com.ar" \
    "$CODENAME $CODENAME" \
    "facerecognition-pdlib.list"
    install_if_not php"$PHPVER"-pdlib
fi

# Install the app
install_and_enable_app facerecognition
if ! is_app_enabled facerecognition
then
    msg_box "Could not install the $SCRIPT_NAME app. Cannot proceed."
    exit 1
fi

# Set up face model and max memory usage
# https://github.com/matiasdelellis/facerecognition/wiki/Models#comparison
# https://github.com/matiasdelellis/facerecognition/tree/master#initial-setup
nextcloud_occ face:setup --memory 2GB
nextcloud_occ face:setup --model 3

# Set temporary files size
nextcloud_occ config:app:set facerecognition analysis_image_area --value="4320000"

# Additional settings
# https://github.com/matiasdelellis/facerecognition/wiki/Settings#hidden-settings
if yesno_box_no "Do you want the $SCRIPT_NAME app to scan external storages?
This is currently highly inefficient since it will scan all external storges multiple times (once for each user) \
and can produce a lot of network traffic.
(The scan will need to access all files, also if they are stored externally.)
Hence, you should only enable this option if you are only using local external storage \
or if you don't use the external storage app at all."
then
    nextcloud_occ config:app:set facerecognition handle_external_files --value true
fi
if yesno_box_no "Do you want the $SCRIPT_NAME app to scan groupfolders?
This is currently highly inefficient since it will scan all groupfolders multiple times (once for each user)."
then
    nextcloud_occ config:app:set facerecognition handle_group_files --value true
fi
if yesno_box_no "Do you want the $SCRIPT_NAME app to scan shared folders/files?
This is currently highly inefficient since it will scan all shared folders/files multiple times (once for each user)."
then
    nextcloud_occ config:app:set facerecognition handle_shared_files --value true
fi

# Allow the background scanner to scan the files for each user again and enable face scanning for all users
# https://github.com/matiasdelellis/facerecognition/wiki/Settings#notes
NC_USERS_NEW=$(nextcloud_occ_no_check user:list | sed 's|^  - ||g' | sed 's|:.*||')
mapfile -t NC_USERS_NEW <<< "$NC_USERS_NEW"
for user in "${NC_USERS_NEW[@]}"
do
    nextcloud_occ user:setting "$user" facerecognition full_image_scan_done false
    nextcloud_occ user:setting "$user" facerecognition enabled true
done

# Make sure that the logfile doesn't get crazy big.
crontab -u www-data -l | grep -v "face_background_job.log" | crontab -u www-data -
crontab -u www-data -l | { cat; echo "@daily rm -f $VMLOGS/face_background_job.log"; } | crontab -u www-data -

# Schedule background scan
# https://github.com/matiasdelellis/facerecognition/wiki/Schedule-Background-Task#cron
crontab -u www-data -l | grep -v "face:background_job" | crontab -u www-data -
crontab -u www-data -l | { cat; echo "*/30 * * * * php -f $NCPATH/occ \
face:background_job -t 900 --defer-clustering >> $VMLOGS/face_background_job.log"; } | crontab -u www-data -

msg_box "Congratulations, $SCRIPT_NAME was successfully installed!
You just need to wait now and let the background job do its work.
After a while, you should see more and more faces that were found in your Nextcloud."
