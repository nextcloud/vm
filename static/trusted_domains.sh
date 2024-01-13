#!/bin/bash
true
SCRIPT_NAME="Set trusted domain"
# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh

# T&M Hansson IT AB © - 2024, https://www.hanssonit.se/

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Set trusted domains default
if [ -n "$ADDRESS" ]
then
    nextcloud_occ config:system:set trusted_domains 0 --value="localhost"
    nextcloud_occ config:system:set trusted_domains 1 --value="$ADDRESS"
    nextcloud_occ config:system:set trusted_domains 2 --value="$(hostname)"
    nextcloud_occ config:system:set overwrite.cli.url --value="https://$(hostname --fqdn)"
    # Also set WAN address if it exists
    if [ -n "$WANIP4" ]
    then
        nextcloud_occ config:system:set trusted_domains 3 --value="$WANIP4"
    fi
else
    nextcloud_occ config:system:set trusted_domains 0 --value="localhost"
    nextcloud_occ config:system:set trusted_domains 1 --value="$(hostname)"
    nextcloud_occ config:system:set overwrite.cli.url --value="https://$(hostname --fqdn)"
    # Also set WAN address if it exists
    if [ -n "$WANIP4" ]
    then
        nextcloud_occ config:system:set trusted_domains 2 --value="$WANIP4"
    fi
fi
