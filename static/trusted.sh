#!/bin/bash

NCPATH=/var/www/nextcloud
ADDRESS=$(hostname -I | cut -d ' ' -f 1)
SCRIPTS=/var/scripts

# Change config.php
php $SCRIPTS/update-config.php $NCPATH/config/config.php 'trusted_domains[]' localhost ${ADDRESS[@]} $(hostname) $(hostname --fqdn) 2>&1 >/dev/null
php $SCRIPTS/update-config.php $NCPATH/config/config.php overwrite.cli.url https://$ADDRESS/ 2>&1 >/dev/null

# Change .htaccess accordingly
sed -i "s|RewriteBase /nextcloud|RewriteBase /|g" $NCPATH/.htaccess

exit 0
