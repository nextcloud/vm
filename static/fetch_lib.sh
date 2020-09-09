#!/bin/bash
# shellcheck disable=2034,2059
true
# see https://github.com/koalaman/shellcheck/wiki/Directive

# Functions
lib_error_message() {
    msg_box "You don't have internet and the local lib isn't available. Hence you cannot run this script."
    exit 1
}

download_cache_lib() {
    # Cache the lib for half an hour
    if ! [ -f /var/scripts/lib.sh ] || test "$(find /var/scripts/lib.sh -mmin +30)"
    then
        rm -f /var/scripts/lib.sh
        mkdir -p /var/scripts
        if ! curl -so /var/scripts/lib.sh https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh
        then
            lib_error_message
        fi
    fi
}

# Run the script
if [ -f /var/scripts/nextcloud-startup-script.sh ] && ! [ -f "$SCRIPTS/you-can-not-run-the-startup-script-several-times" ]
then
    if printf "Testing internet connection..." && ping github.com -c 2 >/dev/null 2>&1
    then
        download_cache_lib
    else
        if ! [ -f /var/scripts/lib.sh ]
        then
            lib_error_message
        fi
    fi
else
    download_cache_lib
fi

# shellcheck source=lib.sh
source /var/scripts/lib.sh
