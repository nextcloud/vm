#!/bin/bash

# T&M Hansson IT AB © - 2024, https://www.hanssonit.se/

true
SCRIPT_NAME="Prune ZFS Snapshots"
# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Must be root
root_check

if [ -d "$NCDATA" ]
then
    if is_this_installed zfs-auto-snapshot
    then
        # Check if /mnt/ncdata is more than 70% full
        if [ "$(df -h "$NCDATA" | awk '{print $5}' | tail -1 | cut -d "%" -f1)" -gt 70 ]
        then
            # If it is, then check if there's more than 100 GB left. Large disks may have plenty of space left,
            # and still being set for cleaning if this is not checked
            if [ "$(df /mnt/ncdata/ | awk '{print $4}' | tail -1)" -lt 104857600 ]
            then
                # Notify user
                notify_admin_gui \
                "Disk space almost full!" \
                "The disk space for ncdata is almost full. We have automatically deleted \
ZFS snapshots older than 2 days and cleaned up your trashbin to free up some space \
and avoid a fatal crash. Please check $VMLOGS/zfs_prune.log for the results."
                # On screen information
                msg_box "Your disk space is almost full (more than 70% or less than 100GB left).

To solve that, we will now delete ZFS snapshots older than 2 days.

The script will also delete everything in trashbin for all users to free up some space."
                countdown "To abort, please press CTRL+C within 10 seconds." 10
                print_text_in_color "$IGreen" "Freeing some space... This might take a while, please don't abort."
                # Get the latest prune script
                if [ -f $SCRIPTS/zfs-prune-snapshots ]
                then
                    rm -f "$SCRIPTS"/zfs-prune-snapshots
                    download_script DISK zfs-prune-snapshots
                elif [ ! -f $SCRIPTS/zfs-prune-snapshots.sh ]
                then
                    download_script DISK zfs-prune-snapshots
                fi
                check_command chmod +x "$SCRIPTS"/zfs-prune-snapshots.sh
                # Prune!
                cd "$SCRIPTS"
                if [ ! -d "$VMLOGS" ]
                then
                    mkdir -p "$VMLOGS"
                fi
                # Prune snapshots
                touch $VMLOGS/zfs_prune.log
                ./zfs-prune-snapshots.sh 2d ncdata | tee -a $VMLOGS/zfs_prune.log
                # Create daily prune to avoid disk being full again
                if [ ! -f "$SCRIPTS/daily-zfs-prune.sh" ]
                then
                    run_script DISK create-daily-zfs-prune
                fi
                # Empty trashbin
                nextcloud_occ trashbin:cleanup --all-users >> $VMLOGS/zfs_prune.log
            fi
        fi
    fi
fi
