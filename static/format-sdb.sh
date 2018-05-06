#!/bin/bash

# Tech and Me © - 2018, https://www.techandme.se/

# shellcheck disable=2034,2059
true
# shellcheck source=lib.sh
. <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)

# Check if root
root_check

# Check if ZFS utils are installed
install_if_not zfsutils-linux 

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

Please shutdown the server and mount a second drive, then start this script again.

If you want help you can buy support in our shop:
https://shop.techandme.se/index.php/product/premium-support-per-30-minutes/"
exit 1
fi

if lsblk -l -n | grep -v mmcblk | grep disk | awk '{ print $1 }' | tail -1 > /dev/null
then
msg_box "Formatting $SDB when you hit OK.

*** WARNING: ALL YOUR DATA WILL BE ERASED! ***"
    check_command wipefs -a -f "$SDB"
    sleep 0.5
    check_command zpool create -f -o ashift=12 "$LABEL_" "$SDB"
    check_command zpool set failmode=continue "$LABEL_"
    check_command zfs set mountpoint="$MOUNT_" "$LABEL_"
    check_command zfs set compression=lz4 "$LABEL_"
    check_command zfs set sync=disabled "$LABEL_"
    check_command zfs set xattr=sa "$LABEL_"
    check_command zfs set primarycache=all "$LABEL_"
    check_command zfs set atime=off "$LABEL_"
    check_command zfs set recordsize=128k "$LABEL_"
    check_command zfs set logbias=latency "$LABEL_"

else
msg_box "It seems like /dev/sdb does not exist.
This script requires that you mount a second drive to hold the data.

Please shutdown the server and mount a second drive, then start this script again.

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

# Success!
if grep "$LABEL_" /etc/mtab
then
msg_box "$MOUNT_ mounted successfully as a ZFS volume:

$(zpool status $LABEL_)

$(zpool list)"
fi

