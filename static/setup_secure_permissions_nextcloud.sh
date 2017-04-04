#!/bin/bash
# shellcheck disable=2034,2059
true
# shellcheck source=lib.sh

. <(curl -sL https://cdn.rawgit.com/morph027/vm/master/lib.sh)

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

chmod +x ${ncpath}/occ

printf "chmod/chown .htaccess\n"
if [ -f ${NCPATH}/.htaccess ]
then
    chmod 0644 ${ncpath}/.htaccess
    chown ${rootuser}:${htgroup} ${NCPATH}/.htaccess
fi
if [ -f ${NCDATA}/.htaccess ]
then
    chmod 0644 ${NCDATA}/.htaccess
    chown ${rootuser}:${htgroup} ${NCDATA}/.htaccess
fi
