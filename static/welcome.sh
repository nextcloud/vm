#!/bin/bash

# T&M Hansson IT AB © - 2021, https://www.hanssonit.se/

WANIP6=$(curl -s -k -m 5 -6 icanhazip.com)
WANIP4=$(curl -s -k -m 5 -4 icanhazip.com)
ADDRESS=$(hostname -I | cut -d ' ' -f 1)

clear
figlet -f small Nextcloud
echo "https://github.com/nextcloud/vm"
echo
echo
echo "Hostname: $(hostname -s)"
echo "WAN IPv4: $WANIP4"
echo "WAN IPv6: $WANIP6"
echo "LAN IPv4: $ADDRESS"
echo
exit 0
