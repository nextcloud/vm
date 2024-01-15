#!/bin/bash

# T&M Hansson IT AB © - 2024, https://www.hanssonit.se/
# Copyright © 2021 Simon Lindner (https://github.com/szaimen)

true
SCRIPT_NAME="Off-Shore Backup Wizard"
SCRIPT_EXPLAINER="This script helps creating an off-shore backup script for your server."
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
BACKUP_SCRIPT_NAME="$SCRIPTS/off-shore-rsync-backup.sh"
DAILY_BACKUP_FILE="$SCRIPTS/daily-borg-backup.sh"

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

# Ask for execution
msg_box "$SCRIPT_EXPLAINER"
if ! yesno_box_yes "Do you want to create an off-shore backup script?"
then
    exit
fi

# Before starting check if the requirements are met
if [ -f "$BACKUP_SCRIPT_NAME" ]
then
    msg_box "The off-shore backup script already exists. 
Please rename or delete $BACKUP_SCRIPT_NAME if you want to reconfigure the backup."
    exit 1
fi
# Before starting check if the requirements are met
if ! [ -f "$DAILY_BACKUP_FILE" ]
then
    msg_box "The daily backup doesn't exist. 
Please create the daily backup script first by running the 'Daily Backup Wizard' from the 'Not-Supported Menu'"
    exit 1
fi
# Check if pending snapshot is existing and cancel the setup in this case.
if does_snapshot_exist "NcVM-snapshot-pending"
then
    msg_box "It seems to be currently running a backup or update.
Cannot set up the off-shore backup now. Please try again later.\n
If you are sure that no update or backup is currently running, you can fix this by rebooting your server."
    exit 1
elif does_snapshot_exist "NcVM-startup"
then
    msg_box "Please run the update script once before you can continue."
    exit 1
fi
# Check if snapshot/free space exists
check_free_space
if ! does_snapshot_exist "NcVM-snapshot" && ! [ "$FREE_SPACE" -ge 50 ]
then
    msg_box "Unfortunately you have not enough free space on your vgs to \
create a LVM-snapshot which is a requirement to create a backup script."
    exit 1
fi
# Get backup mountpoint from daily-borg-backup.sh
DAILY_BACKUP_MOUNTPOINT="$(grep "BACKUP_MOUNTPOINT=" "$DAILY_BACKUP_FILE" | sed 's|.*BACKUP_MOUNTPOINT="||;s|"$||')"
DAILY_BACKUP_TARGET="$(grep "BACKUP_TARGET_DIRECTORY=" "$DAILY_BACKUP_FILE" | sed 's|.*BACKUP_TARGET_DIRECTORY="||;s|"$||')"
DAILY_BACKUP_DIFFERENCE="${DAILY_BACKUP_TARGET##"$DAILY_BACKUP_MOUNTPOINT"}"
if [ -z "$DAILY_BACKUP_MOUNTPOINT" ] || [ -z "$DAILY_BACKUP_TARGET" ] || [ -z "$DAILY_BACKUP_DIFFERENCE" ]
then
    msg_box "One needed variable from daily-borg-backup.sh is empty.
This is false."
    exit 1
fi
if [ "$DAILY_BACKUP_MOUNTPOINT" = "$DAILY_BACKUP_TARGET" ]
then
    msg_box "Daily backup mountpoint and target are the same which is wrong."
    exit 1
fi
if ! grep -q " $DAILY_BACKUP_MOUNTPOINT " /etc/fstab
then
    msg_box "Couldn't find the daily backup drive in fstab. This is wrong."
    exit 1
fi
# Check if backup drives existing
BACKUP_MOUNTS="$(grep "ntfs-3g" /etc/fstab | grep "windows_names" | grep "uid=root" \
| grep "gid=root" | grep "umask=177" | grep "noauto" | awk '{print $2}')"
BACKUP_MOUNTS+="\n"
BACKUP_MOUNTS+="$(grep cifs /etc/fstab | grep "uid=root" | grep "gid=root" \
| grep "file_mode=0600" | grep "dir_mode=0600" | grep "noauto" | awk '{print $2}')"
BACKUP_MOUNTS+="\n"
BACKUP_MOUNTS+="$(grep btrfs /etc/fstab | grep ",noauto" | awk '{print $2}')"
if [ "$BACKUP_MOUNTS" = "\n\n" ]
then
    msg_box "No backup drive found that can be used as off-shore backup target.
Please mount one with the SMB Mount script from the Additional Apps Menu \
or with the BTRFS Mount script or NTFS Mount script from the Not-Supported Menu."
    exit 1
fi
BACKUP_MOUNTS="$(echo -e "$BACKUP_MOUNTS" | grep -v "$DAILY_BACKUP_MOUNTPOINT")"
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
    msg_box "At least one backup drive found. Please leave it connected."
fi
# Test sending of mails
if ! send_mail "Testmail" \
"This is a testmail to test if the server can send mails which is needed for the 'Off-Shore Backup Wizard'."
then
    msg_box "The server is not configured to send mails.
Please do that first by running the SMTP-Mail script from the Server Configuration Menu."
    exit 1
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
'$BACKUP_TARGET_DIRECTORY$DAILY_BACKUP_DIFFERENCE'?"
then
    if [ -d "$BACKUP_TARGET_DIRECTORY$DAILY_BACKUP_DIFFERENCE" ] && ! rm -d "$BACKUP_TARGET_DIRECTORY$DAILY_BACKUP_DIFFERENCE"
    then
        msg_box "The directory '$BACKUP_TARGET_DIRECTORY$DAILY_BACKUP_DIFFERENCE' exists and cannot be used.
Please choose a custom one."
        CUSTOM_DIRECTORY=1
    else
        BACKUP_TARGET_DIRECTORY="$BACKUP_TARGET_DIRECTORY$DAILY_BACKUP_DIFFERENCE"
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
Recommended is '$BACKUP_TARGET_DIRECTORY$DAILY_BACKUP_DIFFERENCE'
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
        elif [ -d "$SELECTED_DIRECTORY" ] && ! rm -d "$SELECTED_DIRECTORY"
        then
            msg_box "This directory already exists. Please try again."
        else
            if ! mkdir -p "$SELECTED_DIRECTORY"
            then
                msg_box "Couldn't create the directory. Please try again."
                rm -d "$SELECTED_DIRECTORY"
            else
                rm -d "$SELECTED_DIRECTORY"
                BACKUP_TARGET_DIRECTORY="$SELECTED_DIRECTORY"
                break
            fi
        fi
    done
fi

# Create the folder and unmount the backup drive since no longer needed
mkdir -p "$BACKUP_TARGET_DIRECTORY"
check_command umount "$BACKUP_MOUNT"

# Ask when the daily backup shall run
if yesno_box_yes "Do you want to run the off-shore backup every 90 days, which is recommended?"
then
    BACKUP_DAYS="90"
else
    while :
    do
        BACKUP_DAYS=$(input_box_flow "Please enter how many days shall pass until the next off-shore backup shall get created.
Recommended are 90 days.
If you want to cancel, just type in 'exit' and press [ENTER].")
        if [ "$BACKUP_DAYS" = "exit" ]
        then
            exit 1
        elif ! check_if_number "$BACKUP_DAYS"
        then
            msg_box "The value you entered doesn't seem to be a number, please enter a valid number."
        elif ! [ "$BACKUP_DAYS" -gt 1 ]
        then
            msg_box "The number of days has to be at least equal or more than 2 days."
        else
            break
        fi
    done
fi

# Install needed tools
msg_box "We will create the off-shore backup script now."

# Write beginning of the script
cat << WRITE_BACKUP_SCRIPT > "$BACKUP_SCRIPT_NAME"
#!/bin/bash

# T&M Hansson IT AB © - 2024, https://www.hanssonit.se/
# Copyright © 2021 Simon Lindner (https://github.com/szaimen)

true
SCRIPT_NAME="Off-Shore Rsync Backup"
SCRIPT_EXPLAINER="This script executes the off-shore rsync backup."
# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Check if root
root_check

# Local Variables
BACKUP_INTERVAL_DAYS=$BACKUP_DAYS
DAYS_SINCE_LAST_BACKUP=$BACKUP_DAYS

# Export Variables
export BACKUP_TARGET_DIRECTORY="$BACKUP_TARGET_DIRECTORY"
export BACKUP_MOUNTPOINT="$BACKUP_MOUNT"
export RSYNC_BACKUP_LOG="$VMLOGS/rsyncbackup.log"
export BACKUP_SOURCE_MOUNTPOINT="$DAILY_BACKUP_MOUNTPOINT"
export BACKUP_SOURCE_DIRECTORY="$DAILY_BACKUP_TARGET"

# Test if backup shall run
if [ "\$DAYS_SINCE_LAST_BACKUP" -lt "\$BACKUP_INTERVAL_DAYS" ]
then
    DAYS_SINCE_LAST_BACKUP=\$((DAYS_SINCE_LAST_BACKUP+1))
    sed -i "s|^DAYS_SINCE_LAST_BACKUP.*|DAYS_SINCE_LAST_BACKUP=\$DAYS_SINCE_LAST_BACKUP|" "\$BASH_SOURCE"
    echo "Not yet enough days over to make the next off-shore backup \$(date +%Y-%m-%d_%H-%M-%S)" >> "\$RSYNC_BACKUP_LOG"
    print_text_in_color "\$ICyan" "Not yet enough days over to make the next off-shore backup"
    # Test if backup drive is still connected
    umount "\$BACKUP_MOUNTPOINT" &>/dev/null
    mount "\$BACKUP_MOUNTPOINT" &>/dev/null
    if mountpoint -q "\$BACKUP_MOUNTPOINT" && ! grep "\$BACKUP_MOUNTPOINT" /etc/fstab | grep -q " cifs "
    then
        if ! send_mail "Off-shore Backup drive still connected!" \
"It seems like the Off-shore Backup drive ist still connected.
Please disconnect it from your server and store it somewhere safe outside your home!"
        then
            notify_admin_gui "Off-shore Backup drive still connected!" \
"It seems like the Off-shore Backup drive ist still connected.
Please disconnect it from your server and store it somewhere safe outside your home!"
        fi
    fi
    umount "\$BACKUP_MOUNTPOINT" &>/dev/null
    exit
fi

# Execute backup
if network_ok
then
    echo "Executing \$SCRIPT_NAME. \$(date +%Y-%m-%d_%H-%M-%S)" >> "\$RSYNC_BACKUP_LOG"
    run_script NOT_SUPPORTED_FOLDER rsyncbackup
else
    echo "Unable to execute \$SCRIPT_NAME. No network connection. \$(date +%Y-%m-%d_%H-%M-%S)" >> "\$RSYNC_BACKUP_LOG"
    notify_admin_gui "Unable to execute \$SCRIPT_NAME." "No network connection."
fi
WRITE_BACKUP_SCRIPT

# Secure the file
chown root:root "$BACKUP_SCRIPT_NAME"
chmod 700 "$BACKUP_SCRIPT_NAME"

# Create fstab entry
crontab -u root -l | grep -v "$BACKUP_SCRIPT_NAME"  | crontab -u root -
crontab -u root -l | { cat; echo "0 20 * * * $BACKUP_SCRIPT_NAME > /dev/null 2>&1" ; } | crontab -u root -

# Inform user
msg_box "The off-shore backup script was successfully created!
It is located here: '$BACKUP_SCRIPT_NAME'\n
The first backup will run at 20.00h, if the first daily backup has been created until then."

exit
