#!/bin/bash

# T&M Hansson IT AB © - 2020, https://www.hanssonit.se/

# shellcheck disable=SC2154
true
SCRIPT_NAME="Setup Extra Security"
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

# Based on: http://www.techrepublic.com/blog/smb-technologist/secure-your-apache-server-from-ddos-slowloris-and-dns-injection-attacks/

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

# Don't enable SpamHaus now as it's now working anyway
# REMOVE disable of SC2154 WHEN PUTTING SPAMHAUS IN PRODUCTION (it's just to fixing travis for now) 
exit

# Protect against DNS Injection
# Insipired by: https://www.c-rieger.de/nextcloud-13-nginx-installation-guide-for-ubuntu-18-04-lts/#spamhausproject

# shellcheck disable=SC2016
DATE='$(date +%Y-%m-%d)'
cat << SPAMHAUS_ENABLE > "$SCRIPTS/spamhaus_cronjob.sh"
#!/bin/bash
# Thanks to @ank0m
EXEC_DATE='date +%Y-%m-%d'
SPAMHAUS_DROP="/usr/local/src/drop.txt"
SPAMHAUS_eDROP="/usr/local/src/edrop.txt"
URL="https://www.spamhaus.org/drop/drop.txt"
eURL="https://www.spamhaus.org/drop/edrop.txt"
DROP_ADD_TO_UFW="/usr/local/src/DROP2.txt"
eDROP_ADD_TO_UFW="/usr/local/src/eDROP2.txt"
DROP_ARCHIVE_FILE="/usr/local/src/DROP_{$EXEC_DATE}"
eDROP_ARCHIVE_FILE="/usr/local/src/eDROP_{$EXEC_DATE}"
# All credits for the following BLACKLISTS goes to "The Spamhaus Project" - https://www.spamhaus.org
echo "Start time: $(date)"
echo " "
echo "Download daily DROP file:"
curl -fsSL "$URL" > $SPAMHAUS_DROP
grep -v '^;' $SPAMHAUS_DROP | cut -d ' ' -f 1 > $DROP_ADD_TO_UFW
echo " "
echo "Extract DROP IP addresses and add to UFW:"
cat $DROP_ADD_TO_UFW | while read line
do
/usr/sbin/ufw insert 1 deny from "$line" comment 'DROP_Blacklisted_IPs'
done
echo " "
echo "Downloading eDROP list and import to UFW"
echo " "
echo "Download daily eDROP file:"
curl -fsSL "$eURL" > $SPAMHAUS_eDROP
grep -v '^;' $SPAMHAUS_eDROP | cut -d ' ' -f 1 > $eDROP_ADD_TO_UFW
echo " "
echo "Extract eDROP IP addresses and add to UFW:"
cat $eDROP_ADD_TO_UFW | while read line
do
/usr/sbin/ufw insert 1 deny from "$line" comment 'eDROP_Blacklisted_IPs'
done
echo " "
#####
## To remove or revert these rules, keep the list of IPs!
## Run a command like so to remove the rules:
# while read line; do ufw delete deny from $line; done < $ARCHIVE_FILE
#####
echo "Backup DROP IP address list:"
mv $DROP_ADD_TO_UFW $DROP_ARCHIVE_FILE
echo " "
echo "Backup eDROP IP address list:"
mv $eDROP_ADD_TO_UFW $eDROP_ARCHIVE_FILE
echo " "
echo End time: $(date)
SPAMHAUS_ENABLE

# Make the file executable
chmod +x "$SCRIPTS"/spamhaus_cronjob.sh

# Add it to crontab
(crontab -l ; echo "10 2 * * * $SCRIPTS/spamhaus_crontab.sh 2>&1") | crontab -u root -

# Run it for the first time
check_command bash "$SCRIPTS"/spamhaus_cronjob.sh

# Enable $SPAMHAUS
if sed -i "s|#MS_WhiteList /etc/spamhaus.wl|MS_WhiteList $SPAMHAUS|g" /etc/apache2/mods-enabled/spamhaus.conf
then
    print_text_in_color "$IGreen" "Security added!"
    restart_webserver
fi
