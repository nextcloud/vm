#!/bin/bash
WIFACE=$(lshw -c network | grep "wl" | awk '{print $3; exit}')
clear

# Check if root
if [ "$(whoami)" != "root" ]
then
    echo
    echo -e "\e[31mSorry, you are not root.\n\e[0mYou must type: \e[36msudo \e[0mbash $SCRIPTS/nextberry-upgrade.sh"
    echo
    exit 1
fi

# Temp network config
cat << TEMP >> "/etc/network/interfaces"
allow-hotplug "$WIFACE"
auto "$WIFACE"
iface "$WIFACE" inet dhcp
TEMP
ifup "$WIFACE"

# Iwlist scan
a=0
b=0
x=0
while read line
do
   case $line in
    *ESSID* )
        line=${line#*ESSID:}
        essid[$a]=${line//\"/}
        a=$((a + 1))
        ;;
    *Address*)
        line=${line#*Address:}
        address[$b]=$line
        b=$((b + 1))
        ;;
   esac
done < <(iwlist scan 2>/dev/null) #the redirect gets rid of "lo        Interface doesn't support scanning."

while [ $x -lt ${#essid[@]} ];do
  echo "======================================"
  echo ${essid[$x]} --- ${address[$x]}
  echo "======================================"
  (( x++ ))
done

# Ask for SSID
echo
echo "Please copy/paste (select text and hit CTRL+C and then CTRL+V) your wifi network:"
read SSID

# Ask for PASS
clear
echo
echo "Please enter the password for network: $SSID"
read PASSWORD

# Create config file
cat << WPA > "/etc/wpa_supplicant.conf"
# /etc/wpa_supplicant.conf

ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1

network={
ssid="$SSID"
psk="$PASSWORD"
proto=RSN
key_mgmt=WPA-PSK
pairwise=CCMP
auth_alg=OPEN
}
WPA

# Bringdown eth0 before removing and backing up old config
ifdown eth0
mv /etc/network/interfaces /etc/network/interfaces.bak
sed -i 's|allow-hotplug "$WIFACE"||g' /etc/network/interfaces.bak
sed -i 's|auto "$WIFACE"||g' /etc/network/interfaces.bak
sed -i 's|iface "$WIFACE" inet dhcp||g' /etc/network/interfaces.bak

IP=$(grep address /etc/network/interfaces.bak)
MASK=$(grep netmask /etc/network/interfaces.bak)
GW=$(grep gateway /etc/network/interfaces.bak)

# New interface config without IPV6
cat << NETWORK > "/etc/network/interfaces"
auto lo
iface lo inet loopback

allow-hotplug "$WIFACE"
auto "$WIFACE"
iface "$WIFACE" inet static
"$IP"
"$MASK"
"$GW"
            dns-nameservers 8.8.8.8 8.8.4.4
wpa-conf /etc/wpa_supplicant.conf
"$WIFACE" default inet dhcp
NETWORK

# Bring up Wifi
ifup "$WIFACE"

# Create a revert script
cat << REVERT > "/usr/sbin/revert-wifi"
ifdown "$WIFACE"
rm /etc/network/interfaces
mv /etc/network/interfaces.bak /etc/network/interfaces
ifup eth0
REVERT
chmod +x /usr/sbin/revert-wifi
