#!/bin/bash
true
SCRIPT_NAME="Set trusted domain"
# shellcheck source=lib.sh
source <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)

# Removed in NC 26.0.0.

nextcloud occ config:system:set trusted_domains 0 --value="localhost"
nextcloud occ config:system:set trusted_domains 0 --value="${ADDRESS[@]}"
nextcloud occ config:system:set trusted_domains 1 --value="$(hostname)"
nextcloud occ config:system:set trusted_domains 2 --value="$(hostname --fqdn)"
nextcloud occ config:system:set overwrite.cli.url --value="https://$(hostname --fqdn)"
nextcloud_occ maintenance:update:htaccess
