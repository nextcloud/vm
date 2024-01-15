#!/bin/bash

# T&M Hansson IT AB © - 2024, https://www.hanssonit.se/
# Copyright © 2021 Simon Lindner (https://github.com/szaimen)

true
SCRIPT_NAME="System Restore"
SCRIPT_EXPLAINER="This script let's you restore your system- and boot-partition to a previous state."
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
DAILY_BACKUP_FILE="$SCRIPTS/daily-borg-backup.sh"
OFFSHORE_BACKUP_FILE="$SCRIPTS/off-shore-rsync-backup.sh"

# Functions
restore_original_state() {
    # Restore original cache and security folder
    if [ "$BACKUP_MOUNTPOINT" = "$OFFSHORE_BACKUP_MOUNTPOINT" ]
    then
        rm -r /root/.config/borg/security
        mv /root/.config/borg/security.bak/ /root/.config/borg/security
        rm -r /root/.cache/borg
        mv /root/.cache/borg.bak/ /root/.cache/borg
    fi

    # Re-rename the snapshot to represent that it is done
    if ! lvrename /dev/ubuntu-vg/NcVM-snapshot-pending /dev/ubuntu-vg/NcVM-snapshot
    then
        msg_box "Could not re-rename the snapshot. Please reboot your server!"
        exit 1
    fi

    # Unmount the backup drive
    sleep 1
    if ! umount "$BACKUP_MOUNTPOINT"
    then
        msg_box "Something went wrong while unmounting the backup drive."
        exit 1
    fi
}

# Ask for execution
msg_box "$SCRIPT_EXPLAINER"
if ! yesno_box_yes "Do you want to restore your system to a previous state?"
then
    exit
fi

# Check if restore is possible
if ! [ -f "$DAILY_BACKUP_FILE" ]
then
    msg_box "It seems like you haven't set up daily borg backups.
Please do that before you can view backups."
    exit 1
fi
# Get needed variables
ENCRYPTION_KEY="$(grep "ENCRYPTION_KEY=" "$DAILY_BACKUP_FILE" | sed "s|.*ENCRYPTION_KEY=||;s|'||g;s|\"||g")"
DAILY_BACKUP_MOUNTPOINT="$(grep "BACKUP_MOUNTPOINT=" "$DAILY_BACKUP_FILE" | sed 's|.*BACKUP_MOUNTPOINT="||;s|"||')"
DAILY_BACKUP_TARGET="$(grep "BACKUP_TARGET_DIRECTORY=" "$DAILY_BACKUP_FILE" | sed 's|.*BACKUP_TARGET_DIRECTORY="||;s|"||')"
if [ -z "$ENCRYPTION_KEY" ] || [ -z "$DAILY_BACKUP_FILE" ] || [ -z "$DAILY_BACKUP_FILE" ]
then
    msg_box "Some daily backup variables are empty. This is wrong."
    exit 1
fi
# Also get variables from the offshore backup file
if [ -f "$OFFSHORE_BACKUP_FILE" ]
then
    OFFSHORE_BACKUP_MOUNTPOINT="$(grep "BACKUP_MOUNTPOINT=" "$OFFSHORE_BACKUP_FILE" | sed 's|.*BACKUP_MOUNTPOINT="||;s|"||')"
    OFFSHORE_BACKUP_TARGET="$(grep "BACKUP_TARGET_DIRECTORY=" "$OFFSHORE_BACKUP_FILE" | sed 's|.*BACKUP_TARGET_DIRECTORY="||;s|"||')"
    if [ -z "$OFFSHORE_BACKUP_MOUNTPOINT" ] ||[ -z "$OFFSHORE_BACKUP_TARGET" ]
    then
        msg_box "Some off-shore backup variables are empty. This is wrong."
        exit 1
    fi
fi
# Check if pending snapshot is existing and cancel the viewing in this case.
if does_snapshot_exist "NcVM-snapshot-pending"
then
    msg_box "The snapshot pending does exist. Can currently not show the backup.
Please try again later.\n
If you are sure that no update or backup is currently running, you can fix this by rebooting your server."
    exit 1
fi
# Check if startup snapshot is existing and cancel the viewing in this case.
if does_snapshot_exist "NcVM-startup"
then
    msg_box "The snapshot startup does exist.
Please run the update script first."
    exit 1
fi
# Check if snapshot can get renamed
if ! does_snapshot_exist "NcVM-snapshot"
then
    msg_box "The NcVM-snapshot doesn't exist. This isn't allowed."
    exit 1
fi

# Ask if a backup was created
msg_box "It is recommended to make a backup and/or snapshot of your NcVM before restoring the system."
if ! yesno_box_no "Have you made a backup of your NcVM?"
then
    if ! yesno_box_yes "Do you want to run the backup now?"
    then
        exit 1
    fi
    rm -f /tmp/DAILY_BACKUP_CREATION_SUCCESSFUL
    export SKIP_DAILY_BACKUP_CHECK=1
    bash "$DAILY_BACKUP_FILE"
    if ! [ -f "/tmp/DAILY_BACKUP_CREATION_SUCCESSFUL" ]
    then
        if ! yesno_box_no "It seems like the backup was not successful. Do you want to continue nonetheless? (Not recommended!)"
        then
            exit 1
        fi
    fi
fi

print_text_in_color "$ICyan" "Checking which backup drives are connected. This can take a while..."

# View backup repository menu
args=(whiptail --title "$TITLE" --menu \
"Please select the backup repository that you want to view.
$MENU_GUIDE" "$WT_HEIGHT" "$WT_WIDTH" 4)

# Check if at least one drive is connected
DAILY=1
if ! [ -d "$DAILY_BACKUP_TARGET" ]
then
    mount "$DAILY_BACKUP_MOUNTPOINT" &>/dev/null
    if ! [ -d "$DAILY_BACKUP_TARGET" ]
    then
        DAILY=""
    fi
    umount "$DAILY_BACKUP_MOUNTPOINT" &>/dev/null
fi
if [ -f "$OFFSHORE_BACKUP_FILE" ]
then
    OFFSHORE=1
    if ! [ -d "$OFFSHORE_BACKUP_TARGET" ]
    then
        mount "$OFFSHORE_BACKUP_MOUNTPOINT" &>/dev/null
        if ! [ -d "$OFFSHORE_BACKUP_TARGET" ]
        then
            OFFSHORE=""
        fi
    fi
    umount "$OFFSHORE_BACKUP_MOUNTPOINT" &>/dev/null
fi
if [ -z "$DAILY" ] && [ -z "$OFFSHORE" ]
then
    msg_box "Not even one backup drive is connected.
You must connect one if you want to view a backup."
    exit 1
fi

# Get which one is connected
if [ -n "$DAILY" ]
then
    args+=("$DAILY_BACKUP_TARGET" " Daily Backup Repository")
fi
if [ -n "$OFFSHORE" ]
then
    args+=("$OFFSHORE_BACKUP_TARGET" " Off-Shore Backup Repository")
fi

# Show the menu
choice=$("${args[@]}" 3>&1 1>&2 2>&3)
if [ -z "$choice" ]
then
    msg_box "No target selected. Exiting."
    exit 1
fi

# Check the boot mountpoint
if mountpoint -q /tmp/borgboot
then
    umount /tmp/borgboot
    if mountpoint -q /tmp/borgboot
    then
        msg_box "There is still something mounted on /tmp/borgboot. Cannot proceed."
        exit 1
    fi
fi

# Check the system mountpoint
if mountpoint -q /tmp/borgsystem
then
    umount /tmp/borgsystem
    if mountpoint -q /tmp/borgsystem
    then
        msg_box "There is still something mounted on /tmp/borgsystem. Cannot proceed."
        exit 1
    fi
fi

# Check if /mnt/ncdata exists
if grep -q " /mnt/ncdata " /etc/mtab
then
    NCDATA_PART_EXISTS=yes
fi

# Check the ncdata mountpoint
if [ -n "$NCDATA_PART_EXISTS" ]
then
    if mountpoint -q /tmp/borgncdata
    then
        umount /tmp/borgboot
        if mountpoint -q /tmp/borgncdata
        then
            msg_box "There is still something mounted on /tmp/borgncdata. Cannot proceed."
            exit 1
        fi
    fi
fi

# Check if pending snapshot is existing and cancel the restore process in this case.
if does_snapshot_exist "NcVM-snapshot-pending"
then
    msg_box "The snapshot pending does exist. Can currently not restore the backup.
Please try again later.\n
If you are sure that no update or backup is currently running, you can fix this by rebooting your server."
    exit 1
fi

# Rename the snapshot to represent that the backup is locked
if ! lvrename /dev/ubuntu-vg/NcVM-snapshot /dev/ubuntu-vg/NcVM-snapshot-pending
then
    msg_box "Could not rename the snapshot. Please reboot your server!"
    exit 1
fi

# Find out which one was selected
BACKUP_TARGET_DIRECTORY="$choice"
if [ "$BACKUP_TARGET_DIRECTORY" = "$DAILY_BACKUP_TARGET" ]
then
    BACKUP_MOUNTPOINT="$DAILY_BACKUP_MOUNTPOINT"
elif [ "$BACKUP_TARGET_DIRECTORY" = "$OFFSHORE_BACKUP_TARGET" ]
then
    BACKUP_MOUNTPOINT="$OFFSHORE_BACKUP_MOUNTPOINT"
    # Work around issue with borg
    # https://github.com/borgbackup/borg/issues/3428#issuecomment-380399036
    mv /root/.config/borg/security/ /root/.config/borg/security.bak
    mv /root/.cache/borg/ /root/.cache/borg.bak
fi

# Mount the backup drive
if ! mount "$BACKUP_MOUNTPOINT"
then
    msg_box "Could not mount the backup drive."
    restore_original_state
    exit 1
fi

# Export passphrase
export BORG_PASSPHRASE="$ENCRYPTION_KEY"

# Break the borg lock if it exists because we have the snapshot that prevents such situations
if [ -f "$BACKUP_TARGET_DIRECTORY/lock.roster" ]
then
    print_text_in_color "$ICyan" "Breaking the borg lock..."
    borg break-lock "$BACKUP_TARGET_DIRECTORY"
fi

# Find available archives
ALL_ARCHIVES=$(borg list "$BACKUP_TARGET_DIRECTORY")
SYSTEM_ARCHIVES=$(echo "$ALL_ARCHIVES" | grep "NcVM-system-partition" | awk -F "-" '{print $1}' | sort -r)
mapfile -t SYSTEM_ARCHIVES <<< "$SYSTEM_ARCHIVES"
BOOT_ARCHIVES=$(echo "$ALL_ARCHIVES" | grep "NcVM-boot-partition" | awk -F "-" '{print $1}' | sort -r)
mapfile -t BOOT_ARCHIVES <<< "$BOOT_ARCHIVES"
NCDATA_ARCHIVES=$(echo "$ALL_ARCHIVES" | grep "NcVM-ncdata-partition" | awk -F "-" '{print $1}' | sort -r)
if [ -n "$NCDATA_ARCHIVES" ]
then
    NCDATA_ARCHIVE_EXISTS=yes
fi
mapfile -t NCDATA_ARCHIVES <<< "$NCDATA_ARCHIVES"

# Check if the setup is correct
if [ "$NCDATA_PART_EXISTS" != "$NCDATA_ARCHIVE_EXISTS" ]
then
    msg_box "Cannot restore the system since either the ncdata partition doesn't exist and is in the repository \
or the partition exists and isn't in the repository."
    restore_original_state
    exit 1
fi

# Find valid archives
for system_archive in "${SYSTEM_ARCHIVES[@]}"
do
    for boot_archive in "${BOOT_ARCHIVES[@]}"
    do
        if [ -n "$NCDATA_ARCHIVE_EXISTS" ]
        then
            for ncdata_archive in "${NCDATA_ARCHIVES[@]}"
            do
                if [ "$system_archive" = "$boot_archive" ] && [ "$system_archive" = "$ncdata_archive" ]
                then
                    VALID_ARCHIVES+=("$system_archive")
                    continue
                fi
            done
        elif [ "$system_archive" = "$boot_archive" ]
        then
            VALID_ARCHIVES+=("$system_archive")
            continue
        fi
    done
done

# Test if at least one valid archive was found
if [ -z "${VALID_ARCHIVES[*]}" ]
then
    msg_box "Not even one valid archive found. Cannot continue."
    restore_original_state
    exit 1
fi

# Create menu to select from available archives
unset args
args=(whiptail --title "$TITLE" --menu \
"Please select the backup archive that you want to restore.
$MENU_GUIDE" "$WT_HEIGHT" "$WT_WIDTH" 4)
for valid_archive in "${VALID_ARCHIVES[@]}"
do
    HUMAN_DATE=$(echo "$ALL_ARCHIVES" | grep "$valid_archive" | head -1 | awk '{print $3}')
    HUMAN_TIME=$(echo "$ALL_ARCHIVES" | grep "$valid_archive" | head -1 | awk '{print $4}')
    args+=("$valid_archive" "The backup was made on $HUMAN_DATE $HUMAN_TIME")
done

# Show the menu
choice=$("${args[@]}" 3>&1 1>&2 2>&3)
if [ -z "$choice" ]
then
    msg_box "No archive selected. Exiting."
    restore_original_state
    exit 1
else
    SELECTED_ARCHIVE="$choice"
fi

# Inform user
msg_box "We've implemented the option to test the extraction of the backup before we start the restore process.
This can take a lot of time though and is because of that not the default."
if yesno_box_no "Do you want to test the extraction of the backup nonetheless?"
then
    print_text_in_color "$ICyan" "Checking the system partition archive integrity. Please be patient!"
    mkdir -p /tmp/borgextract
    cd /tmp/borgextract
    if ! borg extract --dry-run --list "$BACKUP_TARGET_DIRECTORY::$SELECTED_ARCHIVE-NcVM-system-partition"
    then
        msg_box "Some errors were reported while checking the system partition archive integrity."
        restore_original_state
        exit 1
    fi
    print_text_in_color "$ICyan" "Checking the boot partition archive integrity. Please be patient!"
    if ! borg extract --dry-run --list "$BACKUP_TARGET_DIRECTORY::$SELECTED_ARCHIVE-NcVM-boot-partition"
    then
        msg_box "Some errors were reported while checking the boot partition archive integrity."
        restore_original_state
        exit 1
    fi
    if [ -n "$NCDATA_ARCHIVE_EXISTS" ]
    then
        print_text_in_color "$ICyan" "Checking the ncdata partition archive integrity. Please be patient!"
        if ! borg extract --dry-run --list "$BACKUP_TARGET_DIRECTORY::$SELECTED_ARCHIVE-NcVM-ncdata-partition"
        then
            msg_box "Some errors were reported while checking the ncdata partition archive integrity."
            restore_original_state
            exit 1
        fi
    fi
    msg_box "The extraction of the backup was tested successfully!"
fi

print_text_in_color "$ICyan" "Mounting all needed directories from the backup now. This can take a while..."

# Mount system archive
mkdir -p /tmp/borgsystem
if ! borg mount "$BACKUP_TARGET_DIRECTORY::$SELECTED_ARCHIVE-NcVM-system-partition" /tmp/borgsystem
then
    msg_box "Something failed while mounting the system partition archive. Please try again."
    restore_original_state
    exit 1
fi

# Mount boot archive
mkdir -p /tmp/borgboot
if ! borg mount "$BACKUP_TARGET_DIRECTORY::$SELECTED_ARCHIVE-NcVM-boot-partition" /tmp/borgboot
then
    msg_box "Something failed while mounting the boot partition archive. Please try again."
    umount /tmp/borgsystem
    restore_original_state
    exit 1
fi

# Mount ncdata archive
if [ -n "$NCDATA_ARCHIVE_EXISTS" ]
then
    mkdir -p /tmp/borgncdata
    if ! borg mount "$BACKUP_TARGET_DIRECTORY::$SELECTED_ARCHIVE-NcVM-ncdata-partition" /tmp/borgncdata
    then
        msg_box "Something failed while mounting the ncdata partition archive. Please try again."
        umount /tmp/borgsystem
        umount /tmp/borgboot
        restore_original_state
        exit 1
    fi
fi

# Check if all system entries are there
SYS_DRIVES=$(grep "^/dev/disk/by-" /etc/fstab | grep defaults | awk '{print $1}')
mapfile -t SYS_DRIVES <<< "$SYS_DRIVES"
for drive in "${SYS_DRIVES[@]}"
do
    if ! grep -q "$drive" /tmp/borgsystem/system/etc/fstab
    then
        msg_box "Cannot restore to this archive point since fstab entries are missing/not there.
This might be because the archive was created on a different Ubuntu installation."
        umount /tmp/borgsystem
        umount /tmp/borgboot
        umount /tmp/borgncdata &>/dev/null
        restore_original_state
        exit 1
    fi
done

# Exclude some dirs; mnt, media, sys, prob don't need to be excluded because of the usage of --one-file-system flag
EXCLUDED_DIRECTORIES=(home/*/.cache root/.cache root/.config/borg var/cache \
lost+found run var/run tmp var/tmp etc/lvm/archive snap "home/plex/config/Library/Application Support/Plex Media Server/Cache")

# Allow to disable restoring of Previews
if ! yesno_box_yes "Do you want to restore Nextclouds previews? This might slow down the restore process by a lot.
If you select 'No', the preview folder will be excluded from the restore process which can lead to preview issues in Nextcloud."
then
    PREVIEW_EXCLUDED=("--exclude=/appdata_"*/preview/)
    EXCLUDED_DIRECTORIES+=("$NCDATA"/appdata_*/preview)
fi

for directory in "${EXCLUDED_DIRECTORIES[@]}"
do
    directory="${directory#/*}"
    EXCLUDE_DIRS+=(--exclude="/$directory/")
done

# Inform user
if ! yesno_box_no "Are you sure that you want to restore your system to the selected state?
Please note that this will also restore the Bitwarden RS/Vaultwarden/Bitwarden database so newly created passwords that were created in the meantime since this backup will get deleted.
If you select 'Yes', we will start the restore process!"
then
    umount /tmp/borgsystem
    umount /tmp/borgboot
    umount /tmp/borgncdata &>/dev/null
    restore_original_state
    exit 1
fi

# Inform user
msg_box "We will now start the restore process. Please wait until you see the next popup! This can take a while!"

# Start the restore
print_text_in_color "$ICyan" "Starting the restore process..."

# Check if dpkg or apt is running
is_process_running apt
is_process_running dpkg

# Stop services
print_text_in_color "$ICyan" "Stopping services..."
if is_docker_running
then
    systemctl stop docker
fi
nextcloud_occ_no_check maintenance:mode --on
systemctl stop postgresql

# Restore the system partition
print_text_in_color "$ICyan" "Restoring the files..."
if ! rsync --archive --human-readable --delete --one-file-system \
-vv "${EXCLUDE_DIRS[@]}" /tmp/borgsystem/system/ /
then
    SYSTEM_RESTORE_FAILED=1
fi

# Restore the boot partition
if ! rsync --archive --human-readable -vv --delete /tmp/borgboot/boot/ /boot
then
    if [ "$SYSTEM_RESTORE_FAILED" = 1 ]
    then
        msg_box "Something failed while restoring the system partition."
    fi
    msg_box "Something failed while restoring the boot partition."
    umount /tmp/borgsystem
    umount /tmp/borgboot
    umount /tmp/borgncdata &>/dev/null
    restore_original_state
    exit 1
fi

if [ "$SYSTEM_RESTORE_FAILED" = 1 ]
then
    msg_box "Something failed while restoring the system partition."
    umount /tmp/borgsystem
    umount /tmp/borgboot
    umount /tmp/borgncdata &>/dev/null
    restore_original_state
    exit 1
fi

# Restore the ncdata partition
if [ -n "$NCDATA_ARCHIVE_EXISTS" ]
then
    if ! rsync --archive --human-readable --delete --one-file-system \
-vv "${PREVIEW_EXCLUDED[*]}" /tmp/borgncdata/ncdata/ /mnt/ncdata
    then
        msg_box "Something failed while restoring the ncdata partition."
        umount /tmp/borgsystem
        umount /tmp/borgboot
        umount /tmp/borgncdata
        restore_original_state
        exit 1
    fi
fi

# Start services
print_text_in_color "$ICyan" "Starting services..."
systemctl start postgresql
nextcloud_occ_no_check maintenance:mode --off
start_if_stopped docker

# Restore original state
umount /tmp/borgsystem
umount /tmp/borgboot
umount /tmp/borgncdata &>/dev/null
restore_original_state

# Allow to reboot: recommended
msg_box "Congratulations, the restore was successful!\n
It is highly recommended to reboot your server now."
if yesno_box_yes "Do you want to reboot now?"
then
    reboot
fi

exit
