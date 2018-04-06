#!/bin/bash
# shellcheck disable=2034,2059
true
# shellcheck source=lib.sh
. <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)

# Tech and Me © - 2018, https://www.techandme.se/

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

$WGET -q --tries=20 --timeout=10 http://www.github.com -O /tmp/github.idx &> /dev/null
if [ ! -s /tmp/github.idx ]
then
    printf "${Red}Not Connected!${Color_Off}\n"
else
    printf "Connected!\n"
fi
