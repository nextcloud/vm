#!/bin/bash

. <(curl -sL https://cdn.rawgit.com/morph027/vm/color-vars/lib.sh)

WGET="/usr/bin/wget"

$WGET -q --tries=20 --timeout=10 http://www.google.com -O /tmp/google.idx &> /dev/null
if [ ! -s /tmp/google.idx ]
then
    printf "${Red}Not Connected!${Color_Off}\n"
else
    printf "Connected!\n"
fi
