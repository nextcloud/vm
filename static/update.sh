#!/bin/bash
# shellcheck disable=2034,2059
true
# shellcheck source=lib.sh
. <(curl -sL https://raw.githubusercontent.com/morph027/vm/master/lib.sh)

## Tech and Me ## - ©2017, https://www.techandme.se/
#
# Tested on Ubuntu Server 14.04 & 16.04.

FILE=nextcloud_update.sh

# Must be root
if ! is_root
then
    echo "Must be root to run script, in Ubuntu type: sudo -i"
    exit 1
fi

mkdir -p "$SCRIPTS"

if [ -f "$SCRIPTS/$FILE" ]
then
    rm -f "$SCRIPTS/$FILE"
    wget -q "https://raw.githubusercontent.com/nextcloud/vm/master/$FILE" -P "$SCRIPTS"
    bash "$SCRIPTS/$FILE"
else
    wget -q "https://raw.githubusercontent.com/nextcloud/vm/master/$FILE" -P "$SCRIPTS"
    bash "$SCRIPTS/$FILE"
fi

chmod +x "$SCRIPTS/$FILE"

# Remove potenial copy of the same file
if [ -f "$SCRIPTS/$FILE.1" ]
then
    rm -f "$SCRIPTS/$FILE.1"
fi

exit
