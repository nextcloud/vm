#!/bin/bash
# shellcheck disable=2034,2059
true
# shellcheck source=lib.sh
FIRST_IFACE=1 . <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)
unset FIRST_IFACE

# Tech and Me © - 2018, https://www.techandme.se/

# Check if root
root_check

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
    ifdown "$IFACE"
    wait
    ifup "$IFACE"
    wait
    bash "$SCRIPTS/ip.sh"
    if [ -z "$IFACE" ]
    then
        echo "IFACE is an emtpy value. Trying to set IFACE with another method..."
        download_static_script ip2
        bash "$SCRIPTS/ip2.sh"
        rm -f "$SCRIPTS/ip2.sh"
    fi
    ifdown "$IFACE"
    wait
    ifup "$IFACE"
    wait
    echo
    echo "Testing if network is OK..."
    echo
    CONTEST=$(bash $SCRIPTS/test_connection.sh)
    if [ "$CONTEST" == "Connected!" ]
    then
        # Connected!
        printf "${Green}Connected!${Color_Off}\n"
msg_box "We will use the DHCP IP: $ADDRESS

If you want to change it later then just edit the interfaces file:
sudo nano /etc/network/interfaces

If you experience any bugs, please report it here:
$ISSUES"
    else
        # Not connected!
        printf "${Red}Not Connected${Color_Off}\nYou should change your settings manually in the next step.\n"
        any_key "Press any key to open /etc/network/interfaces..."
        nano /etc/network/interfaces
        service networking restart
        clear
        echo "Testing if network is OK..."
        ifdown "$IFACE"
        wait
        ifup "$IFACE"
        wait
        bash "$SCRIPTS/test_connection.sh"
        wait
    fi
else
    echo "OK, then we will not set a static IP as your VPS provider already have setup the network for you..."
    sleep 5 & spinner_loading
fi
