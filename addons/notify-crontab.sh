#!/bin/bash

true
SCRIPT_NAME="Notify Crontab Script"
# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Must be root
root_check

MOUNT_ID="$1"

if nextcloud_occ files_external:list | grep "$MOUNT_ID"
then
    # Start the iNotify for this external storage
    countdown "iNotify starts in 120 seconds" "120" >> "$VMLOGS"/files_inotify.log
    nextcloud_occ files_external:notify -v "$MOUNT_ID" >> "$VMLOGS"/files_inotify.log
else
    notify_admin_gui \
"Files iNotify Failed!" \
"There seems to be an issue with iNofity. Please check the Mount ID (nextcloud_occ files_external:list) and change the crontab accordingly."
fi
