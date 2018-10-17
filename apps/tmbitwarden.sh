#!/bin/bash

# T&M Hansson IT AB © - 2018, https://www.hanssonit.se/

echo "Installing Bitwarden password manager..."

# shellcheck disable=2034,2059
true
# shellcheck source=lib.sh
. <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Check if root
root_check

msg_box "Bitwarden is a password manager that is seperate from Nextcloud, though we provide this service because it's self hosted and secure.

Please note that this script is not fully automated since you need to add your on keys for it to work.
You will be instructed during the script is run on all the steps needed for it to work.
You can get your install keys here: https://bitwarden.com/host/

The script is based on this documentation: https://help.bitwarden.com/article/install-on-premise/
It's a good idea to read that before you start this script."

# Test RAM size (2GB min) + CPUs (min 2)
ram_check 2 Bitwarden
cpu_check 2 Bitwarden

# Install Docker
install_docker
install_if_not docker-compose

# Install Bitwarden
install_if_not curl
curl -s -o bitwarden.sh \
    https://raw.githubusercontent.com/bitwarden/core/master/scripts/bitwarden.sh \
    && chmod +x bitwarden.sh
check_command ./bitwarden.sh install
check_command ./bitwarden.sh start
if check_command ./bitwarden.sh updatedb
then
msg_box "Bitwarden was sucessfully installed!"
fi
