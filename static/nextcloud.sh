#!/bin/bash

# T&M Hansson IT AB © - 2020, https://www.hanssonit.se/

WANIP6=$(curl -s -k -m 5 https://ipv6bot.whatismyipaddress.com)
WANIP4=$(curl -s -k -m 5 https://ipv4bot.whatismyipaddress.com)
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
