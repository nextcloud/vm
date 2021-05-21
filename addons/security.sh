#!/bin/bash

# T&M Hansson IT AB © - 2021, https://www.hanssonit.se/

true
SCRIPT_NAME="Set up Extra Security"
# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh || source <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Check if root
root_check

print_text_in_color "$ICyan" "Installing Extra Security..."


msg_box "This script is based on:
http://www.techrepublic.com/blog/smb-technologist/secure-your-apache-server-from-ddos-slowloris-and-dns-injection-attacks/
https://github.com/wallyhall/spamhaus-drop

As it's kind of intrusive, it could lead to things stop working. But on the other hand it raises the security on the server.

Please run it own your own risk!"

if ! yesno_box_no "Do you want to install Extra Security on your server?"
then
    exit
fi

# Protect against DDOS
apt update -q4 & spinner_loading
apt -y install libapache2-mod-evasive
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
#apt -y install libapache2-mod-qos
a2enmod reqtimeout # http://httpd.apache.org/docs/2.4/mod/mod_reqtimeout.html

# Download SPAMHAUS droplist and block all IPs in that list with IPtables
curl_to_dir https://raw.githubusercontent.com/wallyhall/spamhaus-drop/master/ spamhaus-drop "$SCRIPTS"

# Rename file
mv "$SCRIPTS"/spamhaus-drop  "$SCRIPTS"/spamhaus_cronjob.sh

# Make the file executable
chmod +x "$SCRIPTS"/spamhaus_cronjob.sh

# Add it to crontab
crontab -u root -l | grep -v "$SCRIPTS/spamhaus_crontab.sh 2>&1" | crontab -u root -
crontab -u root -l | { cat; echo "10 2 * * * $SCRIPTS/spamhaus_crontab.sh 2>&1"; } | crontab -u root -

# Run it for the first time
if check_command bash "$SCRIPTS"/spamhaus_cronjob.sh
then
    print_text_in_color "$IGreen" "Security added!"
    restart_webserver
fi
