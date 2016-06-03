#!/bin/sh

IFCONFIG="/sbin/ifconfig"
IP="/sbin/ip"
INTERFACES="/etc/network/interfaces"

IFACE=$($IP -o link show | awk '{print $2,$9}' | grep "UP" | cut -d ":" -f 1)
ADDRESS=$(hostname -I | cut -d ' ' -f 1)
NETMASK=$($IFCONFIG | grep -w inet |grep -v 127.0.0.1| awk '{print $4}' | cut -d ":" -f 2)
GATEWAY=$(route -n|grep "UG"|grep -v "UGH"|cut -f 10 -d " ")

cat <<-IPCONFIG > "$INTERFACES"
        auto lo $IFACE

        iface lo inet loopback

        iface $IFACE inet static
		pre-up /sbin/ethtool -K $IFACE tso off
		pre-up /sbin/ethtool -K $IFACE gso off

                address $ADDRESS
                netmask $NETMASK
                gateway $GATEWAY

# Exit and save:	[CTRL+X] + [Y] + [ENTER]
# Exit without saving:	[CTRL+X]

IPCONFIG

exit 0
