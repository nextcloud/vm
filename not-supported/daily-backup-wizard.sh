#!/bin/bash

# T&M Hansson IT AB © - 2024, https://www.hanssonit.se/
# Copyright © 2021 Simon Lindner (https://github.com/szaimen)

true
SCRIPT_NAME="Daily Backup Wizard"
SCRIPT_EXPLAINER="This script helps creating a daily backup script for your server."
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
BACKUP_SCRIPT_NAME="$SCRIPTS/daily-borg-backup.sh"

# Functions
mount_if_connected() {
    umount "$1" &>/dev/null
    mount "$1" &>/dev/null
    if ! mountpoint -q "$1"
    then
        return 1
    fi
    return 0
}
get_backup_mounts() {
    BACKUP_MOUNTS=""
    BACKUP_MOUNTS="$(grep "ntfs-3g" /etc/fstab | grep "windows_names" | grep "uid=root" \
| grep "gid=root" | grep "umask=177" | grep "noauto" | awk '{print $2}')"
    BACKUP_MOUNTS+="\n"
    BACKUP_MOUNTS+="$(grep cifs /etc/fstab | grep "uid=root" | grep "gid=root" \
| grep "file_mode=0600" | grep "dir_mode=0600" | grep "noauto" | awk '{print $2}')"
    BACKUP_MOUNTS+="\n"
    BACKUP_MOUNTS+="$(grep btrfs /etc/fstab | grep ",noauto" | awk '{print $2}')"
}

# Ask for execution
msg_box "$SCRIPT_EXPLAINER"
if ! yesno_box_yes "Do you want to create a daily backup script?"
then
    exit
fi

# Before starting check if the requirements are met
if [ -f "$BACKUP_SCRIPT_NAME" ]
then
    msg_box "The daily backup script already exists. 
Please rename or delete $BACKUP_SCRIPT_NAME if you want to reconfigure the backup."
    exit 1
fi
# Check if pending snapshot is existing and cancel the setup in this case.
if does_snapshot_exist "NcVM-startup"
then
    # Cannot get executed during the startup script
    if [ -f "$SCRIPTS/nextcloud-startup-script.sh" ]
    then
        msg_box "The daily backup cannot get configured during the startup script.
Please try again after it is finished by running: 
'sudo bash $SCRIPTS/menu.sh' -> 'Server Configuration' -> 'Daily Backup Wizard'."
        exit
    fi
    msg_box "You need to run the update script once before you can continue with creating the backup script."
    if yesno_box_yes "Do you want to do this now?"
    then
        bash "$SCRIPTS"/update.sh minor
    else
        exit 1
    fi
    if does_snapshot_exist "NcVM-startup"
    then
        msg_box "It seems like the statup script wasn't correctly removed. Cannot proceed."
        exit 1
    fi
fi
if does_snapshot_exist "NcVM-snapshot-pending"
then
    msg_box "It seems to be currently running a backup or update.
Cannot set up the daily backup now. Please try again later.\n
If you are sure that no update or backup is currently running, you can fix this by rebooting your server."
    exit 1
fi

# Check if snapshot/free space exists
check_free_space
if ! does_snapshot_exist "NcVM-snapshot" && ! [ "$FREE_SPACE" -ge 50 ]
then
    msg_box "Unfortunately you have not enough free space on your vgs to \
create a LVM-snapshot which is a requirement to create a backup script.

If you are running the script in a VM and not on barebones, you can increase your root partition manually by following these steps:
1. Shut down the VM and create a snapshot/copy of it (in order to be able to restore the current state)
2. Now increase the size of the virtual disk1 in your hypervisor by at least 5 GB (e.g. in VMWare Virtualplayer)
3. Power the VM back on
4. Log in via SSH and run the following command: 
'sudo pvresize \$(sudo pvs | grep ubuntu-vg | grep -oP \"/dev/sda[0-9]\")'
5. Now you can run this script again:
'sudo bash $SCRIPTS/menu.sh' -> 'Server Configuration' -> 'Daily Backup Wizard'"
    exit 1
fi

# Check if backup drives existing
get_backup_mounts
if [ "$BACKUP_MOUNTS" = "\n\n" ]
then
    msg_box "No backup mount found that can be used as daily backup target.
Please mount one with the SMB Mount script from the Additional Apps Menu \
or with the BTRFS Mount script or NTFS Mount script from the Not-Supported Menu."
    if yesno_box_yes "Do you want to mount a SMB-share that can be used as backup target with the SMB Mount script?
(This requires a SMB-server in your network.)"
    then
        run_script APP smbmount
    else
        exit 1
    fi
    get_backup_mounts
    if [ "$BACKUP_MOUNTS" = "\n\n" ]
    then
        msg_box "Still haven't found any backup mount that can be used as daily backup target. Cannot proceed!"
        exit 1
    fi
fi
BACKUP_MOUNTS="$(echo -e "$BACKUP_MOUNTS")"
mapfile -t BACKUP_MOUNTS <<< "$BACKUP_MOUNTS"
for drive in "${BACKUP_MOUNTS[@]}"
do
    if ! mount_if_connected "$drive"
    then
        continue
    fi
    BACKUP_DRIVES+=("$drive")
    umount "$drive"
done
if [ -z "${BACKUP_DRIVES[*]}" ]
then
    msg_box "No backup drive found that is currently connected.
Please connect it to your server before you can continue."
    exit 1
else
    msg_box "At least one backup mount found. Please leave it connected."
fi
# Check if /mnt/ncdata is mounted
if grep -q " /mnt/ncdata " /etc/mtab && ! grep " /mnt/ncdata " /etc/mtab | grep -q zfs
then
    msg_box "The '/mnt/ncdata' directory is mounted and not existing on the root drive.
This is currently not supported."
    exit 1
fi
# The same with the /home directory
if grep -q " /home " /etc/mtab
then
    msg_box "The '/home' directory is mounted and not existing on the root drive.
This is currently not supported."
    exit 1
fi
# Test sending of mails
if ! send_mail "Testmail" \
"This is a testmail to test if the server can send mails which is needed for the 'Daily Backup Wizard'."
then
    msg_box "The server is not configured to send mails."
    if yesno_box_yes "Do you want to do this now?"
    then
        run_script ADDONS smtp-mail
    else
        exit 1
    fi
    if ! send_mail "Testmail" \
"This is a testmail to test if the server can send mails which is needed for the 'Daily Backup Wizard'."
    then
        msg_box "The server still cannot send mails. Cannot proceed!"
        exit 1
    fi
fi

# Drive Menu
args=(whiptail --title "$TITLE" --separate-output --checklist \
"Please select the drives/mountpoints that you want to backup.
Always included is a full system backup (aka '/') and the '/mnt/ncdata' directory/drive.
$CHECKLIST_GUIDE" "$WT_HEIGHT" "$WT_WIDTH" 4)

# Get mountpoints
DRIVE_MOUNTS=$(find /mnt/ -mindepth 1 -maxdepth 2 -type d | grep -v "/mnt/ncdata")
mapfile -t DRIVE_MOUNTS <<< "$DRIVE_MOUNTS"

# Check if drives are connected
if [ -n "${DRIVE_MOUNTS[*]}" ]
then
    for mountpoint in "${DRIVE_MOUNTS[@]}"
    do
        if mountpoint -q "$mountpoint" && [ "$(stat -c '%a' "$mountpoint")" = "770" ] \
&& [ "$(stat -c '%U' "$mountpoint")" = "www-data" ] && [ "$(stat -c '%G' "$mountpoint")" = "www-data" ]
        then
            args+=("$mountpoint" "" OFF)
            RESULTS+="$mountpoint"
        fi
    done

    # Only show menu if at least one additional drive is connected
    if [ -n "$RESULTS" ]
    then
        selected_options=$("${args[@]}" 3>&1 1>&2 2>&3)
    else
        msg_box "No connected drive found that can get backed up.
Always included is a full system backup (aka '/') and the '/mnt/ncdata' directory/drive."
    fi

    # Let the user select directories on the found drives
    if [ -n "$selected_options" ]
    then
        mapfile -t SELECTED_DRIVES <<< "$selected_options"
        for mountpoint in "${SELECTED_DRIVES[@]}"
        do
            if yesno_box_yes "Do you want to backup the whole drive that is mounted at '$mountpoint'?"
            then
                ADDITIONAL_BACKUP_DIRECTORIES+=("$mountpoint")
                continue
            fi
            DIRECTORIES=$(find "$mountpoint" -maxdepth 2 -type d | grep "$mountpoint/")
            while :
            do
                msg_box "Those are existing directories on that drive. Please remember one.\n\n$mountpoint/\n$DIRECTORIES"
                SELECTION=$(input_box_flow "Please type in one \
directory that you would like to backup on this drive '$mountpoint'.
If you want to cancel, just type in 'exit' and press [ENTER].")
                if [ "$SELECTION" = "exit" ]
                then
                    exit 1
                elif ! echo "$SELECTION" | grep -q "^$mountpoint/"
                then
                    msg_box "It has to be a directory in '$mountpoint'. Please try again."
                elif ! [ -d "$SELECTION" ]
                then
                    msg_box "The directory doesn't exist. Please try again."
                else
                    ADDITIONAL_BACKUP_DIRECTORIES+=("$SELECTION")
                    break
                fi
            done
        done
    fi
fi

# Backup drive menu
args=(whiptail --title "$TITLE" --menu \
"Please select the backup drive that you want to use.
$MENU_GUIDE" "$WT_HEIGHT" "$WT_WIDTH" 4)

# Get all backup drives
for drive in "${BACKUP_DRIVES[@]}"
do
    if ! mount_if_connected "$drive"
    then
        continue
    fi
    args+=("$drive" "")
    CONNECTED_DRIVES+="$drive"
    umount "$drive"
done

# Show backup drive menu
if [ -n "$CONNECTED_DRIVES" ]
then
    selected_options=$("${args[@]}" 3>&1 1>&2 2>&3)
else
    msg_box "No backup drive connected.
Hence, unable to continue."
    exit 1
fi

# Cancel if nothing chosen
if [ -z "$selected_options" ]
then
    msg_box "No backup drive chosen. Hence exiting."
    exit 1
else
    BACKUP_TARGET_DIRECTORY="${selected_options%%/}"
    # Mount the backup drive
    check_command mount "$BACKUP_TARGET_DIRECTORY"
    BACKUP_MOUNT="$BACKUP_TARGET_DIRECTORY"
fi

# Ask if default directory shall get used
if yesno_box_yes "Do you want to use the recommended backup directory which is:
'$BACKUP_TARGET_DIRECTORY/borgbackup/NcVM'?"
then
    if [ -d "$BACKUP_TARGET_DIRECTORY/borgbackup/NcVM" ] && ! rm -d "$BACKUP_TARGET_DIRECTORY/borgbackup/NcVM" &>/dev/null
    then
        msg_box "The directory '$BACKUP_TARGET_DIRECTORY/borgbackup/NcVM' exists and cannot be used.
Please choose a custom one."
        CUSTOM_DIRECTORY=1
    else
        BACKUP_TARGET_DIRECTORY="$BACKUP_TARGET_DIRECTORY/borgbackup/NcVM"
    fi
else
    CUSTOM_DIRECTORY=1
fi

# Choose custom backup directory
if [ -n "$CUSTOM_DIRECTORY" ]
then
    while :
    do
        SELECTED_DIRECTORY=$(input_box_flow "Please type in the directory that you want to use as backup directory.
It has to start with '$BACKUP_TARGET_DIRECTORY/'.
Recommended is '$BACKUP_TARGET_DIRECTORY/borgbackup/NcVM'
If you want to cancel, just type in 'exit' and press [ENTER].")
        if [ "$SELECTED_DIRECTORY" = "exit" ]
        then
            exit 1
        elif echo "$SELECTED_DIRECTORY" | grep -q " "
        then
            msg_box "Please don't use spaces."
        elif ! echo "$SELECTED_DIRECTORY" | grep -q "^$BACKUP_TARGET_DIRECTORY/"
        then
            msg_box "The backup directory has to start with '$BACKUP_TARGET_DIRECTORY/'. Please try again."
        elif [ -d "$SELECTED_DIRECTORY" ] && ! rm -d "$SELECTED_DIRECTORY" &>/dev/null
        then
            msg_box "This directory already exists. Please try again."
        else
            if ! mkdir -p "$SELECTED_DIRECTORY"
            then
                msg_box "Couldn't create the directory. Please try again."
                rm -d "$SELECTED_DIRECTORY" &>/dev/null
            else
                rm -d "$SELECTED_DIRECTORY" &>/dev/null
                BACKUP_TARGET_DIRECTORY="$SELECTED_DIRECTORY"
                break
            fi
        fi
    done
fi

# Ask for an Encryption key
while :
do
    ENCRYPTION_KEY=$(input_box_flow "Please enter the encryption key that shall get used for Borg backups.
Please remember to store this key at a save place. You will not be able to restore your backup if you lose the key.
If you want to cancel, just type in 'exit' and press [ENTER].")
    if [ "$ENCRYPTION_KEY" = "exit" ]
    then
        exit 1
    elif yesno_box_no "Have you saved the encryption key for your backup?"
    then
        break
    fi
done

# Ask when the daily backup shall run
if yesno_box_yes "Do you want to run the daily backup at the recommended time 4.00 am?"
then
    BACKUP_TIME="00 04"
else
    while :
    do
        BACKUP_TIME=$(input_box_flow "Please enter the time when the backup shall get executed daily in this format:
'mm hh' (minutes first, hours second)
Recommended is: '00 04' (Backups will be executed at 4.00 am)
Please enter it in 24h format. (No am and pm).
If you want to cancel, just type in 'exit' and press [ENTER].")
        if [ "$BACKUP_TIME" = "exit" ]
        then
            exit 1
        elif ! echo "$BACKUP_TIME" | grep -q "^[0-5][0-9] [0-1][0-9]$" && ! echo "$BACKUP_TIME" | grep -q "^[0-5][0-9] 2[0-3]$"
        then
            msg_box "Please enter the time in this format:
'mm hh' (minutes first, hours second)
Recommended is: '00 04' (Backups will be executed at 4.00 am)"
        else
            break
        fi
    done
fi

# Install needed tools
msg_box "We will now install all needed tools, initialize the Borg backup repository and create the daily backup script now."
install_if_not borgbackup
apt-get install python3-pyfuse3 --no-install-recommends -y

# Initialize the borg backup repository
export BORG_PASSPHRASE="$ENCRYPTION_KEY"
mkdir -p "$BACKUP_TARGET_DIRECTORY"
check_command borg init --encryption=repokey-blake2 "$BACKUP_TARGET_DIRECTORY"
borg config "$BACKUP_TARGET_DIRECTORY" additional_free_space 2G
unset BORG_PASSPHRASE

# Fix too large Borg cache
# https://borgbackup.readthedocs.io/en/stable/faq.html#the-borg-cache-eats-way-too-much-disk-space-what-can-i-do
BORG_ID="$(borg config "$BACKUP_TARGET_DIRECTORY" id)"
check_command rm -r "/root/.cache/borg/$BORG_ID/chunks.archive.d"
check_command touch "/root/.cache/borg/$BORG_ID/chunks.archive.d"

# Make a backup from the borg config file
if ! [ -f "$BACKUP_TARGET_DIRECTORY/config" ]
then
    msg_box "The borg config file wasn't created. Something is wrong."
    exit 1
else
    if ! send_mail "Your daily backup config file! Please save/archive it!" "$(cat "$BACKUP_TARGET_DIRECTORY/config")"
    then
        msg_box "Could not send the daily backup config file. This is wrong."
        exit 1
    fi
fi

# Unmount the backup drive
check_command umount "$BACKUP_MOUNT"

# Write beginning of the script
cat << WRITE_BACKUP_SCRIPT > "$BACKUP_SCRIPT_NAME"
#!/bin/bash

# T&M Hansson IT AB © - 2024, https://www.hanssonit.se/
# Copyright © 2021 Simon Lindner (https://github.com/szaimen)

true
SCRIPT_NAME="Daily Borg Backup"
SCRIPT_EXPLAINER="This script executes the daily Borg backup."
# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Check if root
root_check

# Export Variables
export ENCRYPTION_KEY='$ENCRYPTION_KEY'
export BACKUP_TARGET_DIRECTORY="$BACKUP_TARGET_DIRECTORY"
export BACKUP_MOUNTPOINT="$BACKUP_MOUNT"
export BORGBACKUP_LOG="$VMLOGS/borgbackup.log"
export CHECK_BACKUP_INTERVAL_DAYS=14
export DAYS_SINCE_LAST_BACKUP_CHECK=14
WRITE_BACKUP_SCRIPT
unset ENCRYPTION_KEY

# Secure the file
chown root:root "$BACKUP_SCRIPT_NAME"
chmod 700 "$BACKUP_SCRIPT_NAME"

# Add a variable for enabling/disabling btrfs scrub for the backup drive
if grep "$BACKUP_MOUNT" /etc/fstab | grep -q btrfs
then
    echo 'export BTRFS_SCRUB_BACKUP_DRIVE="yes"' >> "$BACKUP_SCRIPT_NAME"
fi

# Write additional backup sources to the script
SOURCES='export ADDITIONAL_BACKUP_DIRECTORIES="'
for source in "${ADDITIONAL_BACKUP_DIRECTORIES[@]}"
do
    SOURCES+="$source\n"
done
SOURCES="${SOURCES%%\\n}"
SOURCES+='"'
echo -e "$SOURCES" >> "$BACKUP_SCRIPT_NAME"

# Write end of the script
cat << WRITE_BACKUP_SCRIPT >> "$BACKUP_SCRIPT_NAME"

# Execute backup
if network_ok
then
    echo "Executing \$SCRIPT_NAME. \$(date +%Y-%m-%d_%H-%M-%S)" >> "\$BORGBACKUP_LOG"
    run_script NOT_SUPPORTED_FOLDER borgbackup
else
    echo "Unable to execute \$SCRIPT_NAME. No network connection. \$(date +%Y-%m-%d_%H-%M-%S)" >> "\$BORGBACKUP_LOG"
    notify_admin_gui "Unable to execute \$SCRIPT_NAME." "No network connection."
fi
WRITE_BACKUP_SCRIPT

# Create fstab entry
crontab -u root -l | grep -v "$BACKUP_SCRIPT_NAME"  | crontab -u root -
crontab -u root -l | { cat; echo "$BACKUP_TIME * * * $BACKUP_SCRIPT_NAME > /dev/null 2>&1" ; } | crontab -u root -

# Inform user
msg_box "The Borg backup script was successfully created!
It is located here: '$BACKUP_SCRIPT_NAME'\n
The first backup will run automatically at your chosen time."

exit
