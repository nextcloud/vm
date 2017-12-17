#!/bin/bash

# Tech and Me © - 2017, https://www.techandme.se/

<<<<<<< HEAD
# shellcheck disable=2034,2059
true
# shellcheck source=lib.sh
LOAD_IP6=1 . <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/postgresql/lib.sh)
unset LOAD_IP6

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode
=======
WANIP6=$(curl -s -k -m 7 https://6.ifcfg.me)
WANIP4=$(curl -s -m 5 ipinfo.io/ip)
ADDRESS=$(hostname -I | cut -d ' ' -f 1)
>>>>>>> bb612fe... more msg_box (#429)

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
