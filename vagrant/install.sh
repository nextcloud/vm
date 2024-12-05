#!/bin/bash

true
SCRIPT_NAME="Install NcVM with Vagrant"

git clone https://github.com/nextcloud/vm.git

cd vm

sudo bash nextcloud_install_production.sh --provisioning
