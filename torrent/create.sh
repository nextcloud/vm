#!/bin/bash

# T&M Hansson IT AB © - 2023, https://www.hanssonit.se/
# GNU General Public License v3.0
# https://github.com/nextcloud/vm/blob/master/LICENSE

#########

## This doesn't seem to work in current state.
## Help is welcome!

# shellcheck source=lib.sh
# shellcheck disable=SC2046
source /var/scripts/fetch_lib.sh || source <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Check if root
root_check

# Install dependencies
install_if_not transmission-cli
install_if_not transmission-daemon

# Download the VM
curl -fSLO --retry 3 https://download.kafit.se/s/dnkWptz8AK4JZDM/download
mv download NextcloudVM.zip
chown debian-transmission:debian-transmission NextcloudVM.zip

# Set more memory to sysctl
echo "net.core.rmem_max = 16777216" >> /etc/sysctl.conf
echo "net.core.wmem_max = 4194304" >> /etc/sysctl.conf
sysctl -p

# Create torrent
curl_to_dir "$GITHUB_REPO"/torrent trackers.txt /tmp
transmission-create -o nextcloudvmhanssonit.torrent -c "https://www.hanssonit.se/nextcloud-vm" -t $(cat /tmp/trackers.txt) NextcloudVM.zip

# Seed it!
transmission-remote -n 'transmission:transmission' -a nextcloudvmhanssonit.torrent

# Copy it to local NC account
install_if_not rsync
nextclouduser="$(input_box_flow "Please enter the Nextcloud user that you want to move the finished torrent file to:")"
rsync -av nextcloudvmhanssonit.torrent /mnt/ncdata/"$nextclouduser"/files/
chown www-data:www-data /mnt/ncdata/"$nextclouduser"/files/nextcloudvmhanssonit.torrent
nextcloud_occ files:scan "$nextclouduser"
unset nextclouduser
