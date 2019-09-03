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

if [ -d $NCDATA ]
then
    if is_this_installed zfs-auto-snapshot
    then
        if [ "$(df -h $NCDATA | awk '{print $5}' | tail -1 | cut -d "%" -f1)" -gt 90 ]
        then
            # Notify user
            # notify_user_gui "Disk space almost full!" "The disk space for ncdata is almost full. We have automatically deleted ZFS snapshots older than 8 weeks to free up some space. Please check $VMLOGS/zfs_prune.log for the results."
            # On screen information
            msg_box "Your disk space is almost full (more than 90%).\n\nTo solve that, we will now delete ZFS snapshots older than 8 weeks to free up some space."
            countdown "To abort, please press CTRL+C within 10 seconds." 10
            # Get the latest prune script
            if [ ! -f $SCRIPTS/zfs-prune-snapshots ]
            then
                check_command curl_to_dir "https://raw.githubusercontent.com/bahamas10/zfs-prune-snapshots/master/" "zfs-prune-snapshots" "$SCRIPTS"
            fi
            check_command chmod +x "$SCRIPTS"/zfs-prune-snapshots
            # Prune!
            cd "$SCRIPTS"
            touch $VMLOGS/zfs_prune.log
            ./zfs-prune-snapshots 8w ncdata >> $VMLOGS/zfs_prune.log
        fi
    fi
fi
