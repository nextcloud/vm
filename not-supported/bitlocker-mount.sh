#!/bin/bash

# T&M Hansson IT AB © - 2024, https://www.hanssonit.se/
# Copyright © 2021 Simon Lindner (https://github.com/szaimen)

true
SCRIPT_NAME="Bitlocker Mount"
SCRIPT_EXPLAINER="This script automates mounting Bitlocker encrypted drives locally in your system.
Currently supported are only Bitlocker encrypted NTFS (Windows) drives.
You need a password to mount the drive. Recovery keys are not supported."
# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Check if root
root_check

# Show install_popup
if ! is_this_installed dislocker
then
    # Ask for installing
    install_popup "$SCRIPT_NAME"
fi

# Test if one drive is already mounted/created
if grep -q "/media/bitlocker/1" /etc/fstab || mountpoint -q /media/bitlocker/1
then
    msg_box "This script currently only supports mounting one Bitlocker encrypted drive.
Please unmount the current one and remove it from /etc/fstab if you want to mount a different one.

The easiest way to do so is to run the following two commands:
sudo sed -i '/\/media\/bitlocker\/1/d' /etc/fstab
sudo reboot"
    exit
fi

# Install needed packet
install_if_not dislocker

# Secure fstab
chown root:root /etc/fstab
chmod 600 /etc/fstab

# Connect Bitlocker drive
msg_box "Please connect your Bitlocker encrypted NTFS (Windows) drive now if you haven't already done this.
After you hit OK, we wil scan for Bitlocker drives."
print_text_in_color "$ICyan" "Please connect your Bitlocker encrypted drive now."
count=0
while [ "$count" -lt 60 ]
do
    PARTUUID=$(lsblk -o FSTYPE,PARTUUID | grep BitLocker | awk '{print $2}' | head -1)
    if [ -z "$PARTUUID" ]
    then
        print_text_in_color "$ICyan" "No Bitlocker drive found. Please connect your drive now."
        sleep 5 & spinner_loading
        echo ""
        count=$((count+5))
    else
        break
    fi
done

# Exit after 60 seconds
if [ "$count" -ge 60 ]
then
    msg_box "No drive found within 60 seconds.
Please run this script again if you want to try again."
    msg_box "We will now remove dislocker so that you keep a clean system."
    apt-get purge dislocker -y
    apt-get autoremove -y
    exit
fi

# Inform the user
msg_box "A Bitlocker encrypted drive was found!
Please leave it connected. We will now continue with the mounting process."

# Enter the password
while :
do
    PASSWORD=$(input_box_flow "Please enter your password for the Bitlocker encrypted drive now!
If you want to cancel, type 'exit' and press [ENTER].")
    if [ "$PASSWORD" = "exit" ]
    then
        msg_box "We will now remove dislocker so that you keep a clean system."
        apt-get purge dislocker -y
        apt-get autoremove -y
        exit 1
    fi
    mkdir -p /media/bitlocker/1
    echo "PARTUUID=$PARTUUID /media/bitlocker/1 fuse.dislocker \
user-password=$PASSWORD,nofail 0 0" >> /etc/fstab
    if ! mount /media/bitlocker/1
    then
        msg_box "The password seems to be false. Please try again."
        sed -i '/fuse.dislocker/d' /etc/fstab
    else
        break
    fi
done

# Inform the user
msg_box "The password is correct."

# Enter the mountpoint
while :
do
    MOUNT_PATH=$(input_box_flow "Please type in the directory where you want to mount the Bitlocker encrypted drive.
One example is: '/mnt/data'
The directory has to start with '/mnt/'
If you want to cancel, type 'exit' and press [ENTER].")
    if [ "$MOUNT_PATH" = "exit" ]
    then
        umount /media/bitlocker/1
        sed -i '/fuse.dislocker/d' /etc/fstab
        msg_box "We will now remove dislocker so that you keep a clean system."
        apt-get purge dislocker -y
        apt-get autoremove -y
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
        echo "/media/bitlocker/1/dislocker-file $MOUNT_PATH ntfs-3g \
windows_names,uid=www-data,gid=www-data,umask=007,nofail 0 0" >> /etc/fstab
        mkdir -p "$MOUNT_PATH"
        if ! mount "$MOUNT_PATH"
        then
            msg_box "The mount wasn't successful. Please try again.
Most likely it fails because the Bitlocker encrypted drive is no NTFS (Windows) drive."
            sed -i '/\/media\/bitlocker\/1\/dislocker-file /d' /etc/fstab
        else
            break
        fi
    fi
done

# Inform the user
msg_box "Congratulations! The mount was successful.
You can now access the Bitlocker drive here:
$MOUNT_PATH"

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
            exit 1
        fi
        if ! bash /tmp/pms-conf
        then
            msg_box "Starting the new container failed. You can find the config here: '/tmp/pms-conf'"
            exit 1
        fi
        rm /tmp/pms-conf
        msg_box "Plex was adjusted!"
    else
        rm /tmp/pms-conf
        msg_box "No need to update Plex, since the drive is already mounted to Plex."
    fi
fi

exit
