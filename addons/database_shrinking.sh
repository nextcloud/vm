#!/bin/bash

# T&M Hansson IT AB © - 2021, https://www.hanssonit.se/
# Copyright © 2021 Simon Lindner (https://github.com/szaimen)

true
SCRIPT_NAME="Database Shrinking"
# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh || source <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)
SCRIPT_EXPLAINER="This script allows to shrink your database if it has grown too much due to the usage of external storage.
If you don't use external storage, you should NOT run this script!"

# Variables
DAILY_BACKUP_FILE="$SCRIPTS/daily-borg-backup.sh"

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Check if root
root_check

# Show install popup
install_popup "$SCRIPT_NAME"

# Backup
msg_box "It is recommended to make a backup and/or snapshot of your NcVM before shrinking the database."
if ! yesno_box_no "Have you made a backup of your NcVM? If yes, we will start with the database shrinking now."
then
    if ! [ -f "$DAILY_BACKUP_FILE" ]
    then
        exit 1
    fi
    if ! yesno_box_yes "Do you want to run the backup now?"
    then
        exit 1
    fi
    export SKIP_DAILY_BACKUP_CHECK=1
    bash "$DAILY_BACKUP_FILE"
    if ! yesno_box_no "Was the backup successfully? If yes, we will start with the database shrinking now."
    then
        exit 1
    fi
fi

# Remove the app to make sure
nextcloud_occ_no_check app:remove root_cache_cleaner

# Install the app
print_text_in_color "$ICyan" "Installing the needed app..."
nextcloud_occ_no_check app:install root_cache_cleaner
if ! is_app_enabled root_cache_cleaner
then
    msg_box "Could not install the needed app. Cannot proceed!"
    # Make sure to remove the app again
    nextcloud_occ_no_check app:remove root_cache_cleaner
    exit 1
fi

# Do it
print_text_in_color "$ICyan" "Starting the database shrinking. This can take a while..."
yes | nextcloud_occ_no_check root_cache_cleaner:clean

# Make sure to remove the app again
nextcloud_occ_no_check app:remove root_cache_cleaner

# Inform the user
msg_box "Database shrinking done. Please restore from backup if you should experience any issue."
