#!/bin/bash

# shellcheck disable=2034,2059
true
SCRIPT_NAME="Install NcVM with Vagrant"
# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh || source <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)

check_command git clone https://github.com/nextcloud/vm.git

cd vm || exit && print_text_in_color "$IRed" "Could not cd into the 'vm' folder."

yes no | sudo bash nextcloud_install_production.sh

