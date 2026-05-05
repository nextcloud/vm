#!/bin/bash

# T&M Hansson IT AB © - 2026, https://www.hanssonit.se/

true
SCRIPT_NAME="Update Server + Nextcloud"
# shellcheck source=lib.sh
if [ -f /var/scripts/fetch_lib.sh ]
then
    # shellcheck source=static/fetch_lib.sh
    source /var/scripts/fetch_lib.sh
elif ! source <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/main/static/fetch_lib.sh)
then
    source <(curl -sL https://cdn.statically.io/gh/nextcloud/vm/main/static/fetch_lib.sh)
fi

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Must be root
root_check

mkdir -p "$SCRIPTS"

if [[ "${1}" =~ ([[:upper:]]) ]]
then
    msg_box "Please use lower case letters for the beta/rc/minor."
    exit
fi

if [ "${1}" = "minor" ]
then
    echo "$((NCMAJOR-1))" > /tmp/minor.version
elif [ "${1}" = "beta" ]
then
    echo "beta" > /tmp/prerelease.version
elif [[ "${1}" == *"rc"* ]]
then
    echo "${1}" > /tmp/prerelease.version
fi

# Delete, download, run
run_script GITHUB_REPO nextcloud_update

exit
