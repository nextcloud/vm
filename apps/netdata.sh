#!/bin/bash

# T&M Hansson IT AB © - 2020, https://www.hanssonit.se/

# shellcheck disable=2034,2059
true
# shellcheck source=lib.sh
. <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Check if Netdata ist already installed
print_text_in_color "$ICyan" "Checking if Netdata is already installed..."
if [ -d /etc/netdata ]
then
    msg_box "It seems like 'Netdata' is already installed.\nIf you continue, Netdata will get deleted."
    if [[ "no" == $(ask_yes_or_no "Do you really want to continue?") ]]
    then
        exit
    fi
    # Uninstall
    check_command curl_to_dir https://raw.githubusercontent.com/netdata/netdata/master/packaging/installer netdata-uninstaller.sh $SCRIPTS
    check_command bash $SCRIPTS/netdata-uninstaller.sh --force --yes
    rm $SCRIPTS/netdata-uninstaller.sh
    msg_box "Netdata was successfully uninstalled."
    exit
fi

# Install
print_text_in_color "$ICyan" "Installing Netdata..."
is_process_running dpkg
is_process_running apt
apt update -q4 & spinner_loading
curl_to_dir https://my-netdata.io kickstart.sh $SCRIPTS
sudo -u "$UNIXUSER" bash $SCRIPTS/kickstart.sh all --dont-wait --no-updates --stable-channel
rm -f $SCRIPTS/kickstart.sh

# Check Netdata instructions after script is done
any_key "Please check information above and press any key to continue..."

# Installation done?
if [ -d /etc/netdata ]
then
msg_box "Netdata is now installed and can be accessed from this address:

http://$ADDRESS:19999

If you want to reach it from the internet you need to open port 19999 in your firewall.
If you don't know how to open ports, please follow this guide:
https://www.techandme.se/open-port-80-443/

After you have opened the correct port, then you can visit Netdata from your domain:

http://$(hostname -f):19999 and or http://yourdomanin.com:19999

You can find more configuration options in their WIKI:
https://docs.netdata.cloud/daemon/config#configuration-guide"

# Cleanup
rm -rf /tmp/netdata*
fi

exit
