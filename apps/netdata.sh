#!/bin/bash

# T&M Hansson IT AB © - 2024, https://www.hanssonit.se/

true
SCRIPT_NAME="Netdata"
SCRIPT_EXPLAINER="Netdata is an open source tool designed to collect real-time metrics, \
such as CPU usage, disk activity, bandwidth usage, website visits, etc., \
and then display them in live, easy-to-interpret charts.
The tool is designed to visualize activity in the greatest possible detail, \
allowing the user to obtain an overview of what is happening \
and what has just happened in their system or application."
# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Must be sudo
root_check

# Check if netdata is already installed
if ! [ -d /etc/netdata ]
then
    # Ask for installing
    install_popup "$SCRIPT_NAME"
else
    # Ask for removal or reinstallation
    reinstall_remove_menu "$SCRIPT_NAME"
    # Removal
    touch /etc/netdata/.environment
    if [ -f /usr/src/netdata.git/netdata-uninstaller.sh ]
    then
        if ! yes no | bash /usr/src/netdata.git/netdata-uninstaller.sh -y -f
        then
            rm -Rf /usr/src/netdata.git
        fi
    elif [ -f /usr/libexec/netdata-uninstaller.sh ]
    then
        yes no | bash /usr/libexec/netdata-uninstaller.sh -y -f
    elif [ -f /usr/libexec/netdata/netdata-uninstaller.sh ]
    then
        bash /usr/libexec/netdata/netdata-uninstaller.sh -y -f
    else
        curl_to_dir https://raw.githubusercontent.com/netdata/netdata/master/packaging/installer netdata-uninstaller.sh $SCRIPTS
        check_command bash $SCRIPTS/netdata-uninstaller.sh -y -f
        rm $SCRIPTS/netdata-uninstaller.sh
        rm -rf /var/lib/netdata
    fi
    rm -rf /etc/netdata
    apt-get purge netdata -y
    apt-get autoremove -y
    rm -rf /var/cache/netdata
    rm -rf /var/log/netdata
    # Show successful uninstall if applicable
    removal_popup "$SCRIPT_NAME"
fi

# Install
is_process_running dpkg
is_process_running apt
apt-get update -q4 & spinner_loading
curl_to_dir https://get.netdata.cloud kickstart.sh $SCRIPTS
bash $SCRIPTS/kickstart.sh --reinstall-even-if-unsafe --non-interactive --no-updates --stable-channel --disable-cloud
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
