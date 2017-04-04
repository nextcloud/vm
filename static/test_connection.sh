#!/bin/bash
# shellcheck disable=2034,2059
true
# shellcheck source=lib.sh

. <(curl -sL https://raw.githubusercontent.com/morph027/vm/master/lib.sh)

$WGET -q --tries=20 --timeout=10 http://www.google.com -O /tmp/google.idx &> /dev/null
if [ ! -s /tmp/google.idx ]
then
    printf "${Red}Not Connected!${Color_Off}\n"
else
    printf "Connected!\n"
fi
