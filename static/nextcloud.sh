#!/bin/bash

# T&M Hansson IT AB © - 2018, https://www.hanssonit.se/

WANIP6=$(curl -s -k -m 7 ipv6bot.whatismyipaddress.com)
WANIP4=$(curl -s -m 5 ipv4bot.whatismyipaddress.com)
ADDRESS=$(hostname -I | cut -d ' ' -f 1)

clear
figlet -f small Nextcloud
echo "https://www.hanssonit.se/nextcloud-vm"
echo
echo
echo "Hostname: $(hostname -s)"
echo "WAN IPv4: $WANIP4"
echo "WAN IPv6: $WANIP6"
echo "LAN IPv4: $ADDRESS"
echo
exit 0
