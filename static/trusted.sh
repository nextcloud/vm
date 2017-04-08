#!/bin/bash

# Tech and Me © - 2017, https://www.techandme.se/

# shellcheck disable=2034,2059
true
# shellcheck source=lib.sh
. <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/rewrite/lib.sh)

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Change config.php
php $SCRIPTS/update-config.php $NCPATH/config/config.php 'trusted_domains[]' localhost "${ADDRESS[@]}" "$(hostname)" "$(hostname --fqdn)" >/dev/null 2>&1
php $SCRIPTS/update-config.php $NCPATH/config/config.php overwrite.cli.url https://"$(hostname --fqdn)"/ >/dev/null 2>&1

# Change .htaccess accordingly
sed -i "s|RewriteBase /nextcloud|RewriteBase /|g" $NCPATH/.htaccess

exit 0
