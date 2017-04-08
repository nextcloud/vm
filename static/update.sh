#!/bin/bash

# Tech and Me © - 2017, https://www.techandme.se/

# shellcheck disable=2034,2059
true
# shellcheck source=lib.sh
. <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/rewrite/lib.sh)

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

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
    wget -q "$GITHUB_REPO/$FILE" -P "$SCRIPTS"
    bash "$SCRIPTS/$FILE"
else
    wget -q "$GITHUB_REPO/$FILE" -P "$SCRIPTS"
    bash "$SCRIPTS/$FILE"
fi

chmod +x "$SCRIPTS/$FILE"

# Remove potenial copy of the same file
if [ -f "$SCRIPTS/$FILE*" ]
then
    rm -f "$SCRIPTS/$FILE*"
fi

exit
