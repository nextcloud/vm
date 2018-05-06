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
    test_connection
    bash "$SCRIPTS/ip.sh"
    if [ -z "$IFACE" ]
    then
        echo "IFACE is an emtpy value. Trying to set IFACE with another method..."
        download_static_script ip2
        bash "$SCRIPTS/ip2.sh"
        rm -f "$SCRIPTS/ip2.sh"
    fi
    if network_ok
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
https://netplan.io/examples

We will put a example config for you when you hit OK, but please check the site to change it to your own values."
        any_key "Press any key to open /etc/netplan/01-netcfg.yaml..."
        nano /etc/netplan/01-netcfg.yaml
        netplan apply
        test_connection
    fi
else
    echo "OK, then we will not set a static IP as your VPS provider already have setup the network for you..."
    sleep 5 & spinner_loading
fi
