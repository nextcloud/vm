#!/bin/bash

# T&M Hansson IT AB © - 2024, https://www.hanssonit.se/
# Copyright © 2021 Simon Lindner (https://github.com/szaimen)

true
SCRIPT_NAME="NTFS Mount"
SCRIPT_EXPLAINER="This script automates mounting NTFS drives locally in your system."
# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Check if root
root_check

# Show explainer
msg_box "$SCRIPT_EXPLAINER"

# Mount drive
mount_drive() {
local UUIDS
local UUID
local LABEL
msg_box "Please disconnect your drive for now and connect it again AFTER you hit OK.
Otherwise we will not be able to detect it."
CURRENT_DRIVES=$(lsblk -o KNAME,TYPE | grep disk | awk '{print $1}')
count=0
while [ "$count" -lt 60 ]
do
    print_text_in_color "$ICyan" "Please connect your drive now."
    sleep 5 & spinner_loading
    echo ""
    NEW_DRIVES=$(lsblk -o KNAME,TYPE | grep disk | awk '{print $1}')
    if [ "$CURRENT_DRIVES" = "$NEW_DRIVES" ]
    then
        count=$((count+5))
    else
        msg_box "A new drive was found. We will continue with the mounting now.
Please leave it connected."
        break
    fi
done

# Exit if no new drive was found
if [ "$count" -ge 60 ]
then
    msg_box "No new drive found within 60 seconds.
Please run this option again if you want to try again."
    return 1
fi

# Wait until the drive has spin up
countdown "Waiting for the drive to spin up..." 15

# Get all new drives
mapfile -t CURRENT_DRIVES <<< "$CURRENT_DRIVES"
for drive in "${CURRENT_DRIVES[@]}"
do
    NEW_DRIVES=$(echo "$NEW_DRIVES" | grep -v "^$drive$")
done

# Partition menu
args=(whiptail --title "$TITLE" --menu \
"Please select the partition that you would like to mount.
$MENU_GUIDE" "$WT_HEIGHT" "$WT_WIDTH" 4)

# Get information that are important to show the partition menu
mapfile -t NEW_DRIVES <<< "$NEW_DRIVES"
for drive in "${NEW_DRIVES[@]}"
do
    DRIVE_DESCRIPTION=$(lsblk -o NAME,VENDOR,MODEL | grep "^$drive" | awk '{print $2, $3}')
    PARTITION_STATS=$(lsblk -o KNAME,FSTYPE,SIZE,UUID,LABEL | grep "^$drive" | grep -v "^$drive ")
    unset PARTITIONS
    mapfile -t PARTITIONS <<< "$(echo "$PARTITION_STATS" | awk '{print $1}')"
    for partition in "${PARTITIONS[@]}"
    do
        STATS=$(echo "$PARTITION_STATS" | grep "^$partition ")
        FSTYPE=$(echo "$STATS" | awk '{print $2}')
        if [ "$FSTYPE" != "ntfs" ]
        then
            continue
        fi
        SIZE=$(echo "$STATS" | awk '{print $3}')
        UUID=$(echo "$STATS" | awk '{print $4}')
        if [ -z "$UUID" ]
        then
            continue
        fi
        LABEL=$(echo "$STATS" | awk '{print $5,$6,$7,$8,$9,$10,$11,$12}' | sed 's| |_|g' |  sed -r 's|[_]+$||')
        if ! grep -q "$UUID" /etc/fstab
        then
            args+=("$UUID" "$LABEL $DRIVE_DESCRIPTION $SIZE $FSTYPE")
            UUIDS+="$UUID"
        else
            msg_box "The partition
$UUID $LABEL $DRIVE_DESCRIPTION $SIZE $FSTYPE
is already existing.\n
If you want to remove it, run the following two commands:
sudo sed -i '/$UUID/d' /etc/fstab
sudo reboot"
        fi
    done
done

# Check if at least one drive was found
if [ -z "$UUIDS" ] 
then
    msg_box "No drive found that can get mounted.
Most likely none is NTFS formatted."
    return 1
fi

# Show the partition menu
UUID=$("${args[@]}" 3>&1 1>&2 2>&3)
if [ -z "$UUID" ]
then
    return 1
fi

# Get the label of the partition
LABEL=$(lsblk -o UUID,LABEL | grep "^$UUID " | awk '{print $2,$3,$4,$5,$6,$7,$8,$9}' | sed 's| |_|g' |  sed -r 's|[_]+$||')
if [ -z "$LABEL" ]
then
    LABEL="partition-label"
fi

# Create plex user
if ! id plex &>/dev/null
then
    check_command adduser --no-create-home --quiet --disabled-login --force-badname --gecos "" "plex"
fi

# Enter the mountpoint
while :
do
    MOUNT_PATH=$(input_box_flow "Please type in the directory where you want to mount the partition.
One example is: '/mnt/$LABEL'
The directory has to start with '/mnt/'
If you want to cancel, type 'exit' and press [ENTER].")
    if [ "$MOUNT_PATH" = "exit" ]
    then
        exit 1
    elif echo "$MOUNT_PATH" | grep -q " "
    then
        msg_box "Please don't use spaces!"
    elif ! echo "$MOUNT_PATH" | grep -q "^/mnt/"
    then
        msg_box "The directory has to stat with '/mnt/'"
    elif grep -q " $MOUNT_PATH " /etc/fstab
    then
        msg_box "The mountpoint already exists in fstab. Please try a different one."
    elif mountpoint -q "$MOUNT_PATH"
    then
        msg_box "The mountpoint is already mounted. Please try a different one."
    elif echo "$MOUNT_PATH" | grep -q "^/mnt/ncdata"
    then
        msg_box "The directory isn't allowed to start with '/mnt/ncdata'"
    elif echo "$MOUNT_PATH" | grep -q "^/mnt/smbshares"
    then
        msg_box "The directory isn't allowed to start with '/mnt/smbshares'"
    else
        echo "UUID=$UUID $MOUNT_PATH ntfs-3g \
windows_names,uid=plex,gid=plex,umask=007,nofail 0 0" >> /etc/fstab
        mkdir -p "$MOUNT_PATH"
        if ! mount "$MOUNT_PATH"
        then
            msg_box "The mount wasn't successful. Please try again."
            sed -i "/$UUID/d" /etc/fstab
        else
            break
        fi
    fi
done

# Inform the user
msg_box "Congratulations! The mount was successful.
You can now access the partition here:
$MOUNT_PATH"

# Ask if this is a backup drive
if ! yesno_box_no "Is this drive meant to be a backup drive?
If you choose yes, it will only get mounted by a backup script \
and will restrict the read/write permissions to the root user."
then
    # Test if Plex is installed
    if is_docker_running && docker ps -a --format "{{.Names}}" | grep -q "^plex$"
    then
        # Reconfiguring Plex
        msg_box "Plex Media Server found. We are now adjusting Plex to be able to use the new drive.
This can take a while. Please be patient!"
        print_text_in_color "$ICyan" "Downloading the needed tool to get the current Plex config..."
        docker pull assaflavie/runlike
        echo '#/bin/bash' > /tmp/pms-conf
        docker run --rm -v /var/run/docker.sock:/var/run/docker.sock assaflavie/runlike -p plex >> /tmp/pms-conf
        if ! grep -q "$MOUNT_PATH:$MOUNT_PATH:ro" /tmp/pms-conf
        then
            MOUNT_PATH_SED="${MOUNT_PATH//\//\\/}"
            sed -i "0,/--volume/s// -v $MOUNT_PATH_SED:$MOUNT_PATH_SED:ro \\\\\n&/" /tmp/pms-conf
            docker stop plex
            if ! docker rm plex
            then
                msg_box "Something failed while removing the old container."
                return
            fi
            if ! bash /tmp/pms-conf
            then
                msg_box "Starting the new container failed. You can find the config here: '/tmp/pms-conf'"
                return
            fi
            rm /tmp/pms-conf
            msg_box "Plex was adjusted!"
        else
            rm /tmp/pms-conf
            msg_box "No need to update Plex, since the drive is already mounted to Plex."
        fi
    fi
    return
fi

# Execute the change to a backup drive
umount "$MOUNT_PATH"
sed -i "/$UUID/d" /etc/fstab
echo "UUID=$UUID $MOUNT_PATH ntfs-3g windows_names,uid=root,gid=root,umask=177,nofail,noauto 0 0" >> /etc/fstab
msg_box "Your Backup drive is ready."
}

# Show main_menu
while :
do
    choice=$(whiptail --title "$TITLE" --menu \
"Choose what you want to do.
$MENU_GUIDE" "$WT_HEIGHT" "$WT_WIDTH" 4 \
"Mount a drive" "(Interactively mount a NTFS drive)" \
"Exit" "(Exit this script)" 3>&1 1>&2 2>&3)
    case "$choice" in
        "Mount a drive")
            mount_drive
        ;;
        "Exit")
            break
        ;;
        "")
            break
        ;;
        *)
        ;;
    esac
done
exit
