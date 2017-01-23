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
  apt install -y  unattended-upgrades \ # Unattended-upgrades
                  update-notifier-common \
                  python-pip \ # Glances
                  build-essential \
                  python-dev \
                  lm-sensors \
                  landscape-common \ # Sys info
                  ncdu # Directory size

# Glances
pip install --upgrade pip
pip install psutil logutils bottle batinfo https://bitbucket.org/gleb_zhulik/py3sensors/get/tip.tar.gz zeroconf netifaces pymdstat influxdb elasticsearch potsdb statsd pystache docker-py pysnmp pika py-cpuinfo bernhard
pip install glances
echo "sudo glances" > /usr/sbin/nextberry-stats
chmod +x /usr/sbin/nextberry-stats

# NCDU
echo "sudo ncdu /" > /usr/sbin/fs-size

# Unattended-upgrades


  # Set what version is installed
  echo "11 applied" >> "$VERSIONFILE"
  # Change current version var
  sed -i 's|10|11|g' "$VERSIONFILE"
fi

################### V1.2 ####################
if grep -q "12 applied" "$VERSIONFILE"; then
  echo "12 already applied..."
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

  # Set what version is installed
  echo "12 applied" >> "$VERSIONFILE"
  # Change current version var
  sed -i 's|10|11|g' "$VERSIONFILE"
fi

exit
