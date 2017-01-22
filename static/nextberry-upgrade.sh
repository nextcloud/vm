#!/bin/bash
VERSIONFILE="/var/scripts/.version-nc"

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
                  update-notifier-common

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
