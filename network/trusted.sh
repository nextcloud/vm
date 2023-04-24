#!/bin/bash

# T&M Hansson IT AB © - 2023, https://www.hanssonit.se/

true
SCRIPT_NAME="Trusted"
# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Change config.php
nextcloud occ config:system:set trusted_domains 3 --value=${ADDRESS[@]} "$(hostname)" "$(hostname --fqdn)"
nextcloud occ config:system:set overwrite.cli.url --value=https://"$(hostname --fqdn)"

# Change .htaccess accordingly
sed -i "s|RewriteBase /nextcloud|RewriteBase /|g" $NCPATH/.htaccess

