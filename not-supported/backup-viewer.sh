#!/bin/bash

# T&M Hansson IT AB © - 2024, https://www.hanssonit.se/
# Copyright © 2021 Simon Lindner (https://github.com/szaimen)

true
SCRIPT_NAME="Backup Viewer"
SCRIPT_EXPLAINER="This script shows the content of daily and/or off-shore backups."
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

# Ask for execution
msg_box "$SCRIPT_EXPLAINER"
if ! yesno_box_yes "Do you want to view the content of your backups?"
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

# Select your way of showing the backups
choice=$(whiptail --title "$TITLE" --menu \
"Which way do you prefer of showing your backups?
$MENU_GUIDE" "$WT_HEIGHT" "$WT_WIDTH" 4 \
"Midnight Commander" "(Only for viewing your backups, no easy way to copy and move files)" \
"Webmin" "(Copy and move files via webpage but has bad mimetype support)" \
"Remotedesktop" "(Best way to copy and move files but needs xrdp to be installed)" 3>&1 1>&2 2>&3)

case "$choice" in
    "Midnight Commander")
        if ! is_this_installed mc
        then
            msg_box "It seems like Midnight Commander isn't installed, yet."
            if yesno_box_yes "Do you want to install it now?"
            then
                run_script APP midnight-commander
            else
                exit 1
            fi
            if ! is_this_installed mc
            then
                msg_box "It seems like Midnight Commander stil isn't installed. Cannot proceed!"
                exit 1
            fi
        fi
    ;;
    "Webmin")
        if ! is_this_installed webmin
        then
            msg_box "It seems like Webmin isn't installed, yet."
            if yesno_box_yes "Do you want to install it now?"
            then
                run_script APP webmin
            else
                exit 1
            fi
            if ! is_this_installed webmin
            then
                msg_box "It seems like Webmin stil isn't installed. Cannot proceed!"
                exit 1
            fi
        fi
    ;;
    "Remotedesktop")
        if ! is_this_installed xrdp
        then
            msg_box "It seems like Remotedesktop isn't installed, yet.
You need to install it on your server before you can use it.
To do that, you need to manually download and execute the following script on your server:
$NOT_SUPPORTED_FOLDER/remotedesktop.sh"
            exit 1
        fi
    ;;
    "")
        msg_box "No option chosen. Exiting!"
        exit 1
    ;;
    *)
    ;;
esac

# Safe the choice in a new variable
PROGRAM_CHOICE="$choice"

# View backup repository menu
args=(whiptail --title "$TITLE" --menu \
"Please select the backup repository that you want to view.
$MENU_GUIDE" "$WT_HEIGHT" "$WT_WIDTH" 4)

print_text_in_color "$ICyan" "Looking for connected Backup drives. This can take a while..."

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

# Check if pending snapshot is existing a second time and cancel the viewing in this case.
if does_snapshot_exist "NcVM-snapshot-pending"
then
    msg_box "The snapshot pending does exist. Can currently not show the backup.
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

# Find out which one was mounted
if [ "$choice" = "$DAILY_BACKUP_TARGET" ]
then
    BACKUP_MOUNTPOINT="$DAILY_BACKUP_MOUNTPOINT"
elif [ "$choice" = "$OFFSHORE_BACKUP_TARGET" ]
then
    BACKUP_MOUNTPOINT="$OFFSHORE_BACKUP_MOUNTPOINT"
    # Work around issue with borg
    # https://github.com/borgbackup/borg/issues/3428#issuecomment-380399036
    mv /root/.config/borg/security/ /root/.config/borg/security.bak
    mv /root/.cache/borg/ /root/.cache/borg.bak
fi

# Mount the drive
mount "$BACKUP_MOUNTPOINT"

# Break the borg lock if it exists because we have the snapshot that prevents such situations
if [ -f "$BACKUP_TARGET_DIRECTORY/lock.roster" ]
then
    print_text_in_color "$ICyan" "Breaking the borg lock..."
    borg break-lock "$BACKUP_TARGET_DIRECTORY"
fi

# Mount the repository
export BORG_PASSPHRASE="$ENCRYPTION_KEY"
mkdir -p /tmp/borg
borg mount "$choice" /tmp/borg
unset BORG_PASSPHRASE
unset ENCRYPTION_KEY

case "$PROGRAM_CHOICE" in
    "Midnight Commander")
        while :
        do
            msg_box "We will now open Midnight Commander so that you can view the content of your backup repository.\n
Please remember a few things for Midnight Commander:
1. You can simply navigate with the [ARROW] keys and [ENTER]
2. When you are done, please close Midnight Commander completely by pressing [F10]. \
Otherwise we will not be able to unmount the backup repository again and there will \
most likely be problems during the next regular backup."
            if yesno_box_no "Do you remember all two points?"
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
        # Show Midnight commander
        mc /tmp/borg

        # Revert panel settings to MC
        echo "" > "/root/.config/mc/panels.ini"
    ;;
    "Webmin")
        msg_box "For showing your backups with Webmin, you should be able to access them by visiting in a Browser:
https://$ADDRESS:10000/filemin/index.cgi?path=/tmp/borg \n
If you haven't been logged in to Webmin, yet, you might need to log in first and open the link after you've done that.\n
After you are done, just press [ENTER] here to unmount the backup again."
    ;;
    "Remotedesktop")
        msg_box "For showing your backups with Remotedesktop, you need to connect to your server using an RDP client.
After you are connected, open a terminal in the session and execute the following command \
which should open the file manager with the correct location:\n
xhost +si:localuser:root && sudo nautilus /tmp/borg \n
After you are done, just press [ENTER] here to unmount the backup again."
    ;;
    *)
    ;;
esac

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

# Unmount borg backup
if ! umount /tmp/borg
then
    msg_box "Could not unmount the backup archives."
fi

# Unmount the backup drive
sleep 1
if ! umount "$BACKUP_MOUNTPOINT"
then
    msg_box "Could not unmount the backup drive."
    exit 1
fi

# End message
msg_box "Just unmounted the backup repository and drive again."

# Adjust permissions
if [ -f "$SCRIPTS/adjust-startup-permissions.sh" ]
then
    nohup bash "$SCRIPTS/adjust-startup-permissions.sh" &>/dev/null &
fi
