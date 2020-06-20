#!/bin/bash

# T&M Hansson IT AB © - 2020, https://www.hanssonit.se/

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
        if [ "$(df -h $NCDATA | awk '{print $5}' | tail -1 | cut -d "%" -f1)" -gt 70 ]
        then
            # Notify user
            notify_admin_gui \
            "Disk space almost full!" \
            "The disk space for ncdata is almost full. We have automatically deleted ZFS snapshots older than 4 weeks and cleaned up your trashbin to free up some space and avoid a fatal crash. Please check $VMLOGS/zfs_prune.log for the results."
            # On screen information
msg_box "Your disk space is almost full (more than 70%).

To solve that, we will now delete ZFS snapshots older than 4 weeks

The script will also delete everything in trashbin for all users to free up some space."
            countdown "To abort, please press CTRL+C within 10 seconds." 10
            print_text_in_color "$IGreen" "Freeing some space... This might take a while, please don't abort."
            # Get the latest prune script
            if [ -f $SCRIPTS/zfs-prune-snapshots ]
            then
                rm -f "$SCRIPTS"/zfs-prune-snapshots
                download_script STATIC zfs-prune-snapshots
            elif [ ! -f $SCRIPTS/zfs-prune-snapshots.sh ]
            then
                download_script STATIC zfs-prune-snapshots
            fi
            check_command chmod +x "$SCRIPTS"/zfs-prune-snapshots.sh
            # Prune!
            cd "$SCRIPTS"
            if [ ! -d "$VMLOGS" ]
            then
                mkdir -p "$VMLOGS"
            fi
            touch $VMLOGS/zfs_prune.log
            ./zfs-prune-snapshots.sh 4w ncdata >> $VMLOGS/zfs_prune.log
            occ_command trashbin:cleanup --all-users >> $VMLOGS/zfs_prune.log
        fi
    fi
fi
