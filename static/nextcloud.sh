#!/bin/bash
WANIP4=$(dig +short myip.opendns.com @resolver1.opendns.com)
WANIP6=$(curl -s https://6.ifcfg.me/)
ADDRESS=$(hostname -I | cut -d ' ' -f 1)
clear
figlet -f small Nextcloud
echo "           https://www.nextcloud.com"
echo
echo
echo
echo "WAN IPv4: $WANIP4"
echo "WAN IPv6: $WANIP6"
echo "LAN IP: $ADDRESS"
echo
exit 0
