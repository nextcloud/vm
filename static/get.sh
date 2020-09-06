#!/bin/bash
# shellcheck disable=2034,2059
true
# see https://github.com/koalaman/shellcheck/wiki/Directive

# Cache the lib for half an hour
if ! [ -f /var/scripts/lib.sh ] || test "`find /var/scripts/lib.sh -mmin +30`"
then
    rm -f /var/scripts/lib.sh
    curl -so /var/scripts/lib.sh https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh
fi

# shellcheck source=lib.sh
source /var/scripts/lib.sh
