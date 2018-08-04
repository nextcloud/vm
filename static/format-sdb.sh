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


# Check what Hypervisor disks are available
if partprobe /dev/sdb &>/dev/null;	#HyperV, VMware, VirtualBox Hypervisors
then
    DEVTYPE=sdb
elif partprobe /dev/xvdb &>/dev/null;	#Xen Hypervisors
then
    DEVTYPE=xvdb
elif partprobe /dev/vdb &>/dev/null;	#KVM Hypervisor
then
    DEVTYPE=vdb
else
msg_box "It seems like you didn't mount a second disk. 
To be able to put the DATA on a second drive formatted as ZFS you need to add a second disk to this server.

This sript will now exit. Please mount a second disk and start over."
exit 1
fi

# Check if ZFS utils are installed
install_if_not zfsutils-linux 

# Check still not mounted
#These functions return exit codes: 0 = found, 1 = not found
isMounted() { findmnt -rno SOURCE,TARGET "$1" >/dev/null;} #path or device
isDevMounted() { findmnt -rno SOURCE        "$1" >/dev/null;} #device only
isPathMounted() { findmnt -rno        TARGET "$1" >/dev/null;} #path   only
isDevPartOfZFS() { zpool status | grep "$1" >/dev/null;} #device memeber of a zpool

if isPathMounted "/mnt/ncdata";      #Spaces in path names are ok.
then
msg_box "/mnt/ncdata is mounted and need to be unmounted before you can run this script."
    exit 1
fi

if isDevMounted "/dev/$DEVTYPE";
then
msg_box "/dev/$DEVTYPE is mounted and need to be unmounted before you can run this script."
    exit 1
fi

#Universal:
if isMounted "/mnt/ncdata";
then
msg_box "/mnt/ncdata is mounted and need to be unmounted before you can run this script."
    exit 1
fi

if isMounted "/dev/${DEVTYPE}1";
then
msg_box "/dev/${DEVTYPE}1 is mounted and need to be unmounted before you can run this script."
    exit 1
fi

if isDevPartOfZFS "$DEVTYPE";
then
msg_box "/dev/$DEVTYPE is a member of a ZFS pool and needs to be removed from any zpool before you can run this script."
    exit 1
fi

# Get the name of the drive
DISKTYPE=$(fdisk -l | grep $DEVTYPE | awk '{print $2}' | cut -d ":" -f1 | head -1)
if [ "$DISKTYPE" != "/dev/$DEVTYPE" ]
then
msg_box "It seems like /dev/$DEVTYPE does not exist.
This script requires that you mount a second drive to hold the data.

Please shutdown the server and mount a second drive, then start this script again.

If you want help you can buy support in our shop:
https://shop.techandme.se/index.php/product/premium-support-per-30-minutes/"
exit 1
fi

if lsblk -l -n | grep -v mmcblk | grep disk | awk '{ print $1 }' | tail -1 > /dev/null
then
msg_box "Formatting $DISKTYPE when you hit OK.

*** WARNING: ALL YOUR DATA WILL BE ERASED! ***"
    if zpool list | grep "$LABEL_" > /dev/null
    then
        check_command zpool destroy "$LABEL_"
    fi
    check_command wipefs -a -f "$DISKTYPE"
    sleep 0.5
    check_command zpool create -f -o ashift=12 "$LABEL_" "$DISKTYPE"
    check_command zpool set failmode=continue "$LABEL_"
    check_command zfs set mountpoint="$MOUNT_" "$LABEL_"
    check_command zfs set compression=lz4 "$LABEL_"
    check_command zfs set sync=standard "$LABEL_"
    check_command zfs set xattr=sa "$LABEL_"
    check_command zfs set primarycache=all "$LABEL_"
    check_command zfs set atime=off "$LABEL_"
    check_command zfs set recordsize=128k "$LABEL_"
    check_command zfs set logbias=latency "$LABEL_"

else
msg_box "It seems like /dev/$DEVTYPE does not exist.
This script requires that you mount a second drive to hold the data.

Please shutdown the server and mount a second drive, then start this script again.

If you want help you can buy support in our shop:
https://shop.techandme.se/index.php/product/premium-support-per-30-minutes/"
exit 1
fi
}
format

# Success!
if grep "$LABEL_" /etc/mtab
then
msg_box "$MOUNT_ mounted successfully as a ZFS volume.

Automatic scrubbing is done montly via a cronjob that you can find here:
/etc/cron.d/zfsutils-linux

CURRENT STATUS:
$(zpool status $LABEL_)

$(zpool list)"
fi

