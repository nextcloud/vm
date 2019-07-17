#!/bin/bash

# T&M Hansson IT AB © - 2019, https://www.hanssonit.se/

# shellcheck disable=2034,2059
true
# shellcheck source=lib.sh
. <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Must be root
root_check

if [ -d /dev/mapper/ ]
then
    if [ $(df -h /dev/mapper/*--vg-root | awk '{print $5}' | tail -1 | cut -d "%" -f1) -gt 90 ]
    then
        notify_user_gui "Disk space almost full!" "The disk space for /dev/mapper/*--vg-root is almost full. We have delete snaphots older than 1 week to free up space"
        check_command curl_to_dir "https://raw.githubusercontent.com/bahamas10/zfs-prune-snapshots/master/" "zfs-prune-snapshots" "$SCRIPTS"
        chmod +x "$SCRIPTS"/zfs-prune-snapshots

        print_text_in_color "$ICyan" "Delete snapshots older than X weeks:"
        read -r weeks
        cd "$SCRIPTS"
        ./zfs-prune-snapshots "$weeks"w ncdata
    fi
fi
