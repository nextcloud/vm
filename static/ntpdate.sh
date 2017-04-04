#!/bin/bash
# shellcheck disable=2034,2059
true
# shellcheck source=lib.sh


. <(curl -sL https://raw.githubusercontent.com/morph027/vm/master/lib.sh)
if wget -q -T 10 -t 2 http://google.com > /dev/null
then
    ntpdate -s 1.se.pool.ntp.org
fi
exit
