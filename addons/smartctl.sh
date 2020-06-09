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

print_text_in_color "$ICyan" "Installing and configuring S.M.A.R.T..."

# Install smartmontools
install_if_not smartmontools

# Add a crontab to check the disk, and post the output with notify_admin_gui ever week (maybe with updatenotification?)
if home_sme_server
then
    smartctl --all /dev/nvme0n1
    smartctl --all /dev/sda
elif [check which disks are used]
    smartctl --all /dev/sda
    smartctl --all /dev/sdb
fi
