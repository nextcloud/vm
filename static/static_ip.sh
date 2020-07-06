#!/bin/bash

# T&M Hansson IT AB © - 2020, https://www.hanssonit.se/

IRed='\e[0;91m'         # Red
ICyan='\e[0;96m'        # Cyan
Color_Off='\e[0m'       # Text Reset
print_text_in_color() {
	printf "%b%s%b\n" "$1" "$2" "$Color_Off"
}

# Use local lib file in case there is no internet connection
if [ -f /var/scripts/lib.sh ]
then
# shellcheck disable=2034,2059
true
# shellcheck source=lib.sh
FIRST_IFACE=1 source /var/scripts/lib.sh
unset FIRST_IFACE
 # If we have internet, then use the latest variables from the lib remote file
elif printf "Testing internet connection..." && ping github.com -c 2
then
# shellcheck disable=2034,2059
true
# shellcheck source=lib.sh
FIRST_IFACE=1 . <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)
unset FIRST_IFACE
else
    printf "You don't seem to have a working internet connection, and /var/scripts/lib.sh is missing so you can't run this script."
    printf "Please report this to https://github.com/nextcloud/vm/issues/"
    exit 1
fi

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

# Loop until working network settings are validated or the user asks to quit
echo
while true
do
    # Loop until user is happy with the IP address and subnet
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

    # Loop until user is happy with the default gateway
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
able to get any deb packages, download files, or reach the internet.

The current nameservers are:
$DNS1
$DNS2
"

    # Set the variable used to fill in the Netplan nameservers. The existing
    # values are used if the user does not decides not to update the nameservers.
    DNSs="$DNS1"
    # Only add a second nameserver to the list if it is defined.
    if [ -n "$DNS2" ]
    then
        DNSs="$DNS1,$DNS2"
    fi

    if [[ "yes" == $(ask_yes_or_no "Do you want to set your own nameservers?") ]]
    then
        # Loop until user is happy with the nameserver 1
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

        # Nameserver 2 might be empty. As this will not be clear
        # in prompts, 'none' is used in this case.
        DISPLAY_DNS2="$DNS2"
        if [ -z "$DISPLAY_DNS2" ]
        then
            DISPLAY_DNS2="'none'"
        fi

        # Loop until user is happy with the nameserver 2
        echo
        while true
        do
            # Ask for nameserver
            cat << ENTERNS2
+-------------------------------------------------------+
|    Please enter the local nameserver address you want |
|    to set. The 3 options are:                         |
|    - Hit enter to choose the current NS2.             |
|    - Enter a new IP address for NS2.                  |
|    - Enter the text 'none' if you only have one NS.   |
|    Your current NS2 is: $DISPLAY_DNS2               |
+-------------------------------------------------------+
ENTERNS2
            echo
            read -r NSIP2
            echo
            if [ -z "$NSIP2" ]
            then
                NSIP2="$DISPLAY_DNS2"
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
        DNSs="$NSIP1"
        # Only add a second nameserver to the list if it is defined and not 'none'.
        if [[ -n "$NSIP2" && ! ( "none" == "$NSIP2" || "'none'" == "$NSIP2" ) ]]
        then
            DNSs="$NSIP1,$NSIP2"
        fi
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
           addresses: [$DNSs] #name servers
IPCONFIG

        msg_box "These are your settings, please make sure they are correct:

$(cat /etc/netplan/01-netcfg.yaml)"
        netplan try
        set_systemd_resolved_dns "$IFACE"
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
           addresses: [$DNSs] #name servers
IPCONFIGnonvmware

        msg_box "These are your settings, please make sure they are correct:

$(cat /etc/netplan/01-netcfg.yaml)"
        netplan try
        set_systemd_resolved_dns "$IFACE2"
    fi

    if test_connection
    then
        sleep 1
        msg_box "Static IP sucessfully set!"
        break
    fi

    cat << BADNETWORKTEXT

The network settings do not provide access to the Internet and/or the DNS
servers are not reachable. Unless Wi-Fi is required and still to be configured
proceeding will not succeed.

BADNETWORKTEXT
    if [[ "no" == $(ask_yes_or_no "Try new network settings?") ]]
    then
        break
    fi
done
