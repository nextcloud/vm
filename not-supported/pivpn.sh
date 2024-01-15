#!/bin/bash

# T&M Hansson IT AB © - 2024, https://www.hanssonit.se/
# Copyright © 2021 Simon Lindner (https://github.com/szaimen)

true
SCRIPT_NAME="PiVPN"
SCRIPT_EXPLAINER="PiVPN is one of the fastest and most user friendly ways to get a running Wireguard VPN server.
This script will set up a Wireguard VPN server to connect devices to your home net from everywhere.
Wireguard is a relatively new VPN protocol, that is much faster and better then e.g. OpenVPN."
# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Check if root
root_check

# Check if already installed
if ! pivpn &>/dev/null
then
    # Ask for installing
    install_popup "$SCRIPT_NAME"
else
    # Choose to uninstall
    if ! yesno_box_no "It seems like PiVPN is already installed.
Do you want to uninstall PiVPN and reset all its settings?
This will also remove all clients that have currently home network access via Wireguard."
    then
        exit 1
    fi

    # Get installed applications
    INSTALLED=$(grep "INSTALLED_PACKAGES=" /etc/pivpn/wireguard/setupVars.conf)
    INSTALLED="${INSTALLED##*INSTALLED_PACKAGES=}"
    INSTALLED=$(echo "$INSTALLED" | sed 's|(||;s|)||')

    # Warning
    msg_box "Warning! Continuing in the next step will reboot your server after completion automatically!"

    # Inform about possible problems
    msg_box "Attention!

It could happen that the automatic reboot after uninstalling PiVPN fails (it doesn't finish with shutdown).
In this case, you will need to power off your device by hand.
Also it might happen that it will not remove pivpn successfully in this case.
If this is the case, just run the uninstallation again."
    if ! yesno_box_yes "Do you want to continue?"
    then
        exit 1
    fi

    # Last chance to cancel
    if ! yesno_box_yes "The following packets will get uninstalled, too:
$INSTALLED

Do they look correct to you? If not, you can press 'no' and we will not remove anything.
If you press 'yes', we will remove PiVPN, its settings and all those listed programs \
and automatically reboot your server afterwards."
    then
        exit 1
    fi

    # Last msg_box
    msg_box "After you hit okay, we will remove PiVPN, all its settings and all listed programs \
and reboot your server automatically."
    
    # Remove firewall rule
    ufw delete allow 51820/udp &>/dev/null

    # Remove PiVPN and reboot
    yes | pivpn uninstall

    # Remove some leftovers
    rm -r  /etc/wireguard*
    ip link set down wg0
    ip link del dev wg0
    rm -f "$SCRIPTS/pivpn.sh"

    # Just to make sure
    reboot
fi

# Check if Pi-hole is already installed
if ! pihole &>/dev/null
then
    # Inform the user
    msg_box "It seems like Pi-hole is not installed.
It is recommended to install it first if you want to use it, \
because you will have the chance to use it as the DNS-server for Wireguard \
if it is installed before installing Wireguard."

    # Ask if the user wants to continue
    if ! yesno_box_no "Do you want to continue nonetheless?"
    then
        exit 1
    fi
fi

# Test if the user is okay
if [ -z "$UNIXUSER" ] || ! find /home -maxdepth 1 -mindepth 1 | grep -q "$UNIXUSER"
then
    msg_box "It seems like you run this script as pure root \
or your user doesn't have a home directory. This is not supported."
    exit 1
fi

# Inform the user
msg_box "Before installing PiVPN please make sure that you have a backup of your NcVM.
The reason is, that to install the the PiVPN we will need to run a 3rd party script on your NcVM.
Something could go wrong. So please keep backups!"

# Automatically get the domain
if [ -f "$NCPATH/occ" ]
then
    # Get the NCDOMAIN
    NCDOMAIN=$(nextcloud_occ_no_check config:system:get overwrite.cli.url | sed 's|https://||;s|/||')

    # Check if Nextcloud is installed
    if ! curl -s https://"$NCDOMAIN"/status.php | grep -q 'installed":true' || [ "$NCDOMAIN" = "nextcloud" ]
    then
        msg_box "It seems like Nextcloud is not installed or that you don't use https on:
$NCDOMAIN.

Please install Nextcloud and make sure your domain is reachable, or activate TLS
on your domain to be able to run this script.

We need this to make sure that the domain works for connections over Wireguard."
        exit 1
    fi
fi

# Ask if backups are ready
if ! yesno_box_no "Have you made a backup of your NcVM?
This is the last possibility to quit!
If you choose 'yes' we will continue with the installation."
then
    exit 1
fi

# Ask for the domain
if ! [ -f "$NCPATH/occ" ]
then
    # Enter the NCDOMAIN yourself
    NCDOMAIN=$(input_box_flow "Please enter the domain that you want to use for Wireguard.
It should most likely point to your home ip address via DDNS.")
fi

# Inform user to open Port
msg_box "To make Wireguard work, you will need to open port 51820 UDP.

You will have the option to automatically open this port by using UPNP in the next step."
if yesno_box_no "Do you want to use UPNP to open port 51820 UDP?"
then
    unset FAIL
    open_port 51820 UDP
    cleanup_open_port
fi

# Check the port
if ! yesno_box_yes "Unfortunately we are not able to check automatically if port 51820 UDP is open. So please make sure to open it correctly!\nDo you still want to continue?"
then
    exit 1
fi

# Inform the user about PIVPN
msg_box "Just so that you don't wonder:
We will use the scripts from the PiVPN project.
They are made for the Raspberry Pi but work on Ubuntu without any problem.
This is why we decided to use this project as foundation for Wireguard.
The next popups are from the PiVPN script.
This is their official website: https://pivpn.io/"

# Inform the user
print_text_in_color "$ICyan" "Installing PiVPN..."

# Download the script
check_command curl -sfL https://install.pivpn.io -o "$SCRIPTS"/pivpn-install.sh

# Check that all patterns match
if ! grep -q "maybeOSSupport$" "$SCRIPTS"/pivpn-install.sh || ! grep -q "askWhichVPN$" "$SCRIPTS"/pivpn-install.sh \
|| ! grep -q "askPublicIPOrDNS$" "$SCRIPTS"/pivpn-install.sh || ! grep -q "askCustomPort$" "$SCRIPTS"/pivpn-install.sh \
|| ! grep -q "askUnattendedUpgrades$" "$SCRIPTS"/pivpn-install.sh || ! grep -q "displayFinalMessage$" "$SCRIPTS"/pivpn-install.sh \
|| ! grep -q "chooseUser$" "$SCRIPTS"/pivpn-install.sh || ! grep -q "welcomeDialogs$" "$SCRIPTS"/pivpn-install.sh
then
    msg_box "It seems like some functions in pivpn-install.sh have changed.
Please report this to $ISSUES"
    exit 1
fi

# Continue with the process
sed -i 's|maybeOSSupport$|# maybeOSSupport|' "$SCRIPTS"/pivpn-install.sh # We don't need to check the OS since Ubuntu is supported
sed -i 's|askWhichVPN$|# askWhichVPN|' "$SCRIPTS"/pivpn-install.sh # We always want to use Wireguard
sed -i 's|askPublicIPOrDNS$|# askPublicIPOrDNS|' "$SCRIPTS"/pivpn-install.sh # We will set the hostname automatically
sed -i 's|askCustomPort$|# askCustomPort|' "$SCRIPTS"/pivpn-install.sh # We always use port 51820
sed -i 's|askUnattendedUpgrades$|# askUnattendedUpgrades|' "$SCRIPTS"/pivpn-install.sh # We don't want to enable unattended upgrades
sed -i 's|displayFinalMessage$|# displayFinalMessage|' "$SCRIPTS"/pivpn-install.sh # We don't want to show the final message
sed -i 's|chooseUser$|# chooseUser|' "$SCRIPTS"/pivpn-install.sh # We want to use the UNIXUSER
sed -i 's|welcomeDialogs$|# welcomeDialogs|' "$SCRIPTS"/pivpn-install.sh # We don't want to display the welcoem dialog

# Set and export defaults
pivpnPORT=51820 && export pivpnPORT
VPN="wireguard" && export VPN
UNATTUPG=0 && export UNATTUPG

# Run the script
bash "$SCRIPTS"/pivpn-install.sh

# Remove the script since it is no longer needed
check_command rm "$SCRIPTS"/pivpn-install.sh

# Check if PiVPN was successfully installed
if ! pivpn &>/dev/null
then
    msg_box "Something got wrong during pivpn-install.sh
Please report this to $ISSUES"
    exit 1
fi

PIVPN_CONF="/etc/pivpn/wireguard/setupVars.conf"
if [ -f "$PIVPN_CONF" ] && ! grep -q "pivpnHOST" "$PIVPN_CONF" \
&& ! grep -q "UNATTUPG" "$PIVPN_CONF" && ! grep -q "pivpnPORT" "$PIVPN_CONF" \
&& ! grep -q "install_user" "$PIVPN_CONF" && ! grep -q "install_home" "$PIVPN_CONF"
then
    # Write values to setupVars.conf
    cat << PIVPN_CONF >> /etc/pivpn/wireguard/setupVars.conf
pivpnHOST=$NCDOMAIN
UNATTUPG=0
pivpnPORT=51820
install_user=$UNIXUSER
install_home=/home/$UNIXUSER
PIVPN_CONF
else
    msg_box "Couldn't write configuration to setupVars.conf.
Please report this to $ISSUES"
    exit 1
fi

# Add firewall rule
ufw allow 51820/udp comment 'PiVPN' &>/dev/null

# Inform the user about successfully installing PiVPN
msg_box "Congratulations, your PiVPN was set up correctly!

You can now generate new client profiles for your devices by running:
'pivpn -a'

Adding the new profile to a mobile phone (using the Wireguard app) can get afterwards done by running:
'pivpn -qr'

Attention! Every device needs its own profile!

A list of available options is shown by running:
'pivpn -h'"

msg_box "Have you secure boot enabled?
If you had to configure a secure boot key during the PiVPN scripts, \
it is recommended to reboot your server now and follow those instructions:

1. select to reboot
2. On the next startup you will see now the MOK-management-console.
3. select 'Enroll MOK'
4. select 'Yes' when asked 'Enroll the Key(s)?'
5. Enter the password
6. reboot

Afterwards the startup should work automatically again."

if yesno_box_yes "Do you want to reboot now?
This is only needed, if you have secure boot enabled and \
needed to enter a secure boot key during the PiVPN script."
then
    reboot
fi

exit
