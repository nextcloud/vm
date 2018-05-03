#!/bin/bash

# Tech and Me © - 2018, https://www.techandme.se/

# shellcheck disable=2034,2059
true
# shellcheck source=lib.sh
FIRST_IFACE=1 . <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/postgresql/lib.sh)
unset FIRST_IFACE

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Copy old interfaces file
msg_box "Copying old interfaces file to:

/tmp/interfaces.backup"
check_command cp -v /etc/network/interfaces /tmp/interfaces.backup

# Check if this is VMware:
install_if_not virt-what
if [ "$(virt-what)" == "vmware" ]
then
cat <<-IPCONFIG > "$INTERFACES"
network: 
   version: 2 
   renderer: networkd
   ethernets:
       $IFACE: #object name
       dhcp4: no # dhcp v4 disable
       dhcp6: no # dhcp v6 disable
       addresses: [$ADDRESS/24] # client IP address
       gateway4: $GATEWAY # gateway address
       nameservers:
         addresses: [$DNS1,$DNS2] #name servers
IPCONFIG
else
cat <<-IPCONFIGnonvmware > "$INTERFACES"
network: 
   version: 2 
   renderer: networkd
   ethernets:
       $IFACE: #object name
       dhcp4: no # dhcp v4 disable
       dhcp6: no # dhcp v6 disable
       addresses: [$ADDRESS/24] # client IP address
       gateway4: $GATEWAY # gateway address
       nameservers:
         addresses: [$DNS1,$DNS2] #name servers
IPCONFIGnonvmware
fi

exit 0
