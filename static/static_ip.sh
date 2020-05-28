#!/bin/bash

# T&M Hansson IT AB © - 2020, https://www.hanssonit.se/

IRed='\e[0;91m'         # Red
ICyan='\e[0;96m'        # Cyan
Color_Off='\e[0m'       # Text Reset
print_text_in_color() {
	printf "%b%s%b\n" "$1" "$2" "$Color_Off"
}

# shellcheck disable=2034,2059
true
# shellcheck source=lib.sh
source /var/scripts/main/lib.sh &>/dev/null || . <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh) &>/dev/null

# Get needed variables
first_iface

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Must be root
root_check

# Check Ubuntu version
check_distro_version

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
        if [[ "yes" == $(ask_yes_or_no "Is this correct? $LANIP") ]]
        then
            break
        fi
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
|    Please enter the gateway address you want to set.  |
|    Just hit enter to choose the current gateway.      |
|    Your current gateway is: $GATEWAY               |
+-------------------------------------------------------+
ENTERGATEWAY
    echo
    read -r GATEWAYIP
    echo
    if [ -z "$GATEWAYIP" ]
    then
        GATEWAYIP="$GATEWAY"
    fi
    if [[ "yes" == $(ask_yes_or_no "Is this correct? $GATEWAYIP") ]]
    then
        break
    fi
done

# DNS
msg_box "You will now be provided with the option to set your own local DNS.

If you're not sure what DNS is, or if you don't have a local DNS server,
please don't touch this setting.

If something goes wrong here, you will not be
able to get any deb packages, download files, or reach internet.

The default nameservers are:
$DNS1
$DNS2
"

if [[ "yes" == $(ask_yes_or_no "Do you want to set your own nameservers?") ]]
then
    echo
    while true
    do
        # Ask for nameserver
        cat << ENTERNS1
+-------------------------------------------------------+
|    Please enter the local nameserver address you want |
|    to set. Just hit enter to choose the current NS1.  |
|    Your current NS1 is: $DNS1                       |
+-------------------------------------------------------+
ENTERNS1
        echo
        read -r NSIP1
        echo
        if [ -z "$NSIP1" ]
        then
            NSIP1="$DNS1"
        fi
        if [[ "yes" == $(ask_yes_or_no "Is this correct? $NSIP1") ]]
        then
            break
        fi
    done

    echo
    while true
    do
        # Ask for nameserver
        cat << ENTERNS2
+-------------------------------------------------------+
|    Please enter the local nameserver address you want |
|    to set. Just hit enter to choose the current NS2.  |
|    Your current NS2 is: $DNS2               |
+-------------------------------------------------------+
ENTERNS2
        echo
        read -r NSIP2
        echo
        if [ -z "$NSIP2" ]
        then
            NSIP2="$DNS2"
        fi
        if [[ "yes" == $(ask_yes_or_no "Is this correct? $NSIP2") ]]
        then
            break
        fi
    done
fi

# Check if DNS is set manaully and set variables accordingly
if [ -n "$NSIP1" ]
then
    DNS1="$NSIP1"
fi

if [ -n "$NSIP2" ]
then
    DNS2="$NSIP2"
fi

# Check if IFACE is empty, if yes, try another method:
if [ -n "$IFACE" ]
then
    cat <<-IPCONFIG > "$INTERFACES"
network:
   version: 2
   ethernets:
       $IFACE: #object name
         dhcp4: false # dhcp v4 disable
         dhcp6: false # dhcp v6 disable
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
   ethernets:
       $IFACE2: #object name
         dhcp4: false # dhcp v4 disable
         dhcp6: false # dhcp v6 disable
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
