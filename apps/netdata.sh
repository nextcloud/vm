#!/bin/bash

# T&M Hansson IT AB © - 2020, https://www.hanssonit.se/

# shellcheck disable=2034,2059
true
# shellcheck source=lib.sh
. <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)

print_text_in_color "$ICyan" "Installing Netdata..."

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Download and install Netdata
if [ -d /etc/netdata ]
then
msg_box "Netdata seems to be installed.
We will now remove Netdata and reinstall the latest stable version"
    # Uninstall
    if [ -f /usr/src/netdata.git/netdata-uninstaller.sh ]
    then
        if ! yes | bash /usr/src/netdata.git/netdata-uninstaller.sh --force
        then
            rm -Rf /usr/src/netdata.git
        fi
    elif [ -f /usr/libexec/netdata-uninstaller.sh ]
    then
        yes | bash /usr/libexec/netdata-uninstaller.sh --yes
    fi
    userdel netdata
    groupdel netdata
    gpasswd -d netdata adm
    gpasswd -d netdata proxy
    # Install
    is_process_running dpkg
    is_process_running apt
    apt update -q4 & spinner_loading
    curl_to_dir https://my-netdata.io kickstart.sh $SCRIPTS
    sudo -u "$UNIXUSER" bash $SCRIPTS/kickstart.sh all --dont-wait --no-updates --stable-channel
    rm -f $SCRIPTS/kickstart.sh
else
    # Install
    is_process_running dpkg
    is_process_running apt
    apt update -q4 & spinner_loading
    curl_to_dir https://my-netdata.io kickstart.sh $SCRIPTS
    sudo -u "$UNIXUSER" bash $SCRIPTS/kickstart.sh all --dont-wait --no-updates --stable-channel
    rm -f $SCRIPTS/kickstart.sh
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
https://docs.netdata.cloud/daemon/config#configuration-guide"

# Cleanup
rm -rf /tmp/netdata*
fi

exit
