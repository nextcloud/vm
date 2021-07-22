#!/bin/bash

# T&M Hansson IT AB © - 2021, https://www.hanssonit.se/

# Implements this way of doing it: https://askubuntu.com/a/1281319

# Force upgrade dkms:
# ls /var/lib/initramfs-tools | sudo xargs -n1 /usr/lib/dkms/dkms_autoinstaller start

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

# Install dependencies
install_if_not build-essential
install_if_not dkms

INSTALLDIR="$SCRIPTS/PN51"
OLDRVERSION="9.005.06"
RVERSION="9.005.06"

new_version() {
# Ask to update to a newer version
if [ -n "$(check_command dkms status)" ]
then
    if ! yesno_box_no "The Realtek 2.5G driver is already installed, would you like to update to the latest version?"
    then
        exit
    else
        check_command dkms remove r8125/"$OLDRVERSION" --all
        rm -rf /usr/src/r8125"$OLDRVERSION"/
        if [ -z "$(check_command dkms status)" ]
        then
            print_text_in_color "$ICyan" "Firmware version $OLDRVERSION successfully purged!"
        fi
    fi
fi
}

stay_at_current() {
STATUS="$(check_command dkms status)"
if [ -n "$STATUS" ]
then
    if echo "$STATUS" | grep "$RVERSION" &> /dev/null
    then
        print_text_in_color "$ICyan" "The Realtek 2.5G driver (version $RVERSION) is already installed."
        exit
    fi
fi
}

# Update to new version or stay at current
# Before upgrading to bew version, fix all variables and download the newest version to the VM repo here: 
# https://github.com/nextcloud/vm/tree/master/network/asusnuc
#
#new_version
stay_at_current

# Make sure the installation directory exist
mkdir -p "$INSTALLDIR"

# Check for new version based on current version
print_text_in_color "$ICyan" "Checking for newer version of firmware..."
if ! curl -k -s https://www.realtek.com/en/component/zoo/category/network-interface-controllers-10-100-1000m-gigabit-ethernet-pci-express-software | grep "$RVERSION" >/dev/null
then
    msg_box "It seems like there's a newer version of the Realtek Driver for the LAN network card.

Please report this to $ISSUES including this link: https://www.realtek.com/en/component/zoo/category/network-interface-controllers-10-100-1000m-gigabit-ethernet-pci-express-software

Thanks!"
fi

# Download and extract
if [ ! -f "$INSTALLDIR"/r8125-"$RVERSION".tar.bz2 ]
then
    curl_to_dir https://github.com/nextcloud/vm/raw/master/network/asusnuc r8125-"$RVERSION".tar.bz2 "$INSTALLDIR"
fi

if [ ! -d "$INSTALLDIR"/r8125-"$RVERSION" ]
then
    check_command cd "$INSTALLDIR"
    check_command tar -xf r8125-"$RVERSION".tar.bz2
fi

# Install
if [ -d "$INSTALLDIR"/r8125-"$RVERSION" ]
then
    cat <<-DKMSCONFIG > "$INSTALLDIR"/r8125-"$RVERSION"/src/dkms.conf
PACKAGE_NAME="r8125"
PACKAGE_VERSION="$RVERSION"
BUILT_MODULE_NAME[0]="\$PACKAGE_NAME"
DEST_MODULE_LOCATION[0]="/updates/dkms"
AUTOINSTALL="YES"
REMAKE_INITRD="YES"
CLEAN="rm src/@PKGNAME@.ko src/*.o || true"
DKMSCONFIG
    check_command cp -R "$INSTALLDIR"/r8125-"$RVERSION"/src /usr/src/r8125-"$RVERSION"
    check_command dkms add -m r8125 -v "$RVERSION"
    check_command dkms build -m r8125 -v "$RVERSION"
    check_command dkms install -m r8125 -v "$RVERSION"
else
    msg_box "$INSTALLDIR/r8125-$RVERSION does not seem to exist, the script will now exit."
    exit 1
fi

# Remove the folder, keep the tar
rm -rf "$INSTALLDIR"/r8125-"$RVERSION"

# Check if it was successful
STATUS="$(check_command dkms status)"
if [ -n "$STATUS" ]
then
    if echo "$STATUS" | grep "$RVERSION" &> /dev/null
    then
        msg_box "The Realtek 2.5G driver (version $RVERSION) was successfully installed."
    fi
else
    msg_box "Something went wrong, please report this to $ISSUES"
    exit 1
fi

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
