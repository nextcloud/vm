#!/bin/bash

# Tech and Me © - 2017, https://www.techandme.se/

echo "Installing Netdata..."

# shellcheck disable=2034,2059
true
# shellcheck source=lib.sh
. <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Download and install Netdata
if [ -d /etc/netdata ]
then
msg_box "Netdata seems to be installed.
We will now remove Netdata and reinstall it with the latest master."
    # Uninstall
    echo yes | bash /usr/src/netdata.git/netdata-uninstaller.sh --force
    userdel netdata
    groupdel netdata
    gpasswd -d netdata adm
    gpasswd -d netdata proxy
    # Install
    is_process_running dpkg
    is_process_running apt
    apt update -q4 & spinner_loading
    sudo -u "$UNIXUSER" "$(bash <(curl -Ss https://my-netdata.io/kickstart.sh) all --dont-wait)"
else
    # Install
    is_process_running dpkg
    is_process_running apt
    apt update -q4 & spinner_loading
    sudo -u "$UNIXUSER" "$(bash <(curl -Ss https://my-netdata.io/kickstart.sh) all --dont-wait)"
fi

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
https://github.com/firehol/netdata/wiki/Configuration"

# Cleanup
rm -rf /tmp/netdata*
fi
clear

exit


