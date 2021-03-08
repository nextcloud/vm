#!/bin/bash

# T&M Hansson IT AB © - 2021, https://www.hanssonit.se/
# Copyright © 2021 Simon Lindner (https://github.com/szaimen)

true
SCRIPT_NAME="SSH Hardening"
SCRIPT_EXPLAINER="This script hardens the SSH settings based on Lynis security check."
# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh || source <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Check if root
root_check

# Variables
SSH_CONF="/etc/ssh/sshd_config.d/harden_ssh.conf"

# Check requirement
if ! grep -q '^Include /etc/ssh/sshd_config.d/\*\.conf$' /etc/ssh/sshd_config
then
    msg_box "The SSH config doesn't seem to be the default. Cannot proceed!"
    exit 1
fi
if [ -z "$UNIXUSER" ] || [ "$UNIXUSER" = root ]
then
    msg_box "Cannot proceed with root user!"
    exit 1
fi

# Check if webmin is already installed
if ! [ -f "$SSH_CONF" ]
then
    # Ask for installing
    install_popup "$SCRIPT_NAME"
else
    # Ask for removal or reinstallation
    reinstall_remove_menu "$SCRIPT_NAME"
    # Removal
    check_command rm "$SSH_CONF"
    systemctl restart ssh
    # Show successful uninstall if applicable
    removal_popup "$SCRIPT_NAME"
fi

cat << SSH_CONF > "$SSH_CONF"
# Implement Lynis suggestions
# fix https://github.com/nextcloud/vm/issues/1873
AllowTcpForwarding no
ClientAliveCountMax 2
Compression no
LogLevel verbose
MaxAuthTries 2
MaxSessions 2
PermitRootLogin no
# Port will not be changed
TCPKeepAlive no
X11Forwarding no
AllowAgentForwarding no

# https://help.ubuntu.com/community/SSH/OpenSSH/Configuring#Specify_Which_Accounts_Can_Use_SSH
AllowUsers $UNIXUSER
SSH_CONF

# Restart SSH
systemctl restart ssh

# Inform user
msg_box "SSH was successfully hardened!"
