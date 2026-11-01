#!/bin/bash

# T&M Hansson IT AB © - 2026, https://www.hanssonit.se/

# Runs unattended from the update script.
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

# Exists after a failed attempt, so that one outage doesn't become one outage per update
ZFS_FIX_FAILED="$SCRIPTS"/zfs-disk-name-fix-failed

zpool_data_services() {
    if [ "${#ZPOOL_DATA_SERVICES[@]}" -gt 0 ]
    then
        systemctl "$1" "${ZPOOL_DATA_SERVICES[@]}"
    fi
}

leave_alone() {
    print_text_in_color "$ICyan" "ZFS disk name not changed: $1"
    exit 0
}

if ! zpool_disk_is_named_by_uuid
then
    leave_alone "it's not a single disk imported from by-uuid"
fi
ZPOOL_UUID_PATH=/dev/disk/by-uuid/"$(zpool get -H -o value guid "$POOLNAME")"

# With autoexpand on, ZED can crash the ZFS module on this pool by itself, even during boot
ZPOOL_AUTOEXPAND=$(zpool get -H -o value autoexpand "$POOLNAME")
if [ "$ZPOOL_AUTOEXPAND" = "on" ]
then
    zpool set autoexpand=off "$POOLNAME"
fi

# Only what would bring the pool back wrong, or not at all. The move is an export and an import, like
# every reboot, and zpool refuses to export a busy pool without changing anything.
if [ "$(zfs version | sed -E 's/^zfs(-kmod)?-([^-]+).*/\2/' | sort -u | wc -l)" -ne 1 ]
then
    leave_alone "the ZFS tools and the loaded module differ, try again after a reboot"
elif [ -f "$ZFS_FIX_FAILED" ]
then
    leave_alone "it failed before, remove $ZFS_FIX_FAILED to try again"
elif ! grep -q "'maintenance' => true" "$NCPATH"/config/config.php
then
    leave_alone "Nextcloud isn't in maintenance mode"
elif [ "$(zpool list -H -o health "$POOLNAME")" != "ONLINE" ]
then
    leave_alone "the pool isn't healthy"
elif [ "$(zpool get -H -o value readonly "$POOLNAME")" != "off" ]
then
    leave_alone "the pool is read only"
elif [ "$(zfs get -H -o value encryption "$POOLNAME")" != "off" ]
then
    leave_alone "the pool is encrypted"
elif [ "$(findmnt -n -o SOURCE "$NCDATA")" != "$POOLNAME" ]
then
    leave_alone "the pool isn't mounted on $NCDATA"
elif [ "$(zfs get -H -o value mountpoint "$POOLNAME")" != "$NCDATA" ] || [ "$(zfs get -H -o value canmount "$POOLNAME")" != "on" ]
then
    leave_alone "the pool doesn't mount itself on $NCDATA after an import"
elif [ "$(zfs get -H -o value overlay "$POOLNAME")" != "on" ]
then
    leave_alone "the pool can't mount over a folder with files in it (overlay is off)"
elif [ ! -f "$NCDATA"/.ocdata ] && [ ! -f "$NCDATA"/.ncdata ]
then
    leave_alone "$NCDATA doesn't look like the Nextcloud data folder"
elif pgrep -x "zfs|zpool|zdb" >/dev/null
then
    leave_alone "another ZFS command is running"
elif [ "$(zpool get -H -o value cachefile "$POOLNAME")" != "-" ] || [ ! -s /etc/zfs/zpool.cache ]
then
    leave_alone "the pool doesn't use the default cache file"
elif [ "$(blkid -c /dev/null -t UUID="${ZPOOL_UUID_PATH##*/}" -o device | wc -l)" -ne 1 ]
then
    leave_alone "this pool has to be on exactly one disk"
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

# by-id is what OpenZFS recommends. Without disk IDs (disk.EnableUUID) by-path has to do.
for zpool_location in by-id by-path
do
    if [ -n "$(find "/dev/disk/$zpool_location" -lname "*/$ZPOOL_PARTITION" -print -quit 2>/dev/null)" ]
    then
        ZPOOL_NEW_LOCATION="$zpool_location"
        break
    fi
done
if [ -z "$ZPOOL_NEW_LOCATION" ]
then
    leave_alone "there's no by-id or by-path link to the disk"
fi

# Nextcloud is in maintenance mode, so the services using the data folder can stop for the few seconds
# this takes: those with files open in it, and those with a private mount of it.
mapfile -t ZPOOL_DATA_SERVICES < <(
    {
        fuser -m "$NCDATA" 2>/dev/null
        grep -H " - zfs $POOLNAME " /proc/[0-9]*/mountinfo 2>/dev/null | grep -Ev "shared:|master:" | cut -d/ -f3
    } | xargs -r -n1 ps -o unit= -p | tr -d ' ' | sort -u | grep -E '^[^@]+\.service$' | grep -vx "$(ps -o unit= -p $$ | tr -d ' ')"
)
trap 'zpool_data_services start' EXIT
zpool_data_services stop

# Anything still using it is left alone, like a backup or a shell in the data folder
if [ "$(findmnt -R -n -o TARGET "$NCDATA" | wc -l)" -ne 1 ]
then
    leave_alone "something else is mounted inside $NCDATA"
elif ! command -v fuser >/dev/null || fuser -m "$NCDATA" >/dev/null 2>&1
then
    leave_alone "files in $NCDATA are in use"
elif grep -h " - zfs $POOLNAME " /proc/[0-9]*/mountinfo 2>/dev/null | grep -Eqv "shared:|master:"
then
    leave_alone "a container or another process keeps its own mount of $NCDATA"
fi

# Posted first, so that the admin knows what happened even if the data folder is gone afterwards
ZPOOL_MOVE_SUBJECT="The disk in the ZFS pool $POOLNAME is being moved"
ZPOOL_MOVE_MESSAGE="The update is moving the disk in $POOLNAME to /dev/disk/$ZPOOL_NEW_LOCATION, which takes a few seconds.
If $NCDATA is empty after this, reboot to get it back, then run the update again: sudo bash $SCRIPTS/update.sh
Please report that to $ISSUES."
if ! notify_admin_gui "$ZPOOL_MOVE_SUBJECT" "$ZPOOL_MOVE_MESSAGE"
then
    send_mail "$ZPOOL_MOVE_SUBJECT" "$ZPOOL_MOVE_MESSAGE"
fi

# If the new location fails: the old one, and after that any name beats a missing pool
zpool_reimport /dev/disk/"$ZPOOL_NEW_LOCATION" "$ZPOOL_UUID_PATH" /dev

if [ "$(findmnt -n -o SOURCE "$NCDATA")" != "$POOLNAME" ]
then
    zfs mount "$POOLNAME" 2>/dev/null
fi
if [ "$(findmnt -n -o SOURCE "$NCDATA")" != "$POOLNAME" ]
then
    print_text_in_color "$IRed" "The pool $POOLNAME isn't mounted after moving its disk!"
    touch "$ZFS_FIX_FAILED"
    # They would write to the empty folder. A reboot starts them.
    ZPOOL_DATA_SERVICES=()
    # Nextcloud can't run without its data folder, so only mail can reach the admin now
    send_mail "ZFS pool $POOLNAME needs attention!" "The pool isn't mounted on $NCDATA after moving its disk, so the update can't finish.
Reboot to get it back, then run the update again: sudo bash $SCRIPTS/update.sh
Please report this to $ISSUES."
    exit 1
fi

zpool_data_services start

if [ "$(zpool list -H -o health "$POOLNAME" 2>/dev/null)" != "ONLINE" ]
then
    print_text_in_color "$IRed" "The pool $POOLNAME isn't healthy after moving its disk!"
    touch "$ZFS_FIX_FAILED"
    notify_admin_gui "ZFS pool $POOLNAME needs attention!" "The pool isn't healthy after moving its disk.
Please check 'zpool status', and report this to $ISSUES."
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
