#!/bin/bash

# T&M Hansson IT AB © - 2024, https://www.hanssonit.se/

# https://wiki.archlinux.org/index.php/ZFS#Using_zfs-mount-generator
# Tested on Ubuntu 22.04

# This script came to life when we were having issues with importing the ZFS pool (ncdata) on Ubuntu 22.04.
# After some forum reading and some digging on Github, this is the result.
# The intention here is to make the import process more robust, and less prune to fail
# Essentially, changing from 'zfs-mount.service' to 'zfs-mount-generator' which by many has been working better.

true
SCRIPT_NAME="Change to ZFS Mount Generator"
# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh

# Check if root
root_check

# Needs to be Ubuntu 22.04 and Multiverse
check_distro_version
check_multiverse

# Import if missing and export again to import it with UUID
# https://github.com/nextcloud/vm/blob/main/lib.sh#L1233
# Set a different name for the pool (if used outside of this repo)
# export POOLNAME=ncdata
zpool_import_if_missing

# Make sure the correct packages are installed
install_if_not zfs-zed

# Create the dir for this to work
mkdir -p /etc/zfs/zfs-list.cache

# Enable ZFS Event Daemon(ZED) aka ZEDLET
if [ -f /usr/lib/zfs-linux/zed.d/history_event-zfs-list-cacher.sh ]
then
    if [ ! -L /etc/zfs/zed.d/history_event-zfs-list-cacher.sh ]
    then
        check_command ln -s /usr/lib/zfs-linux/zed.d/history_event-zfs-list-cacher.sh /etc/zfs/zed.d
    fi
else
    msg_box "/usr/lib/zfs-linux/zed.d/history_event-zfs-list-cacher.sh is missing, aborting!"
    exit 1
fi

# Enable and disable services
# NEEDED:
systemctl enable zfs-import-cache
# DISABLE OLD METHOD
systemctl disable zfs-mount
# FOR ZEDLET
check_command systemctl enable zfs-zed.service
check_command systemctl enable zfs.target
start_if_stopped zfs-zed

# Activate config
touch /etc/zfs/zfs-list.cache/"$POOLNAME"
zfs set canmount=on "$POOLNAME"
sleep 1
if [ -s /etc/zfs/zfs-list.cache/"$POOLNAME" ]
then
    print_text_in_color "$ICyan" "/etc/zfs/zfs-list.cache/$POOLNAME is empty, setting values manually instead."
    zfs list -H -o name,mountpoint,canmount,atime,relatime,devices,exec,readonly,setuid,nbmand,encroot,keylocation > /etc/zfs/zfs-list.cache/"$POOLNAME"
fi
