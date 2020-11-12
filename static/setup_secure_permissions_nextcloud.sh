#!/bin/bash

# T&M Hansson IT AB © - 2020, https://www.hanssonit.se/

true
SCRIPT_NAME="Setup Secure Permissions for Nextcloud"
# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh || source <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Check if root
root_check

htuser='www-data'
htgroup='www-data'
rootuser='root'

# Only check for existing datadir if Nextcloud is installed
if [ -f "$NCPATH"/config/config.php ]
then
    NCDATA="$(grep 'datadir' "$NCPATH"/config/config.php | awk '{print $3}' | cut -d "'" -f2)"
fi

print_text_in_color "$IGreen" "Setting secure permissions..."
print_text_in_color "$ICyan" "Creating possible missing Directories"
mkdir -p "$NCPATH"/data
mkdir -p "$NCPATH"/updater
install -d -m 777 "$VMLOGS"
install -o www-data -g www-data -m 660 /dev/null /var/log
mkdir -p "$NCDATA"

if ! [ -f "$VMLOGS/nextcloud.log" ]
then
    touch "$VMLOGS/nextcloud.log"
fi

if ! [ -f "$VMLOGS/audit.log" ]
then
    touch "$VMLOGS/audit.log"
fi

print_text_in_color "$ICyan" "chmod Files and Directories"
find "${NCPATH}"/ -type f -print0 | xargs -0 chmod 0640
find "${VMLOGS}"/audit.log -type f -print0 | xargs -0 chmod 0640
find "${NCPATH}"/ -type d -print0 | xargs -0 chmod 0750
find "${VMLOGS}"/ -type d -print0 | xargs -0 chmod 0750
find "${VMLOGS}"/nextcloud.log -type f -print0 | xargs -0 chmod 0640

print_text_in_color "$ICyan" "chown Directories"
chown -R "${rootuser}":"${htgroup}" "${VMLOGS}"/
chown "${htuser}":"${htgroup}" "${VMLOGS}"/
chown "${htuser}":"${htgroup}" "${VMLOGS}"/nextcloud.log
chown "${htuser}":"${htgroup}" "${VMLOGS}"/audit.log
chown -R "${rootuser}":"${htgroup}" "${NCPATH}"/
chown -R "${htuser}":"${htgroup}" "${NCPATH}"/apps/
chown -R "${htuser}":"${htgroup}" "${NCPATH}"/config/
chown -R "${htuser}":"${htgroup}" "${NCPATH}"/themes/
chown -R "${htuser}":"${htgroup}" "${NCPATH}"/updater/
if [ -f "${VMLOGS}"/update.log ]
then
    chown "${rootuser}":"${rootuser}" "${VMLOGS}"/update.log
fi

if stat -c "%U:%G" "$NCDATA"/* | grep -cv "${htuser}:${htgroup}"
then
    chown -R "${htuser}":"${htgroup}" "${NCDATA}"/
fi

chmod +x "${NCPATH}"/occ

print_text_in_color "$ICyan" "chmod/chown .htaccess"
if [ -f "${NCPATH}"/.htaccess ]
then
    chmod 0644 "${NCPATH}"/.htaccess
    chown "${rootuser}":"${htgroup}" "${NCPATH}"/.htaccess
fi
if [ -f "${NCDATA}"/.htaccess ]
then
    chmod 0644 "${NCDATA}"/.htaccess
    chown "${rootuser}":"${htgroup}" "${NCDATA}"/.htaccess
fi

