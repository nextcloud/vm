#!/bin/bash

# T&M Hansson IT AB © - 2024, https://www.hanssonit.se/

true
SCRIPT_NAME="Extra Security"
SCRIPT_EXPLAINER="This script is based on:
http://www.techrepublic.com/blog/smb-technologist/secure-your-apache-server-from-ddos-slowloris-and-dns-injection-attacks/
https://github.com/wallyhall/spamhaus-drop

As it's kind of intrusive, it could lead to things stop working. But on the other hand it raises the security on the server.

Please run it own your own risk!"

# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Must be root
root_check

# Check if Extra Security is already installed
if ! [ -d /var/log/apache2/evasive ]
then
    # Ask for installing
    install_popup "$SCRIPT_NAME"
else
    # Ask for removal or reinstallation
    reinstall_remove_menu "$SCRIPT_NAME"
    # Removal
    apt-get purge libapache2-mod-evasive -y
    rm -rf /var/log/apache2/evasive
    rm -f "$ENVASIVE"
    a2dismod reqtimeout
    bash "$SCRIPTS"/spamhaus-drop.sh -d
    rm -f "$SCRIPTS"/spamhaus-drop.sh
    crontab -u root -l | grep -v "$SCRIPTS/spamhaus-drop.sh" | crontab -u root -
    rm -f "$SCRIPTS"/spamhaus_crontab.sh
    crontab -u root -l | grep -v "$SCRIPTS/spamhaus_crontab.sh" | crontab -u root -
    restart_webserver
    # Show successful uninstall if applicable
    removal_popup "$SCRIPT_NAME"
fi

# Protect against DDOS
apt-get update -q4 & spinner_loading
install_if_not libapache2-mod-evasive
mkdir -p /var/log/apache2/evasive
chown -R www-data:root /var/log/apache2/evasive
if [ ! -f "$ENVASIVE" ]
then
    touch "$ENVASIVE"
    cat << ENVASIVE > "$ENVASIVE"
DOSHashTableSize 2048
DOSPageCount 20  # maximum number of requests for the same page
DOSSiteCount 300  # total number of requests for any object by the same client IP on the same listener
DOSPageInterval 1.0 # interval for the page count threshold
DOSSiteInterval 1.0  # interval for the site count threshold
DOSBlockingPeriod 10.0 # time that a client IP will be blocked for
DOSLogDir
ENVASIVE
fi

# Protect against Slowloris
#install_if_not libapache2-mod-qos
a2enmod reqtimeout # http://httpd.apache.org/docs/2.4/mod/mod_reqtimeout.html

# Download the spamhaus script
download_script STATIC spamhaus-drop

# Install iptables
install_if_not iptables

# Make the file executable
chmod +x "$SCRIPTS"/spamhaus-drop.sh

# Add it to crontab
crontab -u root -l | grep -v "$SCRIPTS/spamhaus-drop.sh" | crontab -u root -
crontab -u root -l | { cat; echo "10 2 * * * $SCRIPTS/spamhaus-drop.sh -u 2>&1"; } | crontab -u root -

# Run it for the first time
msg_box "We will now add a number of bad IP-addresses to your IPtables block list, meaning that all IPs on that list will be blocked as they are known for doing bad stuff.

The script will be run on a schelude to update the IP-addresses, and can be found here: $SCRIPTS/spamhaus-drop.sh.

To disable it, please remove the crontab by executing 'crontab -e' and remove this:
10 2 * * * $SCRIPTS/spamhaus-drop.sh -u 2>&1"

if check_command bash "$SCRIPTS"/spamhaus-drop.sh -u
then
    print_text_in_color "$IGreen" "Security added!"
    restart_webserver
fi
