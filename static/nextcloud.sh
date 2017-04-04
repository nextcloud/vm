#!/bin/bash
# shellcheck disable=2034,2059
true
# shellcheck source=lib.sh


. <(curl -sL https://cdn.rawgit.com/morph027/vm/master/lib.sh)
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
