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

# Download and install previewgenerator
if [ ! -d "$NC_APPS_PATH/previewgenerator" ]
then
    echo "Installing previewgenerator..."
    check_command sudo -u www-data php "$NCPATH"/occ app:install previewgenerator
fi

# Enable previewgenerator
if [ -d "$NC_APPS_PATH/previewgenerator" ]
then
    check_command sudo -u www-data php "$NCPATH"/occ app:enable previewgenerator
    chown -R www-data:www-data "$NC_APPS_PATH"
    crontab -u www-data -l | { cat; echo "@daily php -f $NCPATH/occ preview:pre-generate >> /var/log/previewgenerator.log"; } | crontab -u www-data -
    sudo -u www-data php "$NCPATH"/occ preview:generate-all
    touch /var/log/previewgenerator.log
    chown www-data:www-data /var/log/previewgenerator.log
fi
