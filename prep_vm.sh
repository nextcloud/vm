#!/bin/bash
# shellcheck disable=2034,2059
true
# shellcheck source=lib.sh
. <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)

# T&M Hansson IT AB © - 2020, https://www.hanssonit.se/

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Create scripts folder
mkdir -p "$SCRIPTS"

# Get needed scripts for first bootup
check_command curl_to_dir "$GITHUB_REPO" lib.sh "$SCRIPTS"
download_script STATIC instruction
download_script STATIC history
download_script STATIC static_ip

# Make $SCRIPTS excutable
chmod +x -R "$SCRIPTS"
chown root:root -R "$SCRIPTS"

# Prepare first bootup
check_command run_script STATIC change-ncadmin-profile
check_command run_script STATIC change-root-profile

# Upgrade
apt update -q4 & spinner_loading
apt dist-upgrade -y

# Remove LXD (always shows up as failed during boot)
apt-get purge lxd -y

# Put IP adress in /etc/issue (shown before the login)
if [ -f /etc/issue ]
then
    echo "\4" >> /etc/issue
    echo "USER: ncadmin"
    echo "PASS: nextcloud"
fi
