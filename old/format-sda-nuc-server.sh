#!/bin/bash

# T&M Hansson IT AB © - 2024, https://www.hanssonit.se/

true
SCRIPT_NAME="Format sda NUC Server"
# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh

# Check if root
root_check

# Needs to be Ubuntu 22.04 and Multiverse
check_distro_version
check_multiverse

MOUNT_=/mnt/$POOLNAME

# Needed for partprobe
install_if_not parted

format() {
# umount if mounted
umount /mnt/* &> /dev/null

# mkdir if not existing
mkdir -p "$MOUNT_"

DEVTYPE=sda

# Get the name of the drive
DISKTYPE=$(fdisk -l | grep $DEVTYPE | awk '{print $2}' | cut -d ":" -f1 | head -1)
if [ "$DISKTYPE" != "/dev/$DEVTYPE" ]
then
    msg_box "It seems like your $SYSNAME secondary volume (/dev/$DEVTYPE) does not exist.
This script requires that you mount a second drive to hold the data.

Please shutdown the server and mount a second drive, then start this script again.

If you want help you can buy support in our shop:
https://shop.hanssonit.se/product/premium-support-per-30-minutes/"
    exit 1
fi

# Check if ZFS utils are installed
install_if_not zfsutils-linux

# Check still not mounted
#These functions return exit codes: 0 = found, 1 = not found
isMounted() { findmnt -rno SOURCE,TARGET "$1" >/dev/null;} #path or device
isDevMounted() { findmnt -rno SOURCE        "$1" >/dev/null;} #device only
isPathMounted() { findmnt -rno        TARGET "$1" >/dev/null;} #path   only
isDevPartOfZFS() { zpool status | grep "$1" >/dev/null;} #device member of a zpool

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

# Universal:
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

if lsblk -l -n | grep -v mmcblk | grep disk | awk '{ print $1 }' | tail -1 > /dev/null
then
    msg_box "Formatting your $SYSNAME secondary volume ($DISKTYPE) when you hit OK.

*** WARNING: ALL YOUR DATA WILL BE ERASED! ***"
    if zpool list | grep "$POOLNAME" > /dev/null
    then
        check_command zpool destroy "$POOLNAME"
    fi
    check_command wipefs -a -f "$DISKTYPE"
    sleep 0.5
    check_command zpool create -f -o ashift=12 "$POOLNAME" "$DISKTYPE"
    check_command zpool set failmode=continue "$POOLNAME"
    check_command zfs set mountpoint="$MOUNT_" "$POOLNAME"
    check_command zfs set compression=lz4 "$POOLNAME"
    check_command zfs set sync=standard "$POOLNAME"
    check_command zfs set xattr=sa "$POOLNAME"
    check_command zfs set primarycache=all "$POOLNAME"
    check_command zfs set atime=off "$POOLNAME"
    check_command zfs set recordsize=128k "$POOLNAME"
    check_command zfs set logbias=latency "$POOLNAME"

else
    msg_box "It seems like /dev/$DEVTYPE does not exist.
This script requires that you mount a second drive to hold the data.

Please shutdown the server and mount a second drive, then start this script again.

If you want help you can buy support in our shop:
https://shop.hanssonit.se/product/premium-support-per-30-minutes/"
    exit 1
fi
}
format

# Do a backup of the ZFS mount
if is_this_installed libzfs2linux
then
    if grep -r $POOLNAME /etc/mtab
    then
        install_if_not zfs-auto-snapshot
        sed -i "s|date --utc|date|g" /usr/sbin/zfs-auto-snapshot
    fi
fi

# Check if UUID is used
if zpool list -v | grep "$DEVTYPE"
then
    # Get UUID
    check_command partprobe -s
    if fdisk -l /dev/"$DEVTYPE"1 >/dev/null 2>&1
    then
        UUID_SDB1=$(blkid -o value -s UUID /dev/"DEVTYPE"1)
    fi
    # Export / import the correct way (based on UUID)
    check_command zpool export "$POOLNAME"
    check_command zpool import -d /dev/disk/by-uuid/"$UUID_SDB1" "$POOLNAME"
fi

# Success!
if grep "$POOLNAME" /etc/mtab
then
    msg_box "$MOUNT_ mounted successfully as a ZFS volume.

Automatic scrubbing is done monthly via a cronjob that you can find here:
/etc/cron.d/zfsutils-linux

Automatic snapshots are taken with 'zfs-auto-snapshot'. You can list current snapshots with:
'sudo zfs list -t snapshot'.
Manpage is here:
http://manpages.ubuntu.com/manpages/focal/man8/zfs-auto-snapshot.8.html

CURRENT STATUS:
$(zpool status $POOLNAME)

$(zpool list)"
fi
