#!/bin/bash

# T&M Hansson IT AB © - 2024, https://www.hanssonit.se/
# Copyright © 2021 Simon Lindner (https://github.com/szaimen)

# shellcheck disable=2024
true
SCRIPT_NAME="Borg Backup"
SCRIPT_EXPLAINER="This script creates the Borg backup of your server."
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
LVM_MOUNT="/system"
ZFS_MOUNT="/ncdata"
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
start_services() {
    inform_user "$ICyan" "Starting services..."
    systemctl start postgresql
    if [ -z "$MAINTENANCE_MODE_ON" ]
    then
        sudo -u www-data php "$NCPATH"/occ maintenance:mode --off
    fi
    start_if_stopped docker
    # Restart notify push if existing
    if [ -f "$NOTIFY_PUSH_SERVICE_PATH" ]
    then
        systemctl restart notify_push
    fi
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
    if [ -n "$ZFS_PART_EXISTS" ]
    then
        if mountpoint -q "$ZFS_MOUNT"
        then
            umount "$ZFS_MOUNT"
        fi
    fi
    if [ -d "$BACKUP_TARGET_DIRECTORY" ]
    then
        if [ -z "$DO_NOT_UMOUNT_DAILY_BACKUP_DRIVE" ]
        then
            inform_user "$ICyan" "Unmounting the backup drive..."
            umount "$BACKUP_MOUNTPOINT"
        fi
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
check_snapshot_pending() {
    if does_snapshot_exist "NcVM-snapshot-pending"
    then
        DO_NOT_UMOUNT_DAILY_BACKUP_DRIVE=1
        msg_box "The snapshot pending does exist. Can currently not proceed.
Please try again later.\n
If you are sure that no update or backup is currently running, you can fix this by rebooting your server."
        send_error_mail "NcVM-snapshot-pending exists. Please try again later!" "$1"
    fi
}

# Secure the backup file
chown root:root "$SCRIPTS/daily-borg-backup.sh"
chmod 700 "$SCRIPTS/daily-borg-backup.sh"

# Skip daily backup creation if needed
if [ -z "$SKIP_DAILY_BACKUP_CREATION" ]
then

    # Add automatical unlock upon reboot
    crontab -u root -l | grep -v "lvrename /dev/ubuntu-vg/NcVM-snapshot-pending"  | crontab -u root -
    crontab -u root -l | { cat; echo "@reboot /usr/sbin/lvrename /dev/ubuntu-vg/NcVM-snapshot-pending \
    /dev/ubuntu-vg/NcVM-snapshot &>/dev/null" ; } | crontab -u root -

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

    # Check if /mnt/ncdata is mounted
    if grep -q " /mnt/ncdata " /etc/mtab && ! grep " /mnt/ncdata " /etc/mtab | grep -q zfs
    then
        msg_box "The '/mnt/ncdata' directory is mounted and not existing on the root drive."
        exit 1
    fi
    # The home directory must exist on the root drive
    if grep -q " /home " /etc/mtab
    then
        send_error_mail "The '/home' directory is mounted and not existing on the root drive."
    fi
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

# Export default values
export BORG_PASSPHRASE="$ENCRYPTION_KEY"
export BORG_UNKNOWN_UNENCRYPTED_REPO_ACCESS_IS_OK=yes
export BORG_RELOCATED_REPO_ACCESS_IS_OK=yes

# Skip daily backup creation if needed
if [ -z "$SKIP_DAILY_BACKUP_CREATION" ]
then
    # Check if backup shall get checked
    if [ "$DAYS_SINCE_LAST_BACKUP_CHECK" -ge "$CHECK_BACKUP_INTERVAL_DAYS" ]
    then
        CHECK_BACKUP=1
    else
        DAYS_SINCE_LAST_BACKUP_CHECK=$((DAYS_SINCE_LAST_BACKUP_CHECK+1))
        sed -i "s|^export DAYS_SINCE_LAST_BACKUP_CHECK.*|export DAYS_SINCE_LAST_BACKUP_CHECK=$DAYS_SINCE_LAST_BACKUP_CHECK|" "$SCRIPTS/daily-borg-backup.sh"
    fi
    # Check if pending snapshot is existing and cancel the backup in this case.
    check_snapshot_pending

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

    # Test if btrfs volume
    if grep " $BACKUP_MOUNTPOINT " /etc/mtab | grep -q btrfs
    then
        IS_BTRFS_PART=1
        mkdir -p "$BACKUP_MOUNTPOINT/.snapshots"
        btrfs subvolume snapshot -r "$BACKUP_MOUNTPOINT" "$BACKUP_MOUNTPOINT/.snapshots/@$CURRENT_DATE"
        while [ "$(find "$BACKUP_MOUNTPOINT/.snapshots/" -maxdepth 1 -mindepth 1 -type d -name '@*_*' | wc -l)" -gt 14 ]
        do
            DELETE_SNAP="$(find "$BACKUP_MOUNTPOINT/.snapshots/" -maxdepth 1 -mindepth 1 -type d -name '@*_*' | sort | head -1)"
            btrfs subvolume delete "$DELETE_SNAP"
        done
    fi

    # Send mail that backup was started
    if ! send_mail "Daily backup started!" "You will be notified again when the backup is finished!
Please don't restart or shutdown your server until then!"
    then
        notify_admin_gui "Daily backup started!" "You will be notified again when the backup is finished!
Please don't restart or shutdown your server until then!"
    fi

    # Check if pending snapshot is existing and cancel the backup in this case.
    check_snapshot_pending

    # Fix too large Borg cache
    # https://borgbackup.readthedocs.io/en/stable/faq.html#the-borg-cache-eats-way-too-much-disk-space-what-can-i-do
    find /root/.cache/borg/ -maxdepth 2 -name chunks.archive.d -type d -exec rm -r {} \; -exec touch {} \;

    # Stop services
    inform_user "$ICyan" "Stopping services..."
    if is_docker_running
    then
        systemctl stop docker
    fi
    if [ "$(sudo -u www-data php "$NCPATH"/occ config:system:get maintenance)" = "true" ]
    then
        MAINTENANCE_MODE_ON=1
    fi
    sudo -u www-data php "$NCPATH"/occ maintenance:mode --on
    # Database export
    # Not really necessary since the root partition gets backed up but easier to restore on new systems
    ncdb # get NCDB
    rm -f "$SCRIPTS"/nextclouddb.sql "$SCRIPTS"/nextclouddb.dump
    rm -f "$SCRIPTS"/alldatabases.sql "$SCRIPTS"/alldatabases.dump
    if sudo -Hiu postgres psql -c "SELECT 1 AS result FROM pg_database WHERE datname='$NCDB'" | grep -q "1 row"
    then
        inform_user "$ICyan" "Doing pgdump of $NCDB..."
        sudo -Hiu postgres pg_dump "$NCDB"  > "$SCRIPTS"/nextclouddb.dump
        chown root:root "$SCRIPTS"/nextclouddb.dump
        chmod 600 "$SCRIPTS"/nextclouddb.dump
    else
        inform_user "$ICyan" "Doing pgdump of all databases..."
        sudo -Hiu postgres pg_dumpall > "$SCRIPTS"/alldatabases.dump
        chown root:root "$SCRIPTS"/alldatabases.dump
        chmod 600 "$SCRIPTS"/alldatabases.dump
    fi
    systemctl stop postgresql

    # Check if pending snapshot is existing and cancel the backup in this case.
    check_snapshot_pending

    # Create LVM snapshot & Co.
    inform_user "$ICyan" "Creating LVM snapshot..."
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

    # Cover zfs snapshots
    if grep " /mnt/ncdata " /etc/mtab | grep -q zfs
    then
        ZFS_PART_EXISTS=1
        sed -i "s|date --utc|date|g" /usr/sbin/zfs-auto-snapshot
        if ! zfs-auto-snapshot -r ncdata
        then
            send_error_mail "Could not create ZFS snapshot!"
        fi
        inform_user "$IGreen" "ZFS snapshot successfully created!"
        ZFS_SNAP_NAME="$(zfs list -t snapshot | grep ncdata | grep snap-202 | sort -r | head -1 | awk '{print $1}')"
        # Mount zfs snapshot
        if mountpoint -q "$ZFS_MOUNT"
        then
            if ! umount "$ZFS_MOUNT"
            then
                send_error_mail "Could not unmount '$ZFS_MOUNT'!"
            fi
        fi
        mkdir -p "$ZFS_MOUNT"
        inform_user "$ICyan" "Mounting the ZFS snapshot..."
        if ! mount --read-only --types zfs "$ZFS_SNAP_NAME" "$ZFS_MOUNT"
        then
            send_error_mail "Could not mount the ZFS snapshot!"
        fi
    fi

    # Check if pending snapshot is existing and cancel the backup in this case.
    check_snapshot_pending

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

    # Log Borg version
    borg --version

    # Break the borg lock if it exists because we have the snapshot that prevents such situations
    if [ -f "$BACKUP_TARGET_DIRECTORY/lock.roster" ]
    then
        inform_user "$ICyan" "Breaking the borg lock..."
        if ! borg break-lock "$BACKUP_TARGET_DIRECTORY"
        then
            re_rename_snapshot
            send_error_mail "Some errors were reported while breaking the borg lock!"
        fi
    fi

    # Borg options
    # auto,zstd compression seems to has the best ratio based on:
    # https://forum.level1techs.com/t/optimal-compression-for-borg-backups/145870/6
    BORG_OPTS=(--stats --compression "auto,zstd" --exclude-caches --checkpoint-interval 86400)

    # System backup
    EXCLUDED_DIRECTORIES=(home/*/.cache root/.cache home/plex/transcode var/cache lost+found \
    run var/run dev tmp "home/plex/config/Library/Application Support/Plex Media Server/Cache")
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
    SNAPSHOT_USED=$(lvs -o name,data_percent | grep "NcVM-snapshot-pending" | awk '{print $2}' | sed 's|\..*||' | sed 's|,.*||')
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
    rm -r "$LVM_MOUNT"

    # Prune options
    BORG_PRUNE_OPTS=(--stats --keep-within=7d --keep-weekly=4 --keep-monthly=6 "$BACKUP_TARGET_DIRECTORY")

    # Prune system archives
    inform_user "$ICyan" "Pruning the system archives..."
    if ! borg prune --glob-archives '*_*-NcVM-system-partition' "${BORG_PRUNE_OPTS[@]}"
    then
        re_rename_snapshot
        send_error_mail "Some errors were reported by the prune system command."
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

    # Prune boot archives
    inform_user "$ICyan" "Pruning the boot archives..."
    if ! borg prune --glob-archives '*_*-NcVM-boot-partition' "${BORG_PRUNE_OPTS[@]}"
    then
        re_rename_snapshot
        send_error_mail "Some errors were reported by the prune boot command."
    fi

    # Create ZFS backup
    if [ -n "$ZFS_PART_EXISTS" ]
    then
        inform_user "$ICyan" "Creating ncdata partition backup..."
        if ! borg create "${BORG_OPTS[@]}" --one-file-system \
    "$BACKUP_TARGET_DIRECTORY::$CURRENT_DATE-NcVM-ncdata-partition" "$ZFS_MOUNT/"
        then
            inform_user "$ICyan" "Deleting the failed ncdata backup archive..."
            borg delete --stats "$BACKUP_TARGET_DIRECTORY::$CURRENT_DATE-NcVM-ncdata-partition"
            show_drive_usage
            re_rename_snapshot
            send_error_mail "Some errors were reported during the ncdata partition backup!"
        fi
        # Prune ncdata archives
        inform_user "$ICyan" "Pruning the ncdata archives..."
        if ! borg prune --glob-archives '*_*-NcVM-ncdata-partition' "${BORG_PRUNE_OPTS[@]}"
        then
            re_rename_snapshot
            send_error_mail "Some errors were reported by the prune ncdata command."
        fi
        # Unmount ZFS snapshot
        inform_user "$ICyan" "Unmounting the ZFS snapshot..."
        if ! umount "$ZFS_MOUNT"
        then
            re_rename_snapshot
            send_error_mail "Could not unmount the ZFS snapshot."
        fi
        rm -r "$ZFS_MOUNT"
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

        # Wait for the drive to spin up (else it is possible that some subdirectories are not backed up)
        inform_user "$ICyan" "Waiting 15s for the $DIRECTORY_NAME directory..."
        timeout 0.1s ls -l "$DIRECTORY/" &>/dev/null
        if ! sleep 15
        then
            # In case someone cancels with ctrl+c here
            re_rename_snapshot
            send_error_mail "Something failed while waiting for the $DIRECTORY_NAME directory."
        fi

        # Create backup
        inform_user "$ICyan" "Creating $DIRECTORY_NAME backup..."
        if ! borg create "${BORG_OPTS[@]}" --one-file-system --exclude "$DIRECTORY/.snapshots/" \
"$BACKUP_TARGET_DIRECTORY::$CURRENT_DATE-NcVM-$DIRECTORY_NAME-directory" "$DIRECTORY/"
        then
            inform_user "$ICyan" "Deleting the failed $DIRECTORY_NAME backup archive..."
            borg delete --stats "$BACKUP_TARGET_DIRECTORY::$CURRENT_DATE-NcVM-$DIRECTORY_NAME-directory"
            show_drive_usage
            re_rename_snapshot
            send_error_mail "Some errors were reported during the $DIRECTORY_NAME backup!"
        fi

        # Prune archives
        inform_user "$ICyan" "Pruning the $DIRECTORY_NAME archives..."
        if ! borg prune --glob-archives "*_*-NcVM-$DIRECTORY_NAME-directory" "${BORG_PRUNE_OPTS[@]}"
        then
            re_rename_snapshot
            send_error_mail "Some errors were reported by the prune $DIRECTORY_NAME command."
        fi
    done

    # Run a borg compact which is required with borg 1.2.0 and higher
    if borg compact -h &>/dev/null
    then
        inform_user "$ICyan" "Starting borg compact which will clean up not needed commits and free space..."
        if ! borg compact "$BACKUP_TARGET_DIRECTORY"
        then
            re_rename_snapshot
            send_error_mail "Some errors were reported during borg compact!"
        fi
    fi

    # Rename the snapshot back to normal
    if ! re_rename_snapshot
    then
        send_error_mail "Could not rename the snapshot-pending to snapshot."
    fi

    # Print usage of drives into log
    show_drive_usage

    # Adjust permissions and scrub volume
    if [ -n "$IS_BTRFS_PART" ]
    then
        inform_user "$ICyan" "Adjusting permissions..."
        find "$BACKUP_MOUNTPOINT/" -not -path "$BACKUP_MOUNTPOINT/.snapshots/*" \
    \( ! -perm 600 -o ! -group root -o ! -user root \) -exec chmod 600 {} \; -exec chown root:root {} \; 
    fi

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

    # Create a file that can be checked for
    rm -f /tmp/DAILY_BACKUP_CREATION_SUCCESSFUL
    touch /tmp/DAILY_BACKUP_CREATION_SUCCESSFUL

    # Exit here if the backup doesn't shall get checked
    if [ -z "$CHECK_BACKUP" ]
    then
        exit
    fi

    # Exit here if we want to skip the backup check
    if [ -n "$SKIP_DAILY_BACKUP_CHECK" ]
    then
        exit
    fi
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
check_snapshot_pending "Backup integrity check"

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

# Send mail that backup was started
if ! send_mail "Weekly backup check started!" "You will be notified again when the check is finished!
Please don't restart or shutdown your server until then!"
then
    notify_admin_gui "Weekly backup check started!" "You will be notified again when the check is finished!
Please don't restart or shutdown your server until then!"
fi

# Check if pending snapshot is existing and cancel the backup check in this case.
check_snapshot_pending "Backup integrity check"

# Rename the snapshot to represent that the backup is pending
inform_user "$ICyan" "Renaming the snapshot..."
if ! lvrename /dev/ubuntu-vg/NcVM-snapshot /dev/ubuntu-vg/NcVM-snapshot-pending
then
    send_error_mail "Could not rename the snapshot to snapshot-pending." "Backup integrity check"
fi

# Check the backup
inform_user "$ICyan" "Checking the backup integrity..."
# TODO: check how long this takes. If too long, remove the --verifa-data flag
if ! borg check --verify-data "$BACKUP_TARGET_DIRECTORY"
then
    re_rename_snapshot
    send_error_mail "Some errors were reported during the backup integrity check!" "Backup integrity check"
fi

# Adjust permissions and scrub volume
if [ -n "$IS_BTRFS_PART" ] && [ "$BTRFS_SCRUB_BACKUP_DRIVE" = "yes" ]
then
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
    send_error_mail "Could not rename the snapshot-pending to snapshot." "Backup integrity check"
fi

# Print usage of drives into log
show_drive_usage

# Unmount the backup drive
if [ -z "$SKIP_DAILY_BACKUP_CREATION" ]
then
    inform_user "$ICyan" "Unmounting the backup drive..."
    if mountpoint -q "$BACKUP_MOUNTPOINT" && ! umount "$BACKUP_MOUNTPOINT"
    then
        send_error_mail "Could not unmount the backup drive!" "Backup integrity check"
    fi
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
    "Backup integrity check successful! Though mail sending didn't work!" \
    "Please look at the log file $LOG_FILE if you want to find out more."
    paste_log_file
else
    paste_log_file
    remove_log_file
fi

# Create a file that can be checked for
rm -f /tmp/DAILY_BACKUP_CHECK_SUCCESSFUL
touch /tmp/DAILY_BACKUP_CHECK_SUCCESSFUL

exit
