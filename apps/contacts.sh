#!/bin/bash

# Tech and Me © - 2017, https://www.techandme.se/

# shellcheck disable=2034,2059
true
# shellcheck source=lib.sh
CONTACTS_INSTALL=1 . <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/rewrite/lib.sh)
unset CONTACTS_INSTALL

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Download and install Contacts
if [ ! -d "$NCPATH/apps/contacts" ]
then
    wget -q "$CONVER_REPO/v$CONVER/$CONVER_FILE" -P "$NCPATH/apps"
    tar -zxf "$NCPATH/apps/$CONVER_FILE" -C "$NCPATH/apps"
    cd "$NCPATH/apps"
    rm "$CONVER_FILE"
fi

# Enable Contacts
if [ -d "$NCPATH"/apps/contacts ]
then
    sudo -u www-data php "$NCPATH"/occ app:enable contacts
fi
