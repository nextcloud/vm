#!/bin/bash

# Tech and Me © - 2017, https://www.techandme.se/

# shellcheck disable=2034,2059
true
# shellcheck source=lib.sh
. <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Download and install Calendar
if [ -d /etc/netdata ]
then
    echo "Netdata seems to be installed."
    if [[ "yes" == $(ask_yes_or_no "Do you wich to uninstall Netdata prior to installing it again?") ]]
    then
        bash /usr/src/netdata.git/netdata-uninstaller.sh --force -y
        userdel netdata
        groupdel netdata
        gpasswd -d netdata adm
        gpasswd -d netdata proxy
    else
        is_process_running dpkg
        is_process_running apt
        apt update -q & spinner_loading
        sudo -u "$UNIXUSER" bash <(curl -Ss https://my-netdata.io/kickstart.sh) all --dont-wait
    fi
fi

# Installation done?
if [ -d /etc/netdata ]
then
msg_box "Netdata is now installed and can be accessed from these addresses:

$ADDRESS:19999
$(hostname):19999

You can find more configuraotion options in their wiki:
https://github.com/firehol/netdata/wiki/Configuration"

# Cleanup
rm -f /tmp/netdata*
fi

exit


