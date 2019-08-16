#!/bin/bash

# T&M Hansson IT AB © - 2019, https://www.hanssonit.se/

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

# Must be root
root_check

# Check Ubuntu version
check_distro_version

clear

# Copy old interfaces files
msg_box "Copying old netplan.io config files file to:

/tmp/netplan_io_backup/"
if [ -d /etc/netplan/ ]
then
    mkdir -p /tmp/netplan_io_backup
    check_command cp -vR /etc/netplan/* /tmp/netplan_io_backup/
fi

msg_box "Please note that if the IP address changes during an (remote) SSH connection (via Putty, or terminal for example), the connection will break and the IP will reset to DHCP or the IP you had before you started this script.

To avoid issues with lost connectivity, please use the VM Console directly, and not SSH."
if [[ "yes" == $(ask_yes_or_no "Are you connected via SSH?") ]]
then
    print_text_in_color "$IRed" "Please use the VM Console instead."
    sleep 1
    exit
fi

echo
while true
do
    # Ask for IP address
    cat << ENTERIP
+----------------------------------------------------------+
|    Please enter the static IP address you want to set,   |
|    including the subnet. Example: 192.168.1.100/24       |
+----------------------------------------------------------+
ENTERIP
    echo
    read -r LANIP
    echo

    if [[ $LANIP == *"/"* ]]
    then
        break
    else
        print_text_in_color "$IRed" "Did you forget the /subnet?"
    fi
done

echo
while true
do
    # Ask for domain name
    cat << ENTERGATEWAY
+-------------------------------------------------------+
|    Please enter the gateway address you want to set,  |
|    Your current gateway is: $GATEWAY               |
+-------------------------------------------------------+
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
if [ -n "$IFACE" ]
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
