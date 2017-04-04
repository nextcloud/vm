#!/bin/bash
# shellcheck disable=2034,2059
true
# shellcheck source=lib.sh


. <(curl -sL https://raw.githubusercontent.com/morph027/vm/master/lib.sh)


# Change config.php
php $SCRIPTS/update-config.php $NCPATH/config/config.php 'trusted_domains[]' localhost "${ADDRESS[@]}" "$(hostname)" "$(hostname --fqdn)" >/dev/null 2>&1
php $SCRIPTS/update-config.php $NCPATH/config/config.php overwrite.cli.url https://"$(hostname --fqdn)"/ >/dev/null 2>&1

# Change .htaccess accordingly
sed -i "s|RewriteBase /nextcloud|RewriteBase /|g" $NCPATH/.htaccess

exit 0
