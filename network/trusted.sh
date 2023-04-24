#!/bin/bash
true
SCRIPT_NAME="Set trusted domain"
# shellcheck source=lib.sh
source <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)

nextcloud occ config:system:set trusted_domains 3 --value="${ADDRESS[@]}" "$(hostname)" "$(hostname --fqdn)"
nextcloud occ config:system:set overwrite.cli.url --value="https://$(hostname --fqdn)"
nextcloud_occ maintenance:update:htaccess
