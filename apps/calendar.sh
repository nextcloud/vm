#!/bin/bash

# Tech and Me © - 2017, https://www.techandme.se/

# shellcheck disable=2034,2059
true
# shellcheck source=lib.sh
CALENDAR_INSTALL=1 . <(curl -sL https://raw.githubusercontent.com/morph027/vm/master/lib.sh)
unset CALENDAR_INSTALL

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Download and install Calendar
if [ ! -d "$NCPATH"/apps/calendar ]
then
    wget -q "$CALVER_REPO/v$CALVER/$CALVER_FILE" -P "$NCPATH/apps"
    tar -zxf "$NCPATH/apps/$CALVER_FILE" -C "$NCPATH/apps"
    cd "$NCPATH/apps"
    rm "$CALVER_FILE"
fi

# Enable Calendar
if [ -d "$NCPATH"/apps/calendar ]
then
    sudo -u www-data php "$NCPATH"/occ app:enable calendar
fi
