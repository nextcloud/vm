#!/bin/bash

# T&M Hansson IT AB © - 2020, https://www.hanssonit.se/
# Copyright © 2020 Simon Lindner (https://github.com/szaimen)

true
SCRIPT_NAME="Backup Viewer"
SCRIPT_EXPLAINER="This script shows the content of daily and/or off-shore backups."
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

# Ask for execution
msg_box "$SCRIPT_EXPLAINER"
if ! yesno_box_yes "Do you want to view the content of your backups?"
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
# MC is needed for this
if ! is_this_installed mc
then
    msg_box "For viewing backups we will need Midnight Commander, which is a command line file explorer.
Please install it before you can continue with this script by running:
'sudo bash /var/scripts/menu.sh' choose 'Main Menu => Additional Apps'"
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
# Check if pending snapshot is existing and cancel the vieweing in this case.
if does_snapshot_exist "NcVM-snapshot-pending"
then
    msg_box "The snapshot pending does exist. Can currently not show the backup.
Please try again later."
    exit 1
fi
# Check if startup snapshot is existing and cancel the vieweing in this case.
if does_snapshot_exist "NcVM-startup"
then
    msg_box "The snapshot startup does exist.
Please run the update script first."
    exit 1
fi
# Check if snapshot can get renameds
if ! does_snapshot_exist "NcVM-snapshot"
then
    msg_box "The NcVM-snapshot doesn't exist. This isn't allowed."
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

# Find out which one was mounted
if [ "$choice" = "$DAILY_BACKUP_TARGET" ]
then
    BACKUP_MOUNTPOINT="$DAILY_BACKUP_MOUNTPOINT"
elif [ "$choice" = "$OFFSHORE_BACKUP_TARGET" ]
then
    BACKUP_MOUNTPOINT="$OFFSHORE_BACKUP_MOUNTPOINT"
fi

# Check the mountpoint
if mountpoint -q /tmp/borg
then
    umount /tmp/borg
    if mountpoint -q /tmp/borg
    then
        msg_box "There is still something mounted on /tmp/borg. Cannot proceed."
        exit 1
    fi
fi

# Mount the repository
mount "$BACKUP_MOUNTPOINT"
export BORG_PASSPHRASE="$ENCRYPTION_KEY"
mkdir -p /tmp/borg
if ! borg mount "$choice" /tmp/borg
then
    msg_box "Something failed while mounting the backup repository. Please try again."
    exit 1
fi
unset BORG_PASSPHRASE
unset ENCRYPTION_KEY

# Show last msg_box
while :
do
    msg_box "We will now open Midnight Commander so that you can view the content of your backup repository.\n
Please remember a few things for Midnight Commander:
1. You can simply navigate with the [ARROW] keys and [ENTER]
2. Opening one backup snapshot can take a long time! Please be patient!
3. When you are done, please close Midnight Commander completely by pressing [F10]. \
Otherwise we will not be able to unmount the backup repository again and there will \
most likely be problems during the next regular backup."
    if yesno_box_no "Do you remember all three points?"
    then
        break
    fi
done

# Set the needed settings for mc
mkdir -p "/root/.config/mc"
cat << MC_INI > "/root/.config/mc/panels.ini"
[New Left Panel]
list_format=user
user_format=full name | mtime:15 | size:15 | owner:12 | group:12 | perm:12
MC_INI

# Rename the snapshot to represent that the backup is locked
if ! lvrename /dev/ubuntu-vg/NcVM-snapshot /dev/ubuntu-vg/NcVM-snapshot-pending
then
    msg_box "Could not rename the snapshot. Please reboot your server!"
    exit 1
fi

# Show Midnight commander
if ! mc /tmp/borg
then
    msg_box "Something went wrong while showing MC"
    exit 1
fi

# Unmount borg backup
if ! umount /tmp/borg
then
    msg_box "Could not unmount the backup repository."
    exit 1
fi

# Re-rename the snapshot to represent that it is done
if ! lvrename /dev/ubuntu-vg/NcVM-snapshot-pending /dev/ubuntu-vg/NcVM-snapshot
then
    msg_box "Could not re-rename the snapshot. Please reboot your server!"
    exit 1
fi

# Revert panel settings to MC
echo "" > "/root/.config/mc/panels.ini"

# Unmount the backup drive
sleep 1
if ! umount "$BACKUP_MOUNTPOINT"
then
    msg_box "Something went wrong while unmounting the backup drive."
    exit 1
fi

# End message
msg_box "Just unmounted the backup repository and drive again."
exit