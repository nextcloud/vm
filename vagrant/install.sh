#!/bin/bash

# shellcheck disable=2034,2059
true
SCRIPT_NAME="Install NcVM with Vagrant"
# shellcheck source=lib.sh
source <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)

install_if_not wget
check_command wget https://raw.githubusercontent.com/nextcloud/vm/master/nextcloud_install_production.sh

check_command sudo bash nextcloud_install_production.sh --provisioning

