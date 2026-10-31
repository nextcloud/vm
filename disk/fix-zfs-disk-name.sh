#!/bin/bash

# T&M Hansson IT AB © - 2026, https://www.hanssonit.se/

# Runs unattended from the update script, so anything unexpected means: change nothing.
#
# A pool imported from /dev/disk/by-uuid shows the pool GUID as the name of the disk. That name
# can't be expanded, and using it crashes the ZFS module, which needs a hard reset:
# https://github.com/openzfs/zfs/issues/19659

true
SCRIPT_NAME="Fix ZFS disk name"
# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Must be root
root_check

# Rolled out in steps. Raise this when no problems are reported.
ZFS_FIX_ROLLOUT_PERCENT=0

leave_alone() {
    print_text_in_color "$ICyan" "ZFS disk name not changed: $1"
    exit 0
}

MACHINE_ID=$(cat /etc/machine-id 2>/dev/null)
if ! [[ "$MACHINE_ID" =~ ^[0-9a-f]{4} ]] || [ "$((16#${MACHINE_ID:0:4} % 100))" -ge "$ZFS_FIX_ROLLOUT_PERCENT" ]
then
    leave_alone "not part of this rollout step"
fi

# The only state this script changes
if ! zpool_disk_is_named_by_uuid
then
    leave_alone "it's not a single disk imported from by-uuid"
fi
ZPOOL_UUID_PATH=/dev/disk/by-uuid/"$(zpool get -H -o value guid "$POOLNAME")"

# With autoexpand on, ZED can crash the ZFS module on this pool by itself. Turning it off needs no downtime.
ZPOOL_AUTOEXPAND=$(zpool get -H -o value autoexpand "$POOLNAME")
if [ "$ZPOOL_AUTOEXPAND" = "on" ]
then
    zpool set autoexpand=off "$POOLNAME"
fi

# Everything has to be as expected before the pool is exported. If we think it might fail, don't try.
if [ "$(zfs version | sed -E 's/^zfs(-kmod)?-([^-]+).*/\2/' | sort -u | wc -l)" -ne 1 ]
then
    leave_alone "the ZFS tools and the loaded module differ, try again after a reboot"
elif ! grep -q "'maintenance' => true" "$NCPATH"/config/config.php
then
    leave_alone "Nextcloud isn't in maintenance mode"
elif [ "$(zpool list -H -o health "$POOLNAME")" != "ONLINE" ]
then
    leave_alone "the pool isn't healthy"
elif ! LC_ALL=C zpool status -x "$POOLNAME" | grep -q "is healthy"
then
    leave_alone "the pool has errors"
elif LC_ALL=C zpool status "$POOLNAME" | grep -q "in progress"
then
    leave_alone "a scrub or resilver is running"
elif [ "$(zpool get -H -o value readonly "$POOLNAME")" != "off" ]
then
    leave_alone "the pool is read only"
elif [ "$(zfs list -H -r -t filesystem,volume -o name "$POOLNAME")" != "$POOLNAME" ]
then
    leave_alone "the pool has more than one dataset"
elif [ "$(zfs get -H -o value encryption "$POOLNAME")" != "off" ]
then
    leave_alone "the pool is encrypted"
elif [ "$(findmnt -n -o SOURCE "$NCDATA")" != "$POOLNAME" ]
then
    leave_alone "the pool isn't mounted on $NCDATA"
elif [ ! -f "$NCDATA"/.ocdata ] && [ ! -f "$NCDATA"/.ncdata ]
then
    leave_alone "$NCDATA doesn't look like the Nextcloud data folder"
elif [ "$(findmnt -R -n -o TARGET "$NCDATA" | wc -l)" -ne 1 ]
then
    leave_alone "something else is mounted inside $NCDATA"
elif ! command -v fuser >/dev/null || fuser -m "$NCDATA" >/dev/null 2>&1
then
    leave_alone "files in $NCDATA are in use"
elif grep -h " - zfs $POOLNAME " /proc/[0-9]*/mountinfo 2>/dev/null | grep -Eqv "shared:|master:"
then
    leave_alone "a container or another process keeps its own mount of $NCDATA"
elif pgrep -x "zfs|zpool|zdb" >/dev/null
then
    leave_alone "another ZFS command is running"
elif [ "$(zpool get -H -o value cachefile "$POOLNAME")" != "-" ] || [ ! -s /etc/zfs/zpool.cache ]
then
    leave_alone "the pool doesn't use the default cache file"
elif [ "$(df --output=avail /etc/zfs | tail -1)" -lt 102400 ]
then
    leave_alone "there's less than 100 MiB free on the root disk"
elif [ "$(blkid -c /dev/null -t UUID="${ZPOOL_UUID_PATH##*/}" -o device | wc -l)" -ne 1 ]
then
    leave_alone "more than one disk carries this pool"
fi

# zpool create on a whole disk makes exactly two partitions: the pool and a small reserved one
ZPOOL_PARTITION=$(basename "$(readlink -f "$ZPOOL_UUID_PATH")")
ZPOOL_DISK=$(lsblk -no PKNAME "/dev/$ZPOOL_PARTITION")
if [ "$(lsblk -nlo NAME "/dev/$ZPOOL_DISK" | wc -l)" -ne 3 ]
then
    leave_alone "the pool isn't on a whole disk"
fi

# The disk was grown in the hypervisor. Below 1 GiB is rounding, not a resize.
if [ "$(($(blockdev --getsize64 "/dev/$ZPOOL_DISK") - $(blockdev --getsize64 "/dev/$ZPOOL_PARTITION")))" -ge 1073741824 ]
then
    ZPOOL_NEEDS_EXPAND=yes
fi

# Prints the link to a device in /dev/disk/by-id or /dev/disk/by-path
zpool_device_link() {
    find "/dev/disk/$1" -lname "*/$2" -print -quit 2>/dev/null
}

# by-id is what OpenZFS recommends. by-path depends on the virtual hardware, where by-uuid doesn't,
# so without disk IDs the pool only moves when it has to be expanded.
if [ -n "$(zpool_device_link by-id "$ZPOOL_DISK")" ] && [ -n "$(zpool_device_link by-id "$ZPOOL_PARTITION")" ]
then
    ZPOOL_NEW_LOCATION=by-id
elif [ -n "$ZPOOL_NEEDS_EXPAND" ] && [ -n "$(zpool_device_link by-path "$ZPOOL_DISK")" ] && [ -n "$(zpool_device_link by-path "$ZPOOL_PARTITION")" ]
then
    ZPOOL_NEW_LOCATION=by-path
else
    leave_alone "there are no disk IDs (disk.EnableUUID) and nothing to expand"
fi

# The new name has to lead to this exact pool, read from the disk itself
if ! zdb -l "$(zpool_device_link "$ZPOOL_NEW_LOCATION" "$ZPOOL_PARTITION")" 2>/dev/null | grep -q "pool_guid: ${ZPOOL_UUID_PATH##*/}$"
then
    leave_alone "the $ZPOOL_NEW_LOCATION link doesn't lead to this pool"
fi

# If the new location fails: the old one, and after that any name beats a missing pool
zpool_reimport /dev/disk/"$ZPOOL_NEW_LOCATION" "$ZPOOL_UUID_PATH" /dev

if [ "$(findmnt -n -o SOURCE "$NCDATA")" != "$POOLNAME" ]
then
    zfs mount "$POOLNAME" 2>/dev/null
fi
if [ "$(findmnt -n -o SOURCE "$NCDATA")" != "$POOLNAME" ] || [ "$(zpool list -H -o health "$POOLNAME" 2>/dev/null)" != "ONLINE" ]
then
    print_text_in_color "$IRed" "The pool $POOLNAME isn't healthy and mounted after renaming its disk!"
    notify_admin_gui "ZFS pool $POOLNAME needs attention!" "The pool isn't healthy and mounted on $NCDATA after renaming its disk.
Maintenance mode is still on. Please check 'zpool status' and 'zpool import', and report this to $ISSUES."
    exit 1
fi

if zpool_disk_is_named_by_uuid
then
    leave_alone "the pool was busy or couldn't move, trying again at the next update"
fi
ZPOOL_DISK_NAME=$(zpool list -vH "$POOLNAME" | awk 'NR>1 {print $1}')
print_text_in_color "$IGreen" "The disk in $POOLNAME is now named: $ZPOOL_DISK_NAME"

if [ -n "$ZPOOL_NEEDS_EXPAND" ]
then
    zpool online -e "$POOLNAME" "$ZPOOL_DISK_NAME"
fi
if [ "$ZPOOL_AUTOEXPAND" = "on" ]
then
    zpool set autoexpand=on "$POOLNAME"
fi
