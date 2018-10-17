#!/bin/bash

# T&M Hansson IT AB © - 2018, https://www.hanssonit.se/

# shellcheck disable=2034,2059
true
# shellcheck source=lib.sh
FIRST_IFACE=1 . <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)
unset FIRST_IFACE

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

clear

# Copy old interfaces file
msg_box "Copying old netplan.io config file file to:

/tmp/01-netcfg.yaml_backup"
check_command cp -v /etc/netplan/01-netcfg.yaml /tmp/01-netcfg.yaml_backup

echo
while true
do
# Ask for domain name
cat << ENTERIP
+-------------------------------------------------------------+
|    Please enter the static IP address you want to set,      |
|    including the subnet. Like this: 192.168.1.100/24        |
+-------------------------------------------------------------+
ENTERIP
echo
read -r LANIP
echo
if [[ "yes" == $(ask_yes_or_no "Is this correct? $LANIP") ]]
then
    break
fi
done

echo
while true
do
# Ask for domain name
cat << ENTERGATEWAY
+-------------------------------------------------------------+
|    Please enter the gateway address you want to set,        |
|    Like this: 192.168.1.1                                   |
+-------------------------------------------------------------+
ENTERGATEWAY
echo
read -r GATEWAYIP
echo
if [[ "yes" == $(ask_yes_or_no "Is this correct? $GATEWAYIP") ]]
then
    break
fi
done

# Check if IFACE is empty, if yes, try another method:
if ! [ -z "$IFACE" ]
then
cat <<-IPCONFIG > "$INTERFACES"
network:
   version: 2
   renderer: networkd
   ethernets:
       $IFACE: #object name
         dhcp4: no # dhcp v4 disable
         dhcp6: no # dhcp v6 disable
         addresses: [$LANIP] # client IP address
         gateway4: $GATEWAYIP # gateway address
         nameservers:
           addresses: [$DNS1,$DNS2] #name servers
IPCONFIG

msg_box "These are your settings, please make sure they are correct:

$(cat /etc/netplan/01-netcfg.yaml)"
    netplan try
else
cat <<-IPCONFIGnonvmware > "$INTERFACES"
network:
   version: 2
   renderer: networkd
   ethernets:
       $IFACE2: #object name
         dhcp4: no # dhcp v4 disable
         dhcp6: no # dhcp v6 disable
         addresses: [$ADDRESS/24] # client IP address
         gateway4: $GATEWAY # gateway address
         nameservers:
           addresses: [$DNS1,$DNS2] #name servers
IPCONFIGnonvmware
msg_box "These are your settings, please make sure they are correct:

$(cat /etc/netplan/01-netcfg.yaml)"
    netplan try
fi

if test_connection
then
    sleep 1
    msg_box "Static IP sucessfully set!"
fi
