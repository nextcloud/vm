#!/bin/bash

# T&M Hansson IT AB © - 2023, https://www.hanssonit.se/
# GNU General Public License v3.0
# https://github.com/nextcloud/vm/blob/master/LICENSE

#########

## This doesn't seem to work in current state. help is welcome!

# Install dependencies
install_if_not transmission-cli
install_if_not transmission-daemon

# Download the VM
curl -fSLO --retry 3 https://download.kafit.se/s/dnkWptz8AK4JZDM/download
mv download NextcloudVM.zip

# Create torrent
transmission-create -o nextcloudvmhanssonit.torrent -c "https://www.hanssonit.se/nextcloud-vm" "$(for tracker in $(curl_to_dir "$GITHUB_REPO"/torrent trackers.txt /tmp && cat /tmp/trackers.txt); do echo -t "$tracker"; done)" NextcloudVM.zip

# Seed it!
transmission-remote -n 'transmission:transmission' -a nextcloudvmhanssonit.torrent
