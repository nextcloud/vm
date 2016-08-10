#!/bin/bash
WANIP4=$(dig +short myip.opendns.com @resolver1.opendns.com)
WANIP6=$(curl -s https://6.ifcfg.me/)
ADDRESS=$(hostname -I | cut -d ' ' -f 1) 
FIG=$(figlet -f small  NextBerry)
V=$(cat /var/scripts/version)

whiptail --msgbox "\
$FIG

https://www.nextcloud.com - https://www.techandme.se

        WAN IPv4: $WANIP4
        WAN IPv6: $WANIP6
        LAN IP:   $ADDRESS
        Version:  $V

Useful installer, in the next screen type: techandtool
Upgrade NextBerry, in the next screen type: nextberry-upgrade\
" 22 60 1
exit 0

