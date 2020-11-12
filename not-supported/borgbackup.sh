#!/bin/bash

# T&M Hansson IT AB © - 2020, https://www.hanssonit.se/
# Copyright © 2020 Simon Lindner (https://github.com/szaimen)

true
SCRIPT_NAME="Borg Backup"
SCRIPT_EXPLAINER="This script creates the Borg backup of your server."
# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh || source <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Check if root
root_check

# Variables
LVM_MOUNT="/system"
START_TIME=$(date +%s)
CURRENT_DATE=$(date --date @"$START_TIME" +"%Y%m%d_%H%M%S")
CURRENT_DATE_READABLE=$(date --date @"$START_TIME" +"%d.%m.%Y - %H:%M:%S")
LOG_FILE="$VMLOGS/borgbackup-$CURRENT_DATE.log"
# This is needed for running via cron
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/snap/bin

# Functions
inform_user() {
    echo -e "\n\n# $2"
    print_text_in_color "$1" "$2"
}
stop_services() {
    inform_user "$ICyan" "Stopping services..."
    if is_docker_running
    then
        check_command systemctl stop docker
    fi
    nextcloud_occ maintenance:mode --on
    systemctl stop postgresql
}
start_services() {
    inform_user "$ICyan" "Starting services..."
    systemctl start postgresql
    nextcloud_occ maintenance:mode --off
    start_if_stopped docker
}
paste_log_file() {
    cat "$LOG_FILE" >> "$BORGBACKUP_LOG"
    echo -e "\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n" >> "$BORGBACKUP_LOG"
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
        inform_user "$ICyan" "Unmounting the backup drive..."
        umount "$BACKUP_MOUNTPOINT"
    fi
    get_expiration_time
    MAIL_TITLE="$2"
    if [ -z "$2" ]
    then
        MAIL_TITLE="Daily backup"
    fi
    inform_user "$IRed" "$MAIL_TITLE sent error on $END_DATE_READABLE ($DURATION_READABLE)"
    inform_user "$IRed" "$MAIL_TITLE failed! $1"
    if ! send_mail "$MAIL_TITLE failed! $1" "$(cat "$LOG_FILE")"
    then
        notify_admin_gui \
        "$MAIL_TITLE failed! Though mail sending didn't work!" \
        "Please look at the log file $LOG_FILE if you want to find out more."
        paste_log_file
    else
        paste_log_file
        remove_log_file
    fi
    exit 1
}
re_rename_snapshot() {
    if mountpoint -q "$LVM_MOUNT"
    then
        umount "$LVM_MOUNT"
    fi
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

# Secure the backup file
chown root:root "$SCRIPTS/daily-borg-backup.sh"
chmod 700 "$SCRIPTS/daily-borg-backup.sh"

# Write output to logfile.
exec > >(tee -i "$LOG_FILE")
exec 2>&1

# Check if dpkg or apt is running
is_process_running apt
is_process_running dpkg

# Start backup
inform_user "$IGreen" "Daily backup started! $CURRENT_DATE_READABLE"

# Check if the file exists
if ! [ -f "$SCRIPTS/daily-borg-backup.sh" ]
then
    send_error_mail "The daily-borg-backup.sh doesn't exist."
fi

# Check if all needed variables are there (they get exported by the local daily-backup-script.sh)
if [ -z "$ENCRYPTION_KEY" ] || [ -z "$BACKUP_TARGET_DIRECTORY" ] || [ -z "$BORGBACKUP_LOG" ] || [ -z "$BACKUP_MOUNTPOINT" ] \
|| [ -z "$CHECK_BACKUP_INTERVAL_DAYS" ] || [ -z "$DAYS_SINCE_LAST_BACKUP_CHECK" ]
then
    send_error_mail "Didn't get all needed variables."
elif [ -n "$ADDITIONAL_BACKUP_DIRECTORIES" ]
# ADDITIONAL_BACKUP_DIRECTORIES is optional
then
    mapfile -t ADDITIONAL_BACKUP_DIRECTORIES <<< "$ADDITIONAL_BACKUP_DIRECTORIES"
    for directory in "${ADDITIONAL_BACKUP_DIRECTORIES[@]}"
    do
        DIRECTORY="${directory%%/}"
        if ! [ -d "$directory" ]
        then
            send_error_mail "$directory doesn't exist. Drive not connected?"
        else
            if ! test "$(timeout 5 ls -A "$directory")"
            then
                mount "$directory" &>/dev/null
                if ! test "$(timeout 5 ls -A "$directory")"
                then
                    send_error_mail "$directory doesn't exist. Drive not connected?"
                fi
            fi
        fi
    done
fi

# Check if backup shall get checked
if [ "$DAYS_SINCE_LAST_BACKUP_CHECK" -ge "$CHECK_BACKUP_INTERVAL_DAYS" ]
then
    CHECK_BACKUP=1
else
    DAYS_SINCE_LAST_BACKUP_CHECK=$((DAYS_SINCE_LAST_BACKUP_CHECK+1))
    sed -i "s|^export DAYS_SINCE_LAST_BACKUP_CHECK.*|export DAYS_SINCE_LAST_BACKUP_CHECK=$DAYS_SINCE_LAST_BACKUP_CHECK|" "$SCRIPTS/daily-borg-backup.sh"
fi

# Check if pending snapshot is existing and cancel the backup in this case.
if does_snapshot_exist "NcVM-snapshot-pending"
then
    send_error_mail "NcVM-snapshot-pending exists. Please try again later!"
fi

# Check if snapshot can get created
check_free_space
if ! does_snapshot_exist "NcVM-snapshot" && ! [ "$FREE_SPACE" -ge 50 ]
then
    send_error_mail "Not enough free space on your vgs."
fi

# Prepare backup repository
inform_user "$ICyan" "Mounting the backup drive..."
if ! [ -d "$BACKUP_TARGET_DIRECTORY" ]
then
    mount "$BACKUP_MOUNTPOINT" &>/dev/null
    if ! [ -d "$BACKUP_TARGET_DIRECTORY" ]
    then
        send_error_mail "Could not mount the backup drive. Is it connected?"
    fi
fi

# Create LVM snapshot & Co.
inform_user "$ICyan" "Creating LVM snapshot..."
stop_services
if does_snapshot_exist "NcVM-snapshot"
then
    if ! lvremove /dev/ubuntu-vg/NcVM-snapshot -y
    then
        start_services
        send_error_mail "Could not remove old NcVM-snapshot - Please reboot your server!"
    fi
fi
if ! lvcreate --size 5G --snapshot --name "NcVM-snapshot" /dev/ubuntu-vg/ubuntu-lv
then
    start_services
    send_error_mail "Could not create NcVM-snapshot - Please reboot your server!"
else
    inform_user "$IGreen" "Snapshot successfully created!"
fi
start_services

# Rename the snapshot to represent that the backup is pending
inform_user "$ICyan" "Renaming the snapshot..."
if ! lvrename /dev/ubuntu-vg/NcVM-snapshot /dev/ubuntu-vg/NcVM-snapshot-pending
then
    send_error_mail "Could not rename the snapshot to snapshot-pending."
fi

# Mount the snapshot
if mountpoint -q "$LVM_MOUNT"
then
    if ! umount "$LVM_MOUNT"
    then
        re_rename_snapshot
        send_error_mail "Could not unmount '$LVM_MOUNT'!"
    fi
fi
mkdir -p "$LVM_MOUNT"
inform_user "$ICyan" "Mounting the snapshot..."
if ! mount --read-only /dev/ubuntu-vg/NcVM-snapshot-pending "$LVM_MOUNT"
then
    re_rename_snapshot
    send_error_mail "Could not mount the LVM snapshot!"
fi

# Borg backup based on this
# https://borgbackup.readthedocs.io/en/stable/deployment/automated-local.html?highlight=files%20cache#configuring-the-system
# https://iwalton.com/wiki/#[[Backup%20Script]]
# https://decatec.de/linux/backup-strategie-fuer-linux-server-mit-borg-backup/

# Export default values
export BORG_PASSPHRASE="$ENCRYPTION_KEY"
export BORG_UNKNOWN_UNENCRYPTED_REPO_ACCESS_IS_OK=yes
export BORG_RELOCATED_REPO_ACCESS_IS_OK=yes

# Log Borg version
borg --version

# Borg options
# auto,zstd compression seems to has the best ratio based on:
# https://forum.level1techs.com/t/optimal-compression-for-borg-backups/145870/6
BORG_OPTS=(--stats --compression "auto,zstd" --exclude-caches --checkpoint-interval 86400)

# System backup
EXCLUDED_DIRECTORIES=(home/*/.cache root/.cache var/cache lost+found run var/run dev tmp)
# mnt, media, sys, prob don't need to be excluded because of the usage of lvm-snapshots and the --one-file-system flag
for directory in "${EXCLUDED_DIRECTORIES[@]}"
do
    EXCLUDE_DIRS+=(--exclude "$LVM_MOUNT/$directory/")
done

# Create system backup
inform_user "$ICyan" "Creating system partition backup..."
if ! borg create "${BORG_OPTS[@]}" --one-file-system "${EXCLUDE_DIRS[@]}" \
"$BACKUP_TARGET_DIRECTORY::$CURRENT_DATE-NcVM-system-partition" "$LVM_MOUNT/"
then
    inform_user "$ICyan" "Deleting the failed system backup archive..."
    borg delete --stats "$BACKUP_TARGET_DIRECTORY::$CURRENT_DATE-NcVM-system-partition"
    show_drive_usage
    re_rename_snapshot
    send_error_mail "Some errors were reported during the system partition backup!"
fi

# Check Snapshot size
inform_user "$ICyan" "Testing how full the snapshot is..."
SNAPSHOT_USED=$(lvs -o name,data_percent | grep "NcVM-snapshot-pending" | awk '{print $2}' | sed 's|\..*||')
if [ "$SNAPSHOT_USED" -lt 100 ]
then
    inform_user "$IGreen" "Backup ok: Snapshot is not full ($SNAPSHOT_USED%)"
else
    inform_user "$IRed" "Backup corrupt: Snapshot is full ($SNAPSHOT_USED%)"
    inform_user "$ICyan" "Deleting the corrupt system backup archive..."
    borg delete --stats "$BACKUP_TARGET_DIRECTORY::$CURRENT_DATE-NcVM-system-partition"
    show_drive_usage
    re_rename_snapshot
    send_error_mail  "The backup archive was corrupt because the snapshot is full and has been deleted."
fi

# Unmount LVM_snapshot
inform_user "$ICyan" "Unmounting the snapshot..."
if ! umount "$LVM_MOUNT"
then
    send_error_mail "Could not unmount the LVM snapshot."
fi

# Boot partition backup
inform_user "$ICyan" "Creating boot partition backup..."
if ! borg create "${BORG_OPTS[@]}" "$BACKUP_TARGET_DIRECTORY::$CURRENT_DATE-NcVM-boot-partition" "/boot/"
then
    inform_user "$ICyan" "Deleting the failed boot partition backup archive..."
    borg delete --stats "$BACKUP_TARGET_DIRECTORY::$CURRENT_DATE-NcVM-boot-partition"
    show_drive_usage
    re_rename_snapshot
    send_error_mail "Some errors were reported during the boot partition backup!"   
fi

# Backup additional locations
for directory in "${ADDITIONAL_BACKUP_DIRECTORIES[@]}"
do
    if [ -z "$directory" ]
    then
        continue
    fi
    DIRECTORY="${directory%%/}"
    DIRECTORY_NAME=$(echo "$DIRECTORY" | sed 's|^/||;s|/|-|;s| |_|')

    # Create backup
    inform_user "$ICyan" "Creating $DIRECTORY_NAME backup..."
    if ! borg create "${BORG_OPTS[@]}" --one-file-system \
"$BACKUP_TARGET_DIRECTORY::$CURRENT_DATE-NcVM-$DIRECTORY_NAME-directory" "$DIRECTORY/"
    then
        inform_user "$ICyan" "Deleting the failed $DIRECTORY_NAME backup archive..."
        borg delete --stats "$BACKUP_TARGET_DIRECTORY::$CURRENT_DATE-NcVM-$DIRECTORY_NAME-directory"
        show_drive_usage
        re_rename_snapshot
        send_error_mail "Some errors were reported during the $DIRECTORY_NAME backup!"
    fi
done

# Prune the backup repository
inform_user "$ICyan" "Pruning the backup..."
if ! borg prune --progress --stats "$BACKUP_TARGET_DIRECTORY" \
--keep-within=7d \
--keep-weekly=4 \
--keep-monthly=6
then
    re_rename_snapshot
    send_error_mail "Some errors were reported by the prune command."
fi

# Rename the snapshot back to normal
if ! re_rename_snapshot
then
    send_error_mail "Could not rename the snapshot-pending to snapshot."
fi

# Print usage of drives into log
show_drive_usage

# Unmount the backup drive
inform_user "$ICyan" "Unmounting the backup drive..."
if ! umount "$BACKUP_MOUNTPOINT"
then
    send_error_mail "Could not unmount the backup drive!"
fi

# Show expiration time
get_expiration_time
inform_user "$IGreen" "Backup finished on $END_DATE_READABLE ($DURATION_READABLE)"

# Send mail about successful backup
if ! send_mail "Daily backup successful!" "$(cat "$LOG_FILE")"
then
    notify_admin_gui \
    "Daily backup successful! Though mail sending didn't work!" \
    "Please look at the log file $LOG_FILE if you want to find out more."
    if [ -z "$CHECK_BACKUP" ]
    then
        paste_log_file
    fi
else
    paste_log_file
    remove_log_file
fi

# Exit here if the backup doesn't shall get checked
if [ -z "$CHECK_BACKUP" ]
then
    exit
fi

# Recreate logfile
if ! [ -f "$LOG_FILE" ]
then
    touch "$LOG_FILE"
    # Write output to logfile.
    exec > >(tee -i "$LOG_FILE")
    exec 2>&1
fi

# New start time
START_TIME=$(date +%s)
CURRENT_DATE=$(date --date @"$START_TIME" +"%Y%m%d_%H%M%S")
CURRENT_DATE_READABLE=$(date --date @"$START_TIME" +"%d.%m.%Y - %H:%M:%S")

# Inform user
inform_user "$IGreen" "Backup integrity check started! $CURRENT_DATE_READABLE"

# Check if pending snapshot is existing and cancel the backup check in this case.
if does_snapshot_exist "NcVM-snapshot-pending"
then
    send_error_mail "NcVM-snapshot-pending exists. Please try again later!" "Backup integrity check"
fi

# Prepare backup repository
inform_user "$ICyan" "Mounting the backup drive..."
if ! [ -d "$BACKUP_TARGET_DIRECTORY" ]
then
    mount "$BACKUP_MOUNTPOINT" &>/dev/null
    if ! [ -d "$BACKUP_TARGET_DIRECTORY" ]
    then
        send_error_mail "Could not mount the backup drive. Is it connected?" "Backup integrity check"
    fi
fi

# Rename the snapshot to represent that the backup is pending
inform_user "$ICyan" "Renaming the snapshot..."
if ! lvrename /dev/ubuntu-vg/NcVM-snapshot /dev/ubuntu-vg/NcVM-snapshot-pending
then
    send_error_mail "Could not rename the snapshot to snapshot-pending." "Backup integrity check"
fi

# Check the backup
inform_user "$ICyan" "Checking the backup integity..."
# TODO: check how long this takes. If too long, remove the --verifa-data flag
if ! borg check --verify-data "$BACKUP_TARGET_DIRECTORY"
then
    re_rename_snapshot
    send_error_mail "Some errors were reported during the backup integrity check!" "Backup integrity check"
fi

# Rename the snapshot back to normal
if ! re_rename_snapshot
then
    send_error_mail "Could not rename the snapshot-pending to snapshot." "Backup integrity check"
fi

# Print usage of drives into log
show_drive_usage

# Unmount the backup drive
inform_user "$ICyan" "Unmounting the backup drive..."
if ! umount "$BACKUP_MOUNTPOINT"
then
    send_error_mail "Could not unmount the backup drive!" "Backup integrity check"
fi

# Resetting the integrity Check
inform_user "$ICyan" "Resetting the backup check timer..."
sed -i "s|^export DAYS_SINCE_LAST_BACKUP_CHECK.*|export DAYS_SINCE_LAST_BACKUP_CHECK=0|" "$SCRIPTS/daily-borg-backup.sh"

# Show expiration time
get_expiration_time
inform_user "$IGreen" "Backup integrity check finished on $END_DATE_READABLE ($DURATION_READABLE)"

# Send mail about successful backup
if ! send_mail "Backup integrity check successful!" "$(cat "$LOG_FILE")"
then
    notify_admin_gui \
    "Backup integrity check succesful! Though mail sending didn't work!" \
    "Please look at the log file $LOG_FILE if you want to find out more."
    paste_log_file
else
    paste_log_file
    remove_log_file
fi

exit
