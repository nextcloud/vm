#!/bin/bash

# T&M Hansson IT AB © - 2021, https://www.hanssonit.se/

true
SCRIPT_NAME="PN51 Network Drivers"
SCRIPT_EXPLAINER="This installs the correct drivers for the 2.5GB LAN card in the PN51 ASUS"
# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh || source <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Check if root
root_check

# Only intended for the ASUS PN51 NUC
if ! asuspn51
then
    exit
fi

INSTALLDIR="$SCRIPTS/PN51"

mkdir -p $INSTALLDIR

# Install dependencies
install_if_not build-essential

# Download and extract
if [ ! -f $INSTALLDIR/r8125-9.005.06.tar.bz2 ]
then
    curl_to_dir https://github.com/nextcloud/vm/raw/master/network/asusnuc r8125-9.005.06.tar.bz2 "$INSTALLDIR"
fi

if [ ! -d "$INSTALLDIR/r8125-9.005.06" ]
then
    check_command cd "$INSTALLDIR"
    check_command tar -xf r8125-9.005.06.tar.bz2
fi

# Install
if [ -d "$INSTALLDIR/r8125-9.005.06" ]
then
    check_command cd "$INSTALLDIR/r8125-9.005.06"
    bash autorun.sh
else
    msg_box "$INSTALLDIR/r8125-9.005.06 doesn't seem to exist, is the tar-package extracted?"
    exit 1
fi

# Remove the folder, keep the tar
rm -rf "$INSTALLDIR/r8125-9.005.06"

# Add new interface in netplan
cat <<-IPCONFIG > "$INTERFACES"
network:
   version: 2
   ethernets:
       enp2s0:
         dhcp4: true
         dhcp6: true
IPCONFIG

# Apply config
netplan apply
dhclient
