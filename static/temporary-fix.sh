#!/bin/bash

# T&M Hansson IT AB © - 2020, https://www.hanssonit.se/

# shellcheck disable=2034,2059
true
# shellcheck source=lib.sh
. <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Must be root
root_check

# Fix LVM on BASE image
if grep -q "LVM" /etc/fstab
then
    # Resize LVM (live installer is &%¤%/!
    lvextend -l 100%FREE --resizefs /dev/ubuntu-vg/ubuntu-lv
fi

# Fix ZFS
run_static_script change-to-zfs-mount-generator

exit
