#!/bin/bash
WANIP=$(dig +short myip.opendns.com @resolver1.opendns.com)
ADDRESS=$(hostname -I | cut -d ' ' -f 1)
clear
figlet -f small Nextcloud
echo "           https://nextcloud.com/"
echo
echo
echo
echo "WAN IP: $WANIP"
echo "LAN IP: $ADDRESS"
echo
exit 0
