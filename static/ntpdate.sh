#!/bin/bash

. <(curl -sL https://cdn.rawgit.com/morph027/vm/master/lib.sh)
if wget -q -T 10 -t 2 http://google.com > /dev/null
then
    ntpdate -s 1.se.pool.ntp.org
fi
exit
