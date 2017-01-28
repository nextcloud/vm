#!/bin/bash
ncpath='/var/www/nextcloud'
htuser='www-data'
htgroup='www-data'
rootuser='root'
NCDATA='/var/ncdata'

printf "Creating possible missing Directories\n"
mkdir -p $ncpath/data
mkdir -p $ncpath/updater
mkdir -p $NCDATA

printf "chmod Files and Directories\n"
find ${ncpath}/ -type f -print0 | xargs -0 chmod 0640
find ${ncpath}/ -type d -print0 | xargs -0 chmod 0750

printf "chown Directories\n"
chown -R ${rootuser}:${htgroup} ${ncpath}/
chown -R ${htuser}:${htgroup} ${ncpath}/apps/
chown -R ${htuser}:${htgroup} ${ncpath}/config/
chown -R ${htuser}:${htgroup} ${NCDATA}/
chown -R ${htuser}:${htgroup} ${ncpath}/themes/
chown -R ${htuser}:${htgroup} ${ncpath}/updater/

chmod +x ${ncpath}/occ

printf "chmod/chown .htaccess\n"
if [ -f ${ncpath}/.htaccess ]
then
    chmod 0644 ${ncpath}/.htaccess
    chown ${rootuser}:${htgroup} ${ncpath}/.htaccess
fi
if [ -f ${NCDATA}/.htaccess ]
then
    chmod 0644 ${NCDATA}/.htaccess
    chown ${rootuser}:${htgroup} ${NCDATA}/.htaccess
fi
