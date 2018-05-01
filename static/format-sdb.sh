#!/bin/bash

# Tech and Me © - 2018, https://www.techandme.se/

# shellcheck disable=2034,2059
true
# shellcheck source=lib.sh
. <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)

# Check if root
root_check

LABEL_=ncdata
MOUNT_=/mnt/ncdata
format() {
# umount if mounted
umount /mnt/* &> /dev/null

# mkdir if not existing
mkdir -p "$MOUNT_"

# check still not mounted
for dir in $( ls -d /mnt/* 2>/dev/null ); do
mountpoint -q $dir && { msg_box "$dir is still mounted"; exit 1; }
done

# Get the name of the drive
local NAME=( $( lsblk -l -n | grep -v mmcblk | grep sdb | awk '{ print $1 }' ) )
[[ ${#NAME[@]} != 2 ]] && { echo "unexpected error"; exit 1; }


if lsblk -l -n | grep -v mmcblk | grep sdb | awk '{ print $1 }' > /dev/null
then
msg_box "Formatting /dev/${NAME} when you hit OK.

*** WARNING: ALL YOUR DATA WILL BE ERASED! ***"
    check_command wipefs -a -f /dev/"$NAME"
    check_command parted /dev/"$NAME" --script -- mklabel gpt
    check_command parted /dev/"$NAME" --script -- mkpart primary 0% 100%
    sleep 0.5
    check_command mkfs.btrfs -q /dev/"${NAME}1" -f -L "$LABEL_"
else
msg_box "It seems like /dev/${NAME}1 does not exist.
This script requires that you mount a second drive to hold the data.

Please shutdown there server and mount a second drive.

If you want help you can buy support in our shop:
https://shop.techandme.se/index.php/product/premium-support-per-30-minutes/"
exit 1
fi
}
format

# Remove old mount point in fstab if existing
if cat /etc/fstab | grep ncdata
then
    sed -i 10q /etc/fstab > /dev/null
fi

# Mount it in fstab
UUID=$(blkid /dev/sdb1 | awk '{ print $3 }')
FSTAB="$UUID     $MOUNT_     btrfs   defaults 0       2"
echo "# ncdata mount" >> /etc/fstab
echo "$FSTAB" >> /etc/fstab
check_command mount -a

# Success!
if cat /etc/fstab | grep "$UUID"
then
msg_box "$MOUNT_ mounted successfully in /etc/fstab with this command:
$FSTAB

The drive is formated as BTRFS and this is the device:
$(btrfs fi show)"
fi

# BTRFS maintenance
msg_box "The script will now download a set of scripts to maintain the BTRFS mount.

The scripts and instructions can be found here: https://github.com/kdave/btrfsmaintenance"

if [ ! -f /etc/default/btrfsmaintenance ]
then
    cd /tmp
    wget -O btrfsmaintenance.zip https://github.com/kdave/btrfsmaintenance/archive/master.zip
    install_if_not unzip
    unzip -o /tmp/btrfsmaintenance.zip
    check_command bash /tmp/btrfsmaintenance-master/dist-install.sh
    check_command sed -i "s|/|$MOUNT_|g" /etc/default/btrfsmaintenance
    check_command bash /tmp/btrfsmaintenance-master/btrfsmaintenance-refresh-cron.sh
else
msg_box "It seems like /etc/default/btrfsmaintenance already exists. Have you already run this script?"
fi

