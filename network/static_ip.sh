#!/bin/bash

# T&M Hansson IT AB © - 2024, https://www.hanssonit.se/

# Use local lib file in case there is no internet connection
if printf "Testing internet connection..." && ping github.com -c 2 >/dev/null 2>&1
then
true
SCRIPT_NAME="Static IP"
# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh
 # If we have internet, then use the latest variables from the lib remote file
elif [ -f /var/scripts/lib.sh ]
then
true
SCRIPT_NAME="Static IP"
# shellcheck source=lib.sh
source /var/scripts/lib.sh
else
    printf "You don't seem to have a working internet connection, and \
/var/scripts/lib.sh is missing so you can't run this script."
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

msg_box "Please note that if the IP address changes during an (remote) SSH connection \
(via Putty, or CLI for example), the connection will break and the IP will reset to \
DHCP or the IP you had before you started this script.

To avoid issues with lost connectivity, please use the VM Console directly, and not SSH."
if yesno_box_yes "Are you connected via SSH?"
then
    msg_box "Please use the VM Console instead."
    sleep 1
    exit
fi

# Loop until working network settings are validated or the user asks to quit
echo
while :
do
    # Loop until user is happy with the IP address and subnet
    echo
    while :
    do
        # Ask for IP address
    	LANIP=$(input_box "Please enter the static IP address you want to set, \
including the subnet.\nExample: 192.168.1.100/24")
        if [[ $LANIP == *"/"* ]]
        then
            if yesno_box_yes "Is this correct? $LANIP"
            then
                break
            fi
        else
            msg_box "Did you forget the /subnet?"
        fi
    done

    # Loop until user is happy with the default gateway
    echo
    while :
    do
        # Ask for domain name
        GATEWAYIP=$(input_box "Please enter the gateway address you want to set.
Just hit enter to choose the current gateway.\nYour current gateway is: $GATEWAY")
        if [ -z "$GATEWAYIP" ]
        then
            GATEWAYIP="$GATEWAY"
        fi
        if yesno_box_yes "Is this correct? $GATEWAYIP"
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

    if yesno_box_no "Do you want to set your own nameservers?"
    then
        # Loop until user is happy with the nameserver 1
        echo
        while :
        do
            # Ask for nameserver
            NSIP1=$(input_box "Please enter the local nameserver address you want to set.
Just hit enter to choose the current NS1.\nYour current NS1 is: $DNS1")
            if [ -z "$NSIP1" ]
            then
                NSIP1="$DNS1"
            fi
            if yesno_box_yes "Is this correct? $NSIP1"
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
        while :
        do
            # Ask for nameserver
            NSIP2=$(input_box "Please enter the local nameserver address you want to set. The 3 options are:
- Hit enter to choose the current NS2.\n- Enter a new IP address for NS2.
- Enter the text 'none' if you only have one NS.\nYour current NS2 is: $DISPLAY_DNS2")
            if [ -z "$NSIP2" ]
            then
                NSIP2="$DISPLAY_DNS2"
            fi
            if yesno_box_yes "Is this correct? $NSIP2"
            then
                break
            fi
        done
    fi

    # Check if DNS is set manually and set variables accordingly
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
         addresses:
         - $LANIP
         routes:
          - to: default
            via: $GATEWAYIP
         nameservers:
           addresses: [$DNSs]
IPCONFIG

        msg_box "These are your settings, please make sure they are correct:

$(cat /etc/netplan/nextcloud.yaml)"
        chmod 600 /etc/netplan/nextcloud.yaml
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
         addresses:
         - $LANIP
         routes:
          - to: default
            via: $GATEWAYIP
         nameservers:
           addresses: [$DNSs]
IPCONFIGnonvmware

        msg_box "These are your settings, please make sure they are correct:

$(cat /etc/netplan/nextcloud.yaml)"
        chmod 600 /etc/netplan/nextcloud.yaml
        netplan try
        set_systemd_resolved_dns "$IFACE2"
    fi

    if test_connection
    then
        sleep 1
        msg_box "Static IP successfully set!"
        rm -f /etc/netplan/00-installer-config.yaml
        break
    fi

    cat << BADNETWORKTEXT

The network settings do not provide access to the Internet and/or the DNS
servers are not reachable. Unless Wi-Fi is required and still to be configured
proceeding will not succeed.

BADNETWORKTEXT
    if ! yesno_box_yes "Try new network settings?"
    then
        break
    fi
done
