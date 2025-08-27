#!/bin/bash

# T&M Hansson IT AB © - 2024, https://www.hanssonit.se/

WANIP6=$(curl -s -k -m 5 -6 https://api64.ipify.org)
WANIP4=$(curl -s -k -m 5 -4 https://api64.ipify.org)
ADDRESS=$(hostname -I | cut -d ' ' -f 1)

clear
figlet -f small Nextcloud
echo "https://www.hanssonit.se/nextcloud-vm"
echo
echo
echo "FQDN: $(hostname -f)"
echo "WAN IPv4: $WANIP4"
echo "WAN IPv6: $WANIP6"
echo "LAN IPv4: $ADDRESS"
echo
exit 0
