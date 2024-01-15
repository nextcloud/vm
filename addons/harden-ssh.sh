#!/bin/bash

# T&M Hansson IT AB © - 2024, https://www.hanssonit.se/
# Copyright © 2021 Simon Lindner (https://github.com/szaimen)

true
SCRIPT_NAME="SSH Hardening"
SCRIPT_EXPLAINER="This script hardens the SSH settings based on Lynis security check."
# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh

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
    sed -i '/^auth required pam_google_authenticator.so/d' /etc/pam.d/sshd
    sed -i 's|^ChallengeResponseAuthentication.*|ChallengeResponseAuthentication no|' /etc/ssh/sshd_config
    systemctl restart ssh
    rm -f "/home/$UNIXUSER/.google_authenticator"
    if is_this_installed libpam-google-authenticator
    then
        apt-get purge libpam-google-authenticator -y
        apt-get autoremove -y
    fi
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

# Allow to enable 2FA for SSH
if ! yesno_box_no "Do you want to enable Two-factor authentication for SSH connections?
(You will need a smartphone with an app or password manager \
that can store and create one-time passwords (OTP) like Google Authenticator.)"
then
    exit
fi

# https://ubuntu.com/tutorials/configure-ssh-2fa#2-installing-and-configuring-required-packages
print_text_in_color "$ICyan" "Enabling two-factor authentication for SSH connections..."
install_if_not libpam-google-authenticator

# Edit /etc/pam.d/sshd
if ! grep -q '^auth required pam_google_authenticator.so' /etc/pam.d/sshd
then
	echo "auth required pam_google_authenticator.so" >> /etc/pam.d/sshd
fi

# ChallengeResponseAuthentication no in /etc/ssh/sshd_config verändern
if grep -q '^ChallengeResponseAuthentication' /etc/ssh/sshd_config
then
    sed -i 's|^ChallengeResponseAuthentication.*|ChallengeResponseAuthentication yes|' /etc/ssh/sshd_config
else
    echo 'ChallengeResponseAuthentication yes' >> /etc/ssh/sshd_config
fi

# Restart ssh
systemctl restart sshd.service

# Create OTP code
if sudo -u "$UNIXUSER" \
google-authenticator \
--time-based \
--disallow-reuse \
--rate-limit=3 \
--rate-time=30 \
--step-size=30 \
--force \
--window-size=3
then
    msg_box "Please make sure to scan the shown QR code with the OTP app and note down the emergency codes!\n
Without them you will not be able to log in via SSH anymore!
You can simply run this script again to disable 2FA SSH authentication again."
    any_key "Press any key to continue"
    while :
    do 
        if ! yesno_box_no "Are you sure that you have scanned the QR code and saved the emergency codes?\n
Without them you will not be able to log in via SSH anymore!
You can simply run this script again to disable 2FA SSH authentication again."
        then
            any_key "Press any key to continue"
        else
            break
        fi
    done
    msg_box "2FA SSH authentication for $UNIXUSER was successfully configured.\n
The backup codes and configuration are in /home/$UNIXUSER/.google_authenticator
You can simply run this script again to disable 2FA SSH authentication again."
else
    msg_box "2FA SSH authentication configuration was unsuccessful.\n
Please run this script again to disable 2FA again!
Otherwise you might not be able to log in via SSH anymore."
fi
