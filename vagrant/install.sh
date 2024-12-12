#!/bin/bash

true

# Clone this repo
git clone https://github.com/nextcloud/vm.git

# We need a check here due to Shellcheck
cd vm || exit

# Do the installation
sudo bash nextcloud_install_production.sh --provisioning
