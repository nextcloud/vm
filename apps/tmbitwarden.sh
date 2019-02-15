#!/bin/bash

# T&M Hansson IT AB © - 2018, https://www.hanssonit.se/

# shellcheck disable=2034,2059
true
# shellcheck source=lib.sh
. <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)

print_text_in_color "$ICyan" "Installing Bitwarden password manager..."

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Check if root
root_check

msg_box "Bitwarden is a password manager that is seperate from Nextcloud, though we provide this service because it's self hosted and secure.

If you just want to run Bitwarden locally (not connecting your smartphone) then you can use 'localhost' as domain.
If you on the other hand want to run this on a domain, then please create a DNS record and point it to this server.
We'll add support for SSL in a later version of this script, but for now you have to do that stuff manually.

The script is based on this documentation: https://help.bitwarden.com/article/install-on-premise/
It's a good idea to read that before you start this script."

if [[ "no" == $(ask_yes_or_no "Have you made the necessary preparations?") ]]
then
msg_box "OK, please do the necessary preparations before you run this script and then simply run it again once you're done.
The script is located at: $SCRIPTS/apps/tmbitwarden.sh"
    exit
else
    sleep 0.1
fi

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
