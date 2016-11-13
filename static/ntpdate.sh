#!/bin/bash
wget -q --spider http://google.com
if [ $? -eq 0 ]
then
ntpdate -s 1.se.pool.ntp.org
fi
exit
