#!/bin/bash

# Tech and Me © - 2018, https://www.techandme.se/

# shellcheck disable=2034,2059
true
# shellcheck source=lib.sh
. <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)

# Check if root
root_check

LABEL_=ncdata
MOUNT_=/mnt/$LABEL_
format() {
# umount if mounted
umount /mnt/* &> /dev/null

# mkdir if not existing
mkdir -p "$MOUNT_"

# Check still not mounted
#These functions return exit codes: 0 = found, 1 = not found
isMounted() { findmnt -rno SOURCE,TARGET "$1" >/dev/null;} #path or device
isDevMounted() { findmnt -rno SOURCE        "$1" >/dev/null;} #device only
isPathMounted() { findmnt -rno        TARGET "$1" >/dev/null;} #path   only

if isPathMounted "/mnt/ncdata";      #Spaces in path names are ok.
then
msg_box "/mnt/ncdata is mounted and need to be unmounted before you can run this script."
exit 1
fi

if isDevMounted "/dev/sdb";
then
msg_box "/dev/sdb is mounted and need to be unmounted before you can run this script."
exit 1
fi

#Universal:
if isMounted "/mnt/ncdata";
then
msg_box "/mnt/ncdata is mounted and need to be unmounted before you can run this script."
exit 1
fi

if isMounted "/dev/sdb1";
then
msg_box "/dev/sdb1 is mounted and need to be unmounted before you can run this script."
exit 1
fi

# Get the name of the drive
SDB=$(fdisk -l | grep sdb | awk '{print $2}' | cut -d ":" -f1 | head -1)
if [ "$SDB" != "/dev/sdb" ]
then
msg_box "It seems like /dev/sdb does not exist.
This script requires that you mount a second drive to hold the data.

Please shutdown there server and mount a second drive.

If you want help you can buy support in our shop:
https://shop.techandme.se/index.php/product/premium-support-per-30-minutes/"
exit 1
fi

if lsblk -l -n | grep -v mmcblk | grep disk | awk '{ print $1 }' | tail -1 > /dev/null
then
msg_box "Formatting $SDB when you hit OK.

*** WARNING: ALL YOUR DATA WILL BE ERASED! ***"
    check_command wipefs -a -f "$SDB"
    check_command parted "$SDB" --script -- mklabel gpt
    check_command parted "$SDB" --script -- mkpart primary 0% 100%
    sleep 0.5
    check_command mkfs.btrfs -q "$SDB"1 -f -L "$LABEL_"
else
msg_box "It seems like /dev/sdb does not exist.
This script requires that you mount a second drive to hold the data.

Please shutdown there server and mount a second drive.

If you want help you can buy support in our shop:
https://shop.techandme.se/index.php/product/premium-support-per-30-minutes/"
exit 1
fi
}
format

# Remove old mount point in fstab if existing
if  grep "ncdata" /etc/fstab
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
if grep "$UUID" /etc/fstab
then
msg_box "$MOUNT_ mounted successfully in /etc/fstab with this command:
$FSTAB

The drive is formated as BTRFS and this is the device:
$(btrfs filesystem usage $MOUNT_)"
fi

# BTRFS maintenance
msg_box "This script will now download a set of scripts to maintain the BTRFS mount.

The scripts and instructions can be found here: https://github.com/kdave/btrfsmaintenance"

if [ ! -f /etc/default/btrfsmaintenance ]
then
    cd /tmp || exit 1
    wget -O btrfsmaintenance.zip https://github.com/kdave/btrfsmaintenance/archive/master.zip
    install_if_not unzip
    unzip -o /tmp/btrfsmaintenance.zip
    check_command bash /tmp/btrfsmaintenance-master/dist-install.sh
    check_command sed -i "s|/|$MOUNT_|g" /etc/default/btrfsmaintenance
    check_command bash /tmp/btrfsmaintenance-master/btrfsmaintenance-refresh-cron.sh
else
msg_box "It seems like /etc/default/btrfsmaintenance already exists. Have you already run this script?"
fi
