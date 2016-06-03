#!/bin/bash

WGET="/usr/bin/wget"

$WGET -q --tries=20 --timeout=10 http://www.google.com -O /tmp/google.idx &> /dev/null
if [ ! -s /tmp/google.idx ]
then
     echo -e "\e[31mNot Connected!"
else
    echo -e "\e[32mConnected! \o/"
fi

# Reset colors
echo -e "\e[0m"
