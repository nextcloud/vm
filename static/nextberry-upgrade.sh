#!/bin/bash
VERSIONFILE="/var/scripts/.version-nc"
SCRIPTS="/var/scripts"

# Check if root
if [ "$(whoami)" != "root" ]
then
    echo
    echo -e "\e[31mSorry, you are not root.\n\e[0mYou must type: \e[36msudo \e[0mbash $SCRIPTS/nextberry-upgrade.sh"
    echo
    exit 1
fi

# Whiptail auto-size
calc_wt_size() {
  WT_HEIGHT=17
  WT_WIDTH=$(tput cols)

  if [ -z "$WT_WIDTH" ] || [ "$WT_WIDTH" -lt 60 ]; then
    WT_WIDTH=80
  fi
  if [ "$WT_WIDTH" -gt 178 ]; then
    WT_WIDTH=120
  fi
  WT_MENU_HEIGHT=$((WT_HEIGHT-7))
}

################### V1.1 ####################
if grep -q "11 applied" "$VERSIONFILE"; then
  echo "11 already applied..."
else
  # Update and upgrade
  apt autoclean
  apt	autoremove -y
  apt update
  apt full-upgrade -y
  apt install -fy
  dpkg --configure --pending
  bash /var/scripts/update.sh

  # Actual version additions
  apt install -y  unattended-upgrades \
                  update-notifier-common \
                  python-pip \
                  build-essential \
                  python-dev \
                  lm-sensors \
                  landscape-common \
                  ncdu
                  #wicd-curses

  # NextBerry stats
  pip install --upgrade pip
  pip install psutil logutils bottle batinfo https://bitbucket.org/gleb_zhulik/py3sensors/get/tip.tar.gz zeroconf netifaces pymdstat influxdb elasticsearch potsdb statsd pystache docker-py pysnmp pika py-cpuinfo bernhard
  pip install glances
  echo "sudo glances" > /usr/sbin/nextberry-stats
  chmod +x /usr/sbin/nextberry-stats

  # NCDU
  echo "sudo ncdu /" > /usr/sbin/fs-size
  chmod +x /usr/sbin/fs-size

  # Wicd-curses
  #echo "whiptail --msgbox "To see how to use this tool see: http://blog.ubidots.com/setup-wifi-on-raspberry-pi-using-wicd" 20 60" > /usr/sbin/wireless
  #echo "sudo wicd-curses" >> /usr/sbin/wireless
  #echo "whiptail --msgbox "If you are connected to a wireless network please set a static IP in your router.\n\n You can find your IP.\n\n https://www.techandme.se/open-port-80-443/" 20 60" >> /usr/sbin/wireless
  #echo "clear" >> /usr/sbin/wireless
  #echo "bash $SCRIPTS/nextcloud.sh" >> /usr/sbin/wireless
  #chmod +x /usr/sbin/wireless

  # Wpa_supplicant
  CAT << WIRELESS > "/usr/sbin/wireless"
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

  IP=$(grep address /etc/network/interfaces.bak)
  MASK=$(grep netmask /etc/network/interfaces.bak)
  GW=$(grep gateway /etc/network/interfaces.bak)

  # New interface config without IPV6
  cat << NETWORK > "/etc/network/interfaces"
  auto lo
  "$WIFACE" lo inet loopback

  allow-hotplug "$WIFACE"
  auto "$WIFACE"
  WIFACE "$WIFACE" inet static
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
  WIRELESS

  chmod +x /usr/sbin/wireless

  # Set what version is installed
  echo "11 applied" >> "$VERSIONFILE"
  # Change current version var
  sed -i 's|010|011|g' "$VERSIONFILE"
fi

################### V1.2 ####################
#if grep -q "12 applied" "$VERSIONFILE"; then
#  echo "12 already applied..."
#else
#  # Update and upgrade
#  apt autoclean
#  apt	autoremove -y
#  apt update
#  apt full-upgrade -y
#  apt install -fy
#  dpkg --configure --pending
#  bash /var/scripts/update.sh
#
#  # Actual version additions
#  # Unattended-upgrades
#
#  # Set what version is installed
#  echo "12 applied" >> "$VERSIONFILE"
#  # Change current version var
#  sed -i 's|010|011|g' "$VERSIONFILE"
#fi

exit
