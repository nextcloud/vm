#!/bin/bash

# T&M Hansson IT AB © - 2020, https://www.hanssonit.se/
# Copyright © 2020 Simon Lindner (https://github.com/szaimen)

# shellcheck disable=2034,2059
true
SCRIPT_NAME="TPM2 Unlock"
SCRIPT_EXPLAINER="This script helps automatically unlocking the root partition during boot."
# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh || source <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Check if root
root_check

# Check if already installed
if is_this_installed clevis-luks || is_this_installed clevis-tpm2 || is_this_installed clevis-initramfs
then
    msg_box "It seems like clevis-luks is already installed.\nThis script can unfortunately not run twice."
    exit 1
else
    # Ask for installation
    install_popup "$SCRIPT_NAME"
fi

# Make some pre-requirements
if lshw -quiet | grep -q "driver=nvme" && ! grep -q "nvme_core.default_ps_max_latency_us" /etc/default/grub
then
    print_text_in_color "$ICyan" "Configuring necessary pre-requirements..."
    # shellcheck disable=1091
    source /etc/default/grub
    GRUB_CMDLINE_LINUX_DEFAULT+=" nvme_core.default_ps_max_latency_us=5500"
    sed -i "s|^GRUB_CMDLINE_LINUX_DEFAULT.*|GRUB_CMDLINE_LINUX_DEFAULT=\"$GRUB_CMDLINE_LINUX_DEFAULT\"|" /etc/default/grub
    if ! update-grub
    then
        msg_box "Something failed during update-grub. Please report this to $ISSUES"
    fi
fi

# Test if device is present
# https://github.com/noobient/noobuntu/wiki/Full-Disk-Encryption#tpm-2
if ! dmesg | grep -i "tpm" | grep -q "2\.0"
then
    msg_box "No TPM 2.0 device found."
    exit 1
fi
ENCRYPTED_DEVICE="$(lsblk -o KNAME,FSTYPE | grep "crypto_LUKS" | awk '{print $1}')"
if [ -z "$ENCRYPTED_DEVICE" ]
then
    msg_box "No encrypted device found."
    exit 1
fi
mapfile -t ENCRYPTED_DEVICE <<< "$ENCRYPTED_DEVICE"
if [ "${#ENCRYPTED_DEVICE[@]}" -gt 1 ]
then
    msg_box "More than one encrypted device found. This is not supported."
    exit 1
fi

# Enter the password
PASSWORD="$(input_box_flow "Please enter the password for your root partition
If you want to cancel, just type in 'exit' and press [ENTER].")"
if [ "$PASSWORD" = 'exit' ]
then
    exit 1
fi

# Install needed tools
apt install clevis-tpm2 clevis-luks clevis-initramfs -y

# Execute the script
print_text_in_color "$ICyan" "Setting up automatic unlocking via TPM2..."
if ! echo "$PASSWORD" | clevis luks bind -k - -d "/dev/${ENCRYPTED_DEVICE[*]}" tpm2 '{"pcr_ids":"7"}'
then
    msg_box "Something has failed while trying to configure clevis luks.
We will now uninstall all needed packets again, so that you are able to start over."
    apt purge clevis-tpm2 clevis-luks clevis-initramfs -y
    apt autoremove -y
    msg_box "All installed packets were successfully removed."
    exit 1
fi
print_text_in_color "$ICyan" "Updating initramfs..."
if ! update-initramfs -u -k 'all'
then
    msg_box "Errors during initramfs update"
    exit 1
fi

# Inform user
msg_box "TPM2 Unlock was setup successfully.
We will reboot after you hit okay.\n
Please check if it automatically unlocks the root partition.
If not something has failed."

reboot
