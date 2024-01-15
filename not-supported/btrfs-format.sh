#!/bin/bash

# T&M Hansson IT AB © - 2024, https://www.hanssonit.se/
# Copyright © 2021 Simon Lindner (https://github.com/szaimen)

true
SCRIPT_NAME="BTRFS Mount"
SCRIPT_EXPLAINER="This script automates formatting drives to BTRFS."
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
format_drive() {
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

# Get all new drives
mapfile -t CURRENT_DRIVES <<< "$CURRENT_DRIVES"
for drive in "${CURRENT_DRIVES[@]}"
do
    NEW_DRIVES=$(echo "$NEW_DRIVES" | grep -v "^$drive")
done

# Partition menu
args=(whiptail --title "$TITLE" --menu \
"Please select the drive that you would like to format to BTRFS.
$MENU_GUIDE" "$WT_HEIGHT" "$WT_WIDTH" 4)

# Get information that are important
mapfile -t NEW_DRIVES <<< "$NEW_DRIVES"
for drive in "${NEW_DRIVES[@]}"
do
    DRIVE_DESCRIPTION=$(lsblk -o NAME,SIZE,VENDOR,MODEL | grep "^$drive" | awk '{print $2, $3, $4}')
    args+=("/dev/$drive" " $DRIVE_DESCRIPTION")
done

# Show the drive menu
DEVICE=$("${args[@]}" 3>&1 1>&2 2>&3)
if [ -z "$DEVICE" ]
then
    return 1
fi

# Enter partition label
while :
do
    LABEL="$(input_box_flow "Please enter the partition label that the drive shall get.
If you want to cancel, type in 'exit' and press [ENTER].")"
    if [ "$LABEL" = exit ]
    then
        return 1
    else
        break
    fi
done

# Last info box
if ! yesno_box_no "Warning: Are you really sure, that you want to format the drive '$DEVICE' to BTRFS?
All current files on the drive will be erased!
Select 'Yes' to continue with the process. Select 'No' to cancel."
then
    exit 1
fi

# Inform user
msg_box "We will now format the drive '$DEVICE' to BTRFS. Please be patient!"

# Wipe drive
dd if=/dev/urandom of="$DEVICE" bs=1M count=2
parted "$DEVICE" mklabel gpt --script
parted "$DEVICE" mkpart primary 0% 100% --script

# Wait because mkfs fails otherwise
sleep 1

# Format drive
if ! mkfs.btrfs "${DEVICE}1" --quiet --label "$LABEL"
then
    msg_box "Something failed while formatting the drive to BTRFS."
    exit 1
fi

# Inform user
msg_box "Formatting $DEVICE to BTRFS was successful!

You can now use the 'BTRFS Mount' script from the Not-Supported Menu to mount the drive to your system."
}

# Show main_menu
while :
do
    choice=$(whiptail --title "$TITLE" --menu \
"Choose what you want to do.
$MENU_GUIDE" "$WT_HEIGHT" "$WT_WIDTH" 4 \
"Format a drive" "(Interactively format a drive to BTRFS)" \
"Exit" "(Exit this script)" 3>&1 1>&2 2>&3)
    case "$choice" in
        "Format a drive")
            format_drive
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
