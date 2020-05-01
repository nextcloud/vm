#!/bin/bash

# T&M Hansson IT AB © - 2020, https://www.hanssonit.se/

# https://wiki.archlinux.org/index.php/ZFS#Using_zfs-mount-generator
# Tested on Ubuntu 20.04

# This script came to life when we were having issues with importing the ZFS pool (ncdata) on Ubuntu 20.04.
# After some forum reading and some digging on Github, this is the result.
# The intention here is to make the import process more robust, and less prune to fail
# Esentially, changing from źfs-mount.service' to 'zfs-mount-generator' which by many has been working better.

####     ####
#### WIP ####
####     ####

# shellcheck disable=2034,2059
true
# shellcheck source=lib.sh
. <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)

# Check if root
root_check

# Needs to be Ubuntu 20.04 and Multiverse
check_distro_version
check_multiverse

POOLNAME=ncdata

if [ -z "$POOLNAME" ]
then
    msg_box "It seems like the POOLNAME variable is empty, we can't continue without it."
    exit 1
fi

# In either case it's always better to use UUID instead of the /dev/sdX name, so do that as well
# Import zpool in case missing
zpool import -f "$POOLNAME"

# Get UUID
if fdisk -l /dev/sdb1
then
    UUID_SDB1=$(blkid -o value -s UUID /dev/sdb1)
fi

# Export / import
zpool export "$POOLNAME"
zpool import -d /dev/disk/by-uuid/"$UUID_SDB1" "$POOLNAME"

# Make sure the correct packages are installed
install_if_not zfs-zed

# Create the dir for this to work
mkdir -p /etc/zfs/zfs-list.cache

# Enable ZFS Event Daemon(ZED) aka ZEDLET
if [ -f /usr/lib/zfs-linux/zed.d/history_event-zfs-list-cacher.sh ]
then
    check_command ln -s /usr/lib/zfs-linux/zed.d/history_event-zfs-list-cacher.sh /etc/zfs/zed.d
else
    msg_box "/usr/lib/zfs-linux/zed.d/history_event-zfs-list-cacher.sh is missing, aborting!"
    exit 1
fi

# Enable and disable services
# NEEDED:
systemctl enable zfs-import-cache
systemctl enable zfs-import.target
# DISABLE OLD METHOD
systemctl disable zfs-mount
systemctl disable zfs.target
# FOR ZEDLET
check_command systemctl enable zfs-zed.service
check_command systemctl enable zfs.target
check_command systemctl start zfs-zed.service

# Activate config
touch /etc/zfs/zfs-list.cache/"$POOLNAME"
zfs set canmount=on "$POOLNAME"
sleep 1
if [ -s /etc/zfs/zfs-list.cache/"$POOLNAME" ]
then
    print_text_in_color "$ICyan" "/etc/zfs/zfs-list.cache/$POOLNAME is emtpy, setting values manually instead."
    zfs list -H -o name,mountpoint,canmount,atime,relatime,devices,exec,readonly,setuid,nbmand,encroot,keylocation > /etc/zfs/zfs-list.cache/"$POOLNAME"
fi
