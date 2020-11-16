#!/bin/bash

# T&M Hansson IT AB © - 2020, https://www.hanssonit.se/
# Copyright © 2020 Simon Lindner (https://github.com/szaimen)

true
SCRIPT_NAME="Veracrypt"
SCRIPT_EXPLAINER="This script automates formatting, encrypting and mounting drives with Veracrypt."
# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh || source <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Check if root
root_check

# Show explainer
msg_box "$SCRIPT_EXPLAINER"

if ! is_this_installed veracrypt
then
    if ! yesno_box_yes "Do you want to install $SCRIPT_NAME?"
    then
        exit 1
    fi
    msg_box "Please note that in order to install Veracrypt on your server, \
we need to add a 3rd Party PPA, which theoretically could set your server under risk."
    if ! yesno_box_yes "Do you want to continue nonetheless?"
    then
        exit 1
    fi
    msg_box "We wil now install veracrypt. This can take a long time. Please be patient!"
    add-apt-repository ppa:unit193/encryption -y
    apt update -q4 & spinner_loading
    apt install veracrypt --no-install-recommends -y
fi

# Discover drive
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
    exit 1
fi

# Get all new drives
mapfile -t CURRENT_DRIVES <<< "$CURRENT_DRIVES"
for drive in "${CURRENT_DRIVES[@]}"
do
    NEW_DRIVES=$(echo "$NEW_DRIVES" | grep -v "^$drive")
done

# Partition menu
args=(whiptail --title "$TITLE" --menu \
"Please select the drive that you would like to format and encrypt with Veracrypt.
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
    exit 1
fi

# Ask for password
while :
do
    PASSWORD=$(input_box_flow "Please enter the Password that you would like to use for encrypting your drive '$DEVICE'
It should be a strong password.
If you want to cancel, just type in 'exit' and press [ENTER].")
    if [ "$PASSWORD" = "exit" ]
    then
        exit 1
    fi
    if yesno_box_no "Have you saved the password at a safe place?"
    then
        break
    fi
done

# Last info box
if ! yesno_box_no "Warning: Are you really sure, that you want to format the drive '$DEVICE' and encrypt it?
All current files on the drive will be erased!
Select 'Yes' to continue with the process. Select 'No' to cancel."
then
    exit 1
fi

# Inform user
msg_box "We will now format the drive '$DEVICE' and encrypt it with Veracrypt. Please be patient!"

# Wipe drive
dd if=/dev/urandom of="$DEVICE" bs=1M count=2
parted "$DEVICE" mklabel gpt --script
parted "$DEVICE" mkpart primary 0% 100% --script

# Wait so that veracrypt doesn't fail
sleep 1

# Format drive
# https://relentlesscoding.com/posts/encrypt-device-with-veracrypt-from-the-command-line/
if ! echo "$PASSWORD" \
| veracrypt --text --quick \
--non-interactive \
--create "$DEVICE"1 \
--volume-type=normal \
--encryption=AES \
--hash=SHA-512 \
--filesystem=NTFS \
--stdin > /dev/null
then
    msg_box "Something failed while encypting with Veracrypt."
    exit 1
fi

# Inform user
msg_box "Formatting and encryption with Veracrypt was successful!"

# Mount it
if ! yesno_box_yes "Do you want to mount the encrypted partition to your server?"
then
    exit 1
fi

# Get PARTUUID
PARTUUID=$(lsblk -o PATH,PARTUUID | grep "^$DEVICE"1 | awk '{print $2}')

# Enter the mountpoint
while :
do
    MOUNT_PATH=$(input_box_flow "Please type in the directory where you want to mount the partition.
One example is: '/mnt/data'
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
        mkdir -p "$MOUNT_PATH"
        if ! echo "$PASSWORD" | veracrypt -t -k "" --pim=0 --protect-hidden=no \
--fs-options=windows_names,uid=www-data,gid=www-data,umask=007,\
x-systemd.automount,x-systemd.idle-timeout=60 \
"/dev/disk/by-partuuid/$PARTUUID" "$MOUNT_PATH"
        then
            msg_box "Something failed while trying to mount the Volume. Please try again."
        else
            break
        fi
    fi
done

# Create automount script
# Unfortunately the automount via crypttab doesn't work (when using a passphrase-file)
if ! [ -f "$SCRIPTS/veracrypt-automount.sh" ]
then
    cat << AUTOMOUNT > "$SCRIPTS/veracrypt-automount.sh"
#!/bin/bash

# Secure the file
chown root:root "$SCRIPTS/veracrypt-automount.sh"
chmod 700 "$SCRIPTS/veracrypt-automount.sh"

# Veracrypt entries
AUTOMOUNT
fi

# Write to file
cat << AUTOMOUNT >> "$SCRIPTS/veracrypt-automount.sh"
echo "$PASSWORD" | veracrypt -t -k "" --pim=0 --protect-hidden=no \
--fs-options=windows_names,uid=www-data,gid=www-data,umask=007,x-systemd.automount,x-systemd.idle-timeout=60 \
"/dev/disk/by-partuuid/$PARTUUID" "$MOUNT_PATH"
AUTOMOUNT

# Secure the file
chown root:root "$SCRIPTS/veracrypt-automount.sh"
chmod 700 "$SCRIPTS/veracrypt-automount.sh"

# Create crontab
crontab -u root -l | grep -v 'veracrypt-automount.sh'  | crontab -u root -
# Here we want to get informed if something fails hence not redirecting sterr to /dev/null
crontab -u root -l | { cat; echo "@reboot $SCRIPTS/veracrypt-automount.sh > /dev/null"; } | crontab -u root -

# Inform the user
msg_box "Congratulations! The mount was successful.
You can now access the partition here:
$MOUNT_PATH"

exit
