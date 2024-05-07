#!/bin/bash
true
SCRIPT_NAME="Set trusted domain"
# shellcheck source=lib.sh
source <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/main/lib.sh)

# Removed in NC 26.0.0.

# Set trusted domains
nextcloud_occ config:system:set trusted_domains 0 --value="localhost"
nextcloud_occ config:system:set trusted_domains 1 --value="$ADDRESS"
nextcloud_occ config:system:set trusted_domains 2 --value="$(hostname -f)"
nextcloud_occ config:system:set overwrite.cli.url --value="https://$(hostname --fqdn)"
nextcloud_occ maintenance:update:htaccess
