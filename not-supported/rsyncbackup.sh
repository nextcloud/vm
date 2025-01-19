#!/bin/bash

# T&M Hansson IT AB © - 2024, https://www.hanssonit.se/
# Copyright © 2021 Simon Lindner (https://github.com/szaimen)

true
SCRIPT_NAME="Rsync Backup"
SCRIPT_EXPLAINER="This script creates the off-shore backup of your server."
# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Check if root
root_check

# Variables
START_TIME=$(date +%s)
CURRENT_DATE=$(date --date @"$START_TIME" +"%Y%m%d_%H%M%S")
CURRENT_DATE_READABLE=$(date --date @"$START_TIME" +"%d.%m.%Y - %H:%M:%S")
LOG_FILE="$VMLOGS/rsyncbackup-$CURRENT_DATE.log"
# This is needed for running via cron
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/snap/bin

# Functions
inform_user() {
    echo -e "\n\n# $2"
    print_text_in_color "$1" "$2"
}
paste_log_file() {
    cat "$LOG_FILE" >> "$RSYNC_BACKUP_LOG"
    echo -e "\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n" >> "$RSYNC_BACKUP_LOG"
}
remove_log_file() {
    rm "$LOG_FILE"
}
show_drive_usage() {
    inform_user "$ICyan" "Showing drive usage..."
    lsblk -o FSUSE%,SIZE,MOUNTPOINT,NAME | grep -v "loop[0-9]" | grep "%" | sed 's|`-||;s/|-//;s/  | //'
    echo ""
    df -h | grep -v "loop[0-9]" | grep -v "tmpfs" | grep -v "^udev" | grep -v "^overlay"
}
send_error_mail() {
    if [ -d "$BACKUP_TARGET_DIRECTORY" ]
    then
        if [ -z "$DO_NOT_UMOUNT_BACKUP_DRIVES" ]
        then
            inform_user "$ICyan" "Unmounting the offshore backup drive..."
            umount "$BACKUP_MOUNTPOINT"
        fi
    fi
    if [ -d "$BACKUP_SOURCE_DIRECTORY" ]
    then
        if [ -z "$DO_NOT_UMOUNT_BACKUP_DRIVES" ]
        then
            inform_user "$ICyan" "Unmounting the daily backup drive..."
            umount "$BACKUP_SOURCE_MOUNTPOINT"
        fi
    fi
    get_expiration_time
    inform_user "$IRed" "Off-shore backup sent error on $END_DATE_READABLE ($DURATION_READABLE)"
    inform_user "$IRed" "Off-shore backup failed! $1"
    if ! send_mail "Off-shore backup failed! $1" "$(cat "$LOG_FILE")"
    then
        notify_admin_gui \
        "Off-shore backup failed! Though mail sending didn't work!" \
        "Please look at the log file $LOG_FILE if you want to find out more."
        paste_log_file
    else
        paste_log_file
        remove_log_file
    fi
    exit 1
}
re_rename_snapshot() {
    inform_user "$ICyan" "Re-renaming the snapshot..."
    if ! lvrename /dev/ubuntu-vg/NcVM-snapshot-pending /dev/ubuntu-vg/NcVM-snapshot
    then
        return 1
    else
        return 0
    fi
}
get_expiration_time() {
    END_TIME=$(date +%s)
    END_DATE_READABLE=$(date --date @"$END_TIME" +"%d.%m.%Y - %H:%M:%S")
    DURATION=$((END_TIME-START_TIME))
    DURATION_SEC=$((DURATION % 60))
    DURATION_MIN=$(((DURATION / 60) % 60))
    DURATION_HOUR=$((DURATION / 3600))
    DURATION_READABLE=$(printf "%02d hours %02d minutes %02d seconds" $DURATION_HOUR $DURATION_MIN $DURATION_SEC)
}

# Write output to logfile.
exec > >(tee -i "$LOG_FILE")
exec 2>&1

# Send mail that backup was started
if ! send_mail "Off-shore backup started!" "You will be notified again when the backup is finished!
Please don't restart or shutdown your server until then!"
then
    notify_admin_gui "Off-shore backup started!" "You will be notified again when the backup is finished!
Please don't restart or shutdown your server until then!"
fi

# Start backup
inform_user "$IGreen" "Off-shore backup started! $CURRENT_DATE_READABLE"

# Check if the file exists
if ! [ -f "$SCRIPTS/off-shore-rsync-backup.sh" ]
then
    send_error_mail "The off-shore-rsync-backup.sh doesn't exist."
fi

# Check if all needed variables are there (they get exported by the local off-shore-rsync-backup.sh)
if [ -z "$BACKUP_TARGET_DIRECTORY" ] || [ -z "$BACKUP_MOUNTPOINT" ] || [ -z "$RSYNC_BACKUP_LOG" ] \
|| [ -z "$BACKUP_SOURCE_MOUNTPOINT" ] || [ -z "$BACKUP_SOURCE_DIRECTORY" ]
then
    send_error_mail "Didn't get all needed variables."
fi

# Check if pending snapshot is existing and cancel the backup in this case.
if does_snapshot_exist "NcVM-snapshot-pending"
then
    DO_NOT_UMOUNT_BACKUP_DRIVES=1
    msg_box "The snapshot pending does exist. Can currently not proceed.
Please try again later.\n
If you are sure that no update or backup is currently running, you can fix this by rebooting your server."
    send_error_mail "NcVM-snapshot-pending exists. Please try again later!"
fi

# Check if snapshot can get created
if ! does_snapshot_exist "NcVM-snapshot"
then
    send_error_mail "NcVM-snapshot doesn't exists."
fi

# Check if at least one daily backup drive has run
BORGBACKUP_LOG="$(grep "^export BORGBACKUP_LOG" "$SCRIPTS/daily-borg-backup.sh" \
| sed 's|.*BORGBACKUP_LOG="||' | sed 's|"$||')"
if [ -z "$BORGBACKUP_LOG" ] || ! [ -f "$BORGBACKUP_LOG" ] || ! grep -q "Backup finished on" "$BORGBACKUP_LOG"
then
    send_error_mail "Not even one daily backup was successfully created. Please wait for that first."
fi

# Prepare backup repository
inform_user "$ICyan" "Mounting the daily backup drive..."
if ! [ -d "$BACKUP_SOURCE_DIRECTORY" ]
then
    mount "$BACKUP_SOURCE_MOUNTPOINT" &>/dev/null
    if ! [ -d "$BACKUP_SOURCE_DIRECTORY" ]
    then
        send_error_mail "Could not mount the daily backup drive. Is it connected?"
    fi
fi

# Prepare backup repository
inform_user "$ICyan" "Mounting the off-shore backup drive..."
if ! [ -d "$BACKUP_TARGET_DIRECTORY" ]
then
    mount "$BACKUP_MOUNTPOINT" &>/dev/null
    if ! [ -d "$BACKUP_TARGET_DIRECTORY" ]
    then
        send_error_mail "Could not mount the off-shore backup drive. Please connect it!"
    fi
fi

# Check daily backup
rm -f /tmp/DAILY_BACKUP_CHECK_SUCCESSFUL
export SKIP_DAILY_BACKUP_CREATION=1
bash "$SCRIPTS/daily-borg-backup.sh"
if ! [ -f "/tmp/DAILY_BACKUP_CHECK_SUCCESSFUL" ]
then
    send_error_mail "Daily backup check failed!" \
    "Backup check was unsuccessful! $(date +%T)"
fi

# Test if btrfs volume
if grep " $BACKUP_MOUNTPOINT " /etc/mtab | grep -q btrfs
then
    IS_BTRFS_PART=1
    mkdir -p "$BACKUP_MOUNTPOINT/.snapshots"
    btrfs subvolume snapshot -r "$BACKUP_MOUNTPOINT" "$BACKUP_MOUNTPOINT/.snapshots/@$CURRENT_DATE"
    while [ "$(find "$BACKUP_MOUNTPOINT/.snapshots/" -maxdepth 1 -mindepth 1 -type d -name '@*_*' | wc -l)" -gt 4 ]
    do
        DELETE_SNAP="$(find "$BACKUP_MOUNTPOINT/.snapshots/" -maxdepth 1 -mindepth 1 -type d -name '@*_*' | sort | head -1)"
        btrfs subvolume delete "$DELETE_SNAP"
    done
fi

# Check if pending snapshot is existing and cancel the backup in this case.
if does_snapshot_exist "NcVM-snapshot-pending"
then
    DO_NOT_UMOUNT_BACKUP_DRIVES=1
    msg_box "The snapshot pending does exist. Can currently not proceed.
Please try again later.\n
If you are sure that no update or backup is currently running, you can fix this by rebooting your server."
    send_error_mail "NcVM-snapshot-pending exists. Please try again later!"
fi

# Rename the snapshot to represent that the backup is pending
inform_user "$ICyan" "Renaming the snapshot..."
if ! lvrename /dev/ubuntu-vg/NcVM-snapshot /dev/ubuntu-vg/NcVM-snapshot-pending
then
    send_error_mail "Could not rename the snapshot to snapshot-pending."
fi

# Create the backup
inform_user "$ICyan" "Creating the off-shore backup..."
if ! rsync --archive --human-readable --delete --stats "$BACKUP_SOURCE_DIRECTORY/" "$BACKUP_TARGET_DIRECTORY"
then
    show_drive_usage
    re_rename_snapshot
    send_error_mail "Something failed during the rsync job."
fi

# Adjust permissions and scrub volume
if [ -n "$IS_BTRFS_PART" ]
then
    inform_user "$ICyan" "Adjusting permissions..."
    find "$BACKUP_MOUNTPOINT/" -not -path "$BACKUP_MOUNTPOINT/.snapshots/*" \
\( ! -perm 600 -o ! -group root -o ! -user root \) -exec chmod 600 {} \; -exec chown root:root {} \;
    inform_user "$ICyan" "Making sure that all data is written out correctly by waiting 10 min..."
    # This fixes an issue where checksums are not yet created before the scrub command runs which then reports checksum errors
    if ! sleep 10m
    then
        re_rename_snapshot
        send_error_mail "Some errors were reported while waiting for the data to get written out."
    fi
    inform_user "$ICyan" "Scrubbing BTRFS partition..."
    if ! btrfs scrub start -B "$BACKUP_MOUNTPOINT"
    then
        re_rename_snapshot
        send_error_mail "Some errors were reported while scrubbing the BTRFS partition."
    fi
fi

# Rename the snapshot back to normal
if ! re_rename_snapshot
then
    send_error_mail "Could not rename the snapshot-pending to snapshot."
fi

# Print usage of drives into log
show_drive_usage

# Unmount the backup drive
inform_user "$ICyan" "Unmounting the off-shore backup drive..."
if mountpoint -q "$BACKUP_MOUNTPOINT" && ! umount "$BACKUP_MOUNTPOINT"
then
    send_error_mail "Could not unmount the off-shore backup drive!"
fi

# Unmount the backup drive
inform_user "$ICyan" "Unmounting the daily backup drive..."
if mountpoint -q "$BACKUP_SOURCE_MOUNTPOINT" && ! umount "$BACKUP_SOURCE_MOUNTPOINT"
then
    send_error_mail "Could not unmount the daily backup drive!"
fi

# Resetting the timer for off-shore backups
inform_user "$ICyan" "Resetting the timer for off-shore backups..."
sed -i 's|^DAYS_SINCE_LAST_BACKUP.*|DAYS_SINCE_LAST_BACKUP=0|' "$SCRIPTS/off-shore-rsync-backup.sh"

# Show expiration time
get_expiration_time
inform_user "$IGreen" "Off-shore backup finished on $END_DATE_READABLE ($DURATION_READABLE)"

# Send mail about successful backup
if ! send_mail "Off-shore backup successful! You can now disconnect the off-shore backup drive!" "$(cat "$LOG_FILE")"
then
    notify_admin_gui \
    "Off-shore backup successful! Though mail sending didn't work!" \
    "You can now disconnect the off-shore backup drive! \
Please look at the log file $LOG_FILE if you want to find out more."
    paste_log_file
else
    paste_log_file
    remove_log_file
fi

exit