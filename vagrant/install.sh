#!/bin/bash

true
SCRIPT_NAME="Install NcVM with Vagrant"

# Clone this repo
git clone https://github.com/nextcloud/vm.git

# We need a check here due to Shellcheck
if [ -d vm ]
then
    cd vm || exit
else
    echo "Sorry, but the 'cd' dir doesn't exist, please report this issue to https://github.com/nextcloud/vm/"
    exit
fi

# Do the installation
sudo bash nextcloud_install_production.sh --provisioning
