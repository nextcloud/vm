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

# Add crontab for this external storage
sudo -u www-data php -f "$NCPATH"/occ files_external:notify -v "$MOUNT_ID" >> "$VMLOGS"/files_inotify.log
