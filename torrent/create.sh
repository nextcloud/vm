#!/bin/bash

# T&M Hansson IT AB © - 2026, https://www.hanssonit.se/
# GNU General Public License v3.0
# https://github.com/nextcloud/vm/blob/main/LICENSE

#########

## This script will install Transmission, download the latest version of the VM, create a torrent of the file and seed it using Transmission 
## Improvements to the script are welcome!

# shellcheck source=lib.sh
# shellcheck disable=SC2046
if [ -f /var/scripts/fetch_lib.sh ]
then
    # shellcheck source=static/fetch_lib.sh
    source /var/scripts/fetch_lib.sh
elif ! source <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/main/static/fetch_lib.sh)
then
    source <(curl -sL https://cdn.statically.io/gh/nextcloud/vm/main/static/fetch_lib.sh)
fi

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

TRANSMISSION_DL_DIR="/var/lib/transmission-daemon/downloads"
NC_OVA="100GB_Nextcloud-VM_www.hanssonit.se.ova"
VERSION_TAG=31.0.2
VERSION_HUB=10

# Modify transmission service file to fix https://github.com/transmission/transmission/issues/6991
sed -i "s|Type=notify|Type=simple|g" /etc/systemd/system/multi-user.target.wants/transmission-daemon.service
systemctl daemon-reload

# Check if NextcloudVM.zip already exists
if [ ! -f "$TRANSMISSION_DL_DIR"/"$NC_OVA" ]
then
    # Download the VM only if it doesn't exist
    curl_to_dir "https://download.kafit.se/public.php/dav/files/dnkWptz8AK4JZDM/$VERSION_TAG%20-%20HUB%20$VERSION_HUB" "$NC_OVA" "$TRANSMISSION_DL_DIR"
else
    echo "$NC_OVA already exists in transmission default downloads directory, skipping download"
fi

# Set more memory to sysctl
#echo "net.core.rmem_max = 16777216" >> /etc/sysctl.conf
#echo "net.core.wmem_max = 4194304" >> /etc/sysctl.conf
#sysctl -p

# Create torrent
curl_to_dir "$GITHUB_REPO"/torrent trackers.txt /tmp
transmission-create -o $TRANSMISSION_DL_DIR/nextcloudvmhanssonit.torrent -c "https://www.hanssonit.se/nextcloud-vm VERSION: $VERSION_TAG HUB: $VERSION_HUB" -t $(cat /tmp/trackers.txt) "$TRANSMISSION_DL_DIR"/"$NC_OVA"

# Seed it!
transmission-remote -n 'transmission:transmission' --torrent="$TRANSMISSION_DL_DIR/nextcloudvmhanssonit.torrent" -a "$TRANSMISSION_DL_DIR/nextcloudvmhanssonit.torrent" --start --verify

# Copy it to local NC account
install_if_not rsync
nextclouduser="$(input_box_flow "Please enter the Nextcloud user that you want to move the finished torrent file to:")"
rsync -av "$TRANSMISSION_DL_DIR"/nextcloudvmhanssonit.torrent /mnt/ncdata/"$nextclouduser"/files/
chown www-data:www-data /mnt/ncdata/"$nextclouduser"/files/nextcloudvmhanssonit.torrent
nextcloud_occ files:scan "$nextclouduser"
unset nextclouduser
