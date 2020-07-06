#!/bin/bash

# T&M Hansson IT AB © - 2020, https://www.hanssonit.se/

# shellcheck disable=2034,2059,2086
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
    notify_admin_gui "S.M.A.R.T results weekly scan (nvme0n1)" "$(smartctl --all /dev/nvme0n1)"
    notify_admin_gui "S.M.A.R.T results weekly scan (sda)" "$(smartctl --all /dev/sda)"
else
    # get all disks into an array
    disks="$(fdisk -l | grep Disk | grep /dev/sd | awk '{print$2}' | cut -d ":" -f1)"
    # loop over disks in array
    for disk in $(printf "${disks[@]}")
    do
        if [ -n "$disks" ]
        then
             notify_admin_gui "S.M.A.R.T results weekly scan ($disk)" "$(smartctl --all $disk)"
        fi
    done
fi

# Add crontab “At 06:12 on Monday.”
if ! crontab -u root -l | grep -w 'smartctl.sh'
then
    print_text_in_color "$ICyan" "Adding weekly crontab..."
    crontab -u root -l | { cat; echo "12 06 * * 1 $SCRIPTS/smartctl.sh"; } | crontab -u root -
    msg_box "S.M.A.R.T is now configured scheluded to run every Monday at 06:12.\n\nYou will be notified with the results each time."
fi
