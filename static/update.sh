#!/bin/bash

# T&M Hansson IT AB © - 2020, https://www.hanssonit.se/

true
SCRIPT_NAME="Update Server + Nextcloud"
# shellcheck source=lib.sh
source <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Must be root
root_check

mkdir -p "$SCRIPTS"

if [ "${1}" = "minor" ]
then
    echo "$((NCMAJOR-1))" > /tmp/minor.version
elif [ "${1}" = "beta" ]
then
    echo "beta" > /tmp/prerelease.version
elif [[ "${1}" == *"RC"* ]]
then
    echo "${1}" > /tmp/prerelease.version
fi

# Delete, download, run
run_script GITHUB_REPO nextcloud_update

exit
