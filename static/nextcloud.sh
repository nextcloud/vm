#!/bin/bash

. <(curl -sL https://cdn.rawgit.com/morph027/vm/color-vars/lib.sh)
WANIP4=$(curl -s -m 5 ipinfo.io/ip)
WANIP6=$(curl -s -m 5 6.ifcfg.me)
clear
figlet -f small Nextcloud
echo "     https://www.nextcloud.com"
echo
echo
echo "Hostname: $(hostname -s)"
echo "WAN IPv4: $WANIP4"
echo "WAN IPv6: $WANIP6"
echo "LAN IPv4: $ADDRESS"
echo
exit 0
