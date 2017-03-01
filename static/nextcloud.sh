#!/bin/bash
WANIP4=$(wget -q -T 10 -t 2 ipinfo.io/ip -m 5)
WANIP6=$(wget -q -T 10 -t 2 6.ifcfg.me -m 5)
ADDRESS=$(hostname -I | cut -d ' ' -f 1)
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
