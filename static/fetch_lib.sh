#!/bin/bash
# shellcheck disable=2034,2059
true
# see https://github.com/koalaman/shellcheck/wiki/Directive


mkdir -p /var/scripts
if ! [ -f /var/scripts/lib.sh ]
then
    if ! curl -so /var/scripts/lib.sh https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh 
    then
        printf "The local lib isn't available and you don't have internet access. You cannot run this script"
        exit 1
    fi
elif test "$(find /var/scripts/lib.sh -mmin +30)"
then
    curl -so /var/scripts/lib.sh https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh
fi

# shellcheck source=lib.sh
source /var/scripts/lib.sh &>/dev/null
