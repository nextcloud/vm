#!/bin/bash

# T&M Hansson IT AB © - 2021, https://www.hanssonit.se/
# Copyright © 2021 Simon Lindner (https://github.com/szaimen)

true
SCRIPT_NAME="PN51 Network Drivers"
SCRIPT_EXPLAINER="This installs the correct drivers for the 2.5GB LAN card in the PN51 ASUS"
# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh || source <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Check if root
root_check

# Only intended for our NUCs
if ! home_sme_server
then
    exit
fi

# Install dependencies
install_if_not build-essentials

# Download and extract
curl_to_dir https://github.com/nextcloud/vm/blob/pn51/network r8125-9.005.06.tar.bz2 "$SCRIPTS"
check_command cd "$SCRIPTS"
check_command tar-xf r8125-9.005.06.tar.bz2

# Install
check_command cd "$SCRIPTS"/r8125-9.005.06
bash autorun

# Add new interface in netplan
cat <<-IPCONFIG > "$INTERFACES"
network:
   version: 2
   ethernets:
       enp2s0:
         dhcp4: true
         dhcp6: true
IPCONFIG

# Apply config
netplan apply
dhclient
