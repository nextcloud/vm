#!/bin/sh
IFACE=$(lshw -c network | grep "logical name" | awk '{print $3}')

ifdown -a
sed -i 's|eth0|$IFACE|' /etc/network/interfaces
ifup -a

exit 0
