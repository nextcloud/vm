#!/bin/bash

# Tech and Me © - 2017, https://www.techandme.se/

# shellcheck disable=2034,2059
true
# shellcheck source=lib.sh
PREVIEW_INSTALL=1 . <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)
unset PREVIEW_INSTALL

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Download and install Preview Generator
if [ ! -d "$NCPATH"/apps/previewgenerator ]
then
    echo "Installing calendar..."
    wget -q "$PREVER_REPO/v$PREVER/$PREVER_FILE" -P "$NCPATH/apps"
    tar -zxf "$NCPATH/apps/$PREVER_FILE" -C "$NCPATH/apps"
    cd "$NCPATH/apps"
    rm "$CALVER_FILE"
fi

# Enable Preview Generator
if [ -d "$NCPATH"/apps/previewgenerator ]
then
    sudo -u www-data php "$NCPATH"/occ app:enable previewgenerator
    crontab -u www-data -l | { cat; echo "@daily php -f /var/www/nextcloud/occ preview:pre-generate >> /var/log/previewgenerator.log"; } | crontab -u www-data -
fi
