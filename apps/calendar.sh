#!/bin/bash

# Tech and Me © - 2017, https://www.techandme.se/

# shellcheck disable=2034,2059
true
# shellcheck source=lib.sh
. <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Download and install Calendar
if [ ! -d "$NCPATH"/apps/calendar ]
then
sudo -u www-data php "$NCPATH"/occ app:install calendar
fi

# Enable Calendar
if [ -d "$NCPATH"/apps/calendar ]
then
    sudo -u www-data php "$NCPATH"/occ app:enable calendar
    chown -R www-data:www-data $NCPATH/apps
fi
