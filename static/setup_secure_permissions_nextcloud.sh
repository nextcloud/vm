#!/bin/bash

# Tech and Me © - 2018, https://www.techandme.se/

# shellcheck disable=2034,2059
true
# shellcheck source=lib.sh
. <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

htuser='www-data'
htgroup='www-data'
rootuser='root'

printf "Creating possible missing Directories\n"
mkdir -p $NCPATH/data
mkdir -p $NCPATH/updater
mkdir -p $NCDATA

printf "chmod Files and Directories\n"
find ${NCPATH}/ -type f -print0 | xargs -0 chmod 0640
find ${NCPATH}/ -type d -print0 | xargs -0 chmod 0750

printf "chown Directories\n"
chown -R ${rootuser}:${htgroup} ${NCPATH}/
chown -R ${htuser}:${htgroup} ${NCPATH}/apps/
chown -R ${htuser}:${htgroup} ${NCPATH}/config/
chown -R ${htuser}:${htgroup} ${NCDATA}/
chown -R ${htuser}:${htgroup} ${NCPATH}/themes/
chown -R ${htuser}:${htgroup} ${NCPATH}/updater/

chmod +x ${NCPATH}/occ

printf "chmod/chown .htaccess\n"
if [ -f ${NCPATH}/.htaccess ]
then
    chmod 0644 ${NCPATH}/.htaccess
    chown ${rootuser}:${htgroup} ${NCPATH}/.htaccess
fi
if [ -f ${NCDATA}/.htaccess ]
then
    chmod 0644 ${NCDATA}/.htaccess
    chown ${rootuser}:${htgroup} ${NCDATA}/.htaccess
fi
