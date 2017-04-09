#!/bin/bash

# Tech and Me © - 2017, https://www.techandme.se/

# shellcheck disable=2034,2059
true
# shellcheck source=lib.sh
WANIPv6=1 . <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/rewrite/lib.sh)
unset WANIPv6

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

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
