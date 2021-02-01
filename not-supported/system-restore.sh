#!/bin/bash

# T&M Hansson IT AB © - 2021, https://www.hanssonit.se/
# Copyright © 2021 Simon Lindner (https://github.com/szaimen)

true
SCRIPT_NAME="System Restore"
SCRIPT_EXPLAINER="This script let's you restore your system- and boot-partition to a previous state."
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
    msg_box "It seems like you haven't setup daily borg backups.
Please do that before you can view backups."
    exit 1
fi
# Get needed variables
ENCRYPTION_KEY="$(grep "ENCRYPTION_KEY=" "$DAILY_BACKUP_FILE" | sed 's|.*ENCRYPTION_KEY="||;s|"||')"
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
Please try again later."
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
    exit 1
fi

# View backup repository menu
args=(whiptail --title "$TITLE" --menu \
"Please select the backup repository that you want to view.
$MENU_GUIDE" "$WT_HEIGHT" "$WT_WIDTH" 4)

# Check if at least one drive is connected
DAILY=1
if ! [ -d "$DAILY_BACKUP_TARGET" ]
then
    mount "$DAILY_BACKUP_MOUNTPOINT"
    if ! [ -d "$DAILY_BACKUP_TARGET" ]
    then
        DAILY=""
    fi
    umount "$DAILY_BACKUP_MOUNTPOINT"
fi
if [ -f "$OFFSHORE_BACKUP_FILE" ]
then
    OFFSHORE=1
    if ! [ -d "$OFFSHORE_BACKUP_TARGET" ]
    then
        mount "$OFFSHORE_BACKUP_MOUNTPOINT"
        if ! [ -d "$OFFSHORE_BACKUP_TARGET" ]
        then
            OFFSHORE=""
        fi
    fi
    umount "$OFFSHORE_BACKUP_MOUNTPOINT"
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

# Check if pending snapshot is existing and cancel the restore process in this case.
if does_snapshot_exist "NcVM-snapshot-pending"
then
    msg_box "The snapshot pending does exist. Can currently not restore the backup.
Please try again later."
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

# Find available archives
ALL_ARCHIVES=$(borg list "$BACKUP_TARGET_DIRECTORY")
SYSTEM_ARCHIVES=$(echo "$ALL_ARCHIVES" | grep "NcVM-system-partition" | awk -F "-" '{print $1}' | sort -r)
mapfile -t SYSTEM_ARCHIVES <<< "$SYSTEM_ARCHIVES"
BOOT_ARCHIVES=$(echo "$ALL_ARCHIVES" | grep "NcVM-boot-partition" | awk -F "-" '{print $1}')
mapfile -t BOOT_ARCHIVES <<< "$BOOT_ARCHIVES"
for system_archive in "${SYSTEM_ARCHIVES[@]}"
do
    for boot_archive in "${BOOT_ARCHIVES[@]}"
    do
        if [ "$system_archive" = "$boot_archive" ]
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
msg_box "We will now check if extracting works and perform a dry-run of restoring the backup.
(which means that no files/folders will get modified during this step).
Checking the extracting can take a very long time, though."
if yesno_box_yes "Do you want to check if extracting works?
You can skip the extracting check by selecting 'No'. 
The dry-run of restoring the backup will run always. (No files/folders will get modified.) 
It is recommended to select 'Yes' to run the extracting check."
then
    EXTRACT_CHECK=1
fi
msg_box "Please wait until you see the next menu!
You will have the chance to cancel the restore process afterwards.\n
Otherwise you can cancel always by pressing '[CTRL] + [C]'"

# Verify integrity of selected archives
if [ -n "$EXTRACT_CHECK" ]
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
fi

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
        restore_original_state
        exit 1
    fi
done

# Exclude some dirs; mnt, media, sys, prob don't need to be excluded because of the usage of --one-file-system flag
EXCLUDED_DIRECTORIES=(home/*/.cache root/.cache root/.config/borg var/cache \
lost+found run var/run tmp var/tmp etc/lvm/archive snap)
for directory in "${EXCLUDED_DIRECTORIES[@]}"
do
    EXCLUDE_DIRS+=(--exclude="/$directory/")
done

# Dry run of everything
print_text_in_color "$ICyan" "Performing a dry-run before restoring. Please be patient!"
if ! rsync --archive --human-readable --dry-run --verbose --delete /tmp/borgboot/boot/ /boot \
| tee /tmp/dry-run.out
then
    msg_box "Something failed while performing the boot-partition dry-run."
    umount /tmp/borgsystem
    umount /tmp/borgboot
    restore_original_state
    exit 1
fi
sed -i -r '/^[a-zA-Z0-9]+\//s/^/boot\//' /tmp/dry-run.out
if ! rsync --archive --verbose --human-readable \
--dry-run --delete --one-file-system --stats "${EXCLUDE_DIRS[@]}" /tmp/borgsystem/system/ / \
| tee -a /tmp/dry-run.out
then
    msg_box "Something failed while performing the system-partition dry-run."
    umount /tmp/borgsystem
    umount /tmp/borgboot
    restore_original_state
    exit 1
fi

# Prepare output
OUTPUT=$(cat /tmp/dry-run.out)
OUTPUT=$(echo "$OUTPUT" | sed -r '/^[a-zA-Z0-9]+\//s/^/changing or creating /')
DELETED_FILES=$(echo "$OUTPUT" | grep "^deleting " | grep -v "/$" | sort)
DELETED_FOLDERS=$(echo "$OUTPUT" | grep "^deleting .*/$" | sort)
CHANGED_FILES=$(echo "$OUTPUT" | grep "^changing or creating " | grep -v "/$" | sort)
CHANGED_FOLDERS=$(echo "$OUTPUT" | grep "^changing or creating .*/$" | sort)
STATS=$(echo "$OUTPUT" | grep -v "^access.log\|error.log\|\./\|^deleting \|^changing or creating ")

# Show output
msg_box "Here are the stats from the dry-run:\n$STATS\n\n" "STATS"
while :
do
    choice=$(whiptail --title "$TITLE" --menu \
"The dry-run was successful.
You can get further information about the dry-run by selecting an option.
If you get directly redirected to this Menu after selecting an option, \
the list is most likely too long to be shown.\n
$MENU_GUIDE" "$WT_HEIGHT" "$WT_WIDTH" 4 \
"Continue" "(Continue with the process)" \
"Deleted Files" "(Show files that will get deleted)" \
"Deleted Folders" "(Show folders that will get deleted)" \
"Changed/created Files" "(Show files that will get changed or created)" \
"Changed/created Folders" "(Show folders that will get changed or created)" 3>&1 1>&2 2>&3)

    case "$choice" in
        "Continue")
            break
        ;;
        "Deleted Files")
            msg_box "Those files will get deleted:\n$DELETED_FILES" "Deleted Files"
        ;;
        "Deleted Folders")
            msg_box "Those folders will get deleted:\n$DELETED_FOLDERS" "Deleted Folders"
        ;;
        "Changed/created Files")
            msg_box "Those files will get changed/created:\n$CHANGED_FILES" "Changed/created Files" 
        ;;
        "Changed/created Folders")
            msg_box "Those folders will get changed/created:\n$CHANGED_FOLDERS" "Changed/created Folders"
        ;;
        "")
            break
        ;;
        *)
        ;;
    esac
done

# Inform user
msg_box "Here are the stats from the dry-run again:\n$STATS\n\n" "STATS"
if ! yesno_box_no "Are you sure that you want to restore your system to this state?"
then
    umount /tmp/borgsystem
    umount /tmp/borgboot
    restore_original_state
    exit 1
fi

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
--progress "${EXCLUDE_DIRS[@]}" /tmp/borgsystem/system/ /
then
    msg_box "Something failed while restoring the system partition."
    umount /tmp/borgsystem
    umount /tmp/borgboot
    restore_original_state
    exit 1
fi

# Restore the boot partition
if ! rsync --archive --human-readable --progress --delete /tmp/borgboot/boot/ /boot
then
    msg_box "Something failed while restoring the boot partition."
    umount /tmp/borgsystem
    umount /tmp/borgboot
    restore_original_state
    exit 1
fi

# Start services
print_text_in_color "$ICyan" "Starting services..."
systemctl start postgresql
nextcloud_occ_no_check maintenance:mode --off
start_if_stopped docker

# Restore original state
umount /tmp/borgsystem
umount /tmp/borgboot
restore_original_state

# Allow to reboot: recommended
msg_box "Congratulations, the restore was successful!\n
It is highly recommended to reboot your server now."
if yesno_box_yes "Do you want to reboot now?"
then
    reboot
fi

exit
