#!/bin/bash
# shellcheck disable=2034,2059
true
# shellcheck source=lib.sh
FIRST_IFACE=1 . <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)
unset FIRST_IFACE

# Tech and Me © - 2018, https://www.techandme.se/

# Check if root
root_check

# Not compatible
msg_box "ifupdown are deceperated in Ubuntu 18.04 and netplan.io is now used instead. 
We are working on a new way to set static IP but it may take a while since our time is limited.

Contributions are welcome!"
exit 1

# Download needed scripts for this to work
download_static_script ip
download_static_script test_connection

# VPS?
if [[ "no" == $(ask_yes_or_no "Do you run this script on a *remote* VPS like DigitalOcean, HostGator or similar?") ]]
then
    # Change IP
msg_box "OK, we assume you run this locally and we will now configure your IP to be static.

Your internal IP is: $ADDRESS

Write this down, you will need it to set static IP
in your router later. It's included in this guide:

https://www.techandme.se/open-port-80-443/ (step 1 - 5)"
    nmcli connection down id "$IFACE"
    wait
    nmcli connection up id "$IFACE"
    wait
    while true; do if [ $(nmcli networking connectivity check) == "full" ]; then echo "Connected!"; fi && break; done
    bash "$SCRIPTS/ip.sh"
    if [ -z "$IFACE" ]
    then
        echo "IFACE is an emtpy value. Trying to set IFACE with another method..."
        download_static_script ip2
        bash "$SCRIPTS/ip2.sh"
        rm -f "$SCRIPTS/ip2.sh"
    fi
    nmcli connection down id "$IFACE"
    wait
    nmcli connection up id "$IFACE"
    wait
    while true; do if [ $(nmcli networking connectivity check) == "full" ]; then echo "Connected!"; fi && break; done
    echo
    echo "Testing if network is OK..."
    echo
    CONTEST=$(bash $SCRIPTS/test_connection.sh)
    if [ "$CONTEST" == "Connected!" ]
    then
        # Connected!
        printf "${Green}Connected!${Color_Off}\n"
        sleep 1
msg_box "We have now set $ADDRESS as your static IP.

If you want to change it later then just edit the netplan.io YAML file:
sudo nano /etc/netplan/01-netcfg.yaml

If you experience any bugs, please report it here:
$ISSUES"
    else
        # Not connected!
msg_box "Not Connected!
You should change your settings manually in the next step.

Check this site for instructions on how to do it:
http://www.nazimkaradag.com/2017/10/17/set-a-static-ip-on-ubuntu-17-10-with-netplan/

We will put a example config for you when you hit OK, but please check the site to change it to your own values."

# Create example file
if [ ! -f /etc/netplan/01-netcfg.yaml ]
then
    touch /etc/netplan/01-netcfg.yaml
cat << NETWORK_CREATE > /etc/netplan/01-netcfg.yaml
Network: 
	version: 2 
	renderer: networkd
	ethernets:
		{$IFACE}: #object name
			dhcp4: no # dhcp v4 disable
			dhcp6: no # dhcp v6 disable
			addresses: [{$ADDRESS}/24] # client IP address
			gateway4: ${GATEWAY} # gateway adrdess
			nameservers:
				addresses: [9.9.9.9,149.112.112.112] #name servers
NETWORK_CREATE        
        any_key "Press any key to open /etc/netplan/01-netcfg.yaml..."
        nano /etc/netplan/01-netcfg.yaml
        netplan apply
        nmcli connection reload
        clear
        echo "Testing if network is OK..."
        nmcli connection down id "$IFACE"
        wait
        nmcli connection up id "$IFACE"
        wait
        bash "$SCRIPTS/test_connection.sh"
        wait
    fi
else
    echo "OK, then we will not set a static IP as your VPS provider already have setup the network for you..."
    sleep 5 & spinner_loading
fi
