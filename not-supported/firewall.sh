#!/bin/bash

# T&M Hansson IT AB © - 2024, https://www.hanssonit.se/
# Copyright © 2021 Simon Lindner (https://github.com/szaimen)

true
SCRIPT_NAME="Firewall"
SCRIPT_EXPLAINER="This script helps setting up a firewall for your NcVM."
# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Check if root
root_check

# Check if firewall is already enabled
if ! ufw status | grep -q " active"
then
    # Ask for installing
    install_popup "$SCRIPT_NAME"
else
    # Ask for removal or reinstallation
    reinstall_remove_menu "$SCRIPT_NAME"
    # Removal
    ufw disable
    ufw --force reset
    # Show successful uninstall if applicable
    removal_popup "$SCRIPT_NAME"
fi

# Install and enable firewall
if ! is_this_installed ufw
then
    DEBIAN_FRONTEND=noninteractive apt-get install ufw -y --no-install-recommends
    systemctl enable ufw &>/dev/null
    systemctl start ufw &>/dev/null
fi

# SSH
print_text_in_color "$ICyan" "Allow SSH"
ufw allow ssh comment SSH

# Web server
print_text_in_color "$ICyan" "Web server"
ufw allow http comment http
ufw allow https comment https

# UPnP
print_text_in_color "$ICyan" "UPnP"
ufw allow proto udp from 192.168.0.0/16 comment UPnP

# Adminer
print_text_in_color "$ICyan" "Allow Adminer"
ufw allow 9443/tcp comment Adminer

# Netdata
print_text_in_color "$ICyan" "Allow Netdata"
ufw allow 19999/tcp comment 'Netdata TCP'
ufw allow 19999/udp comment 'Netdata UDP'

# Talk (no custom port possible)
print_text_in_color "$ICyan" "Allow Talk"
ufw allow 3478/tcp comment 'Talk TCP'
ufw allow 3478/udp comment 'Talk UDP'

# Webmin
print_text_in_color "$ICyan" "Allow Webmin"
ufw allow 10000/tcp comment Webmin

# RDP
if is_this_installed xrdp
then
    print_text_in_color "$ICyan" "Allow RDP"
    ufw allow 3389/tcp comment Remotedesktop
fi

# Samba
if is_this_installed samba
then
    print_text_in_color "$ICyan" "Allow Samba"
    ufw allow samba comment Samba
fi

# Pi-hole
if pihole &>/dev/null
then
    print_text_in_color "$ICyan" "Allow Pi-hole"
    ufw allow 53/tcp comment 'Pi-hole TCP'
    ufw allow 53/udp comment 'Pi-hole UDP'
    ufw allow 8094/tcp comment 'Pi-hole Web'
fi

# PiVPN
if pivpn &>/dev/null
then
    print_text_in_color "$ICyan" "Allow PiVPN"
    ufw allow 51820/udp comment 'PiVPN'
fi

# Plex
if is_docker_running && docker ps -a --format "{{.Names}}" | grep -q "^plex$"
then
    print_text_in_color "$ICyan" "Allow Plex"
    for port in 32400/tcp 3005/tcp 8324/tcp 32469/tcp 1900/udp 32410/udp 32412/udp 32413/udp 32414/udp
    do
        ufw allow "$port" comment "Plex $port"
    done
fi

# Enable firewall
print_text_in_color "$ICyan" "Enable Firewall"
ufw --force enable

msg_box "The Firewall was configured successfully!"
