#!/bin/bash
# Mockup of the upgrader tool
VERSIONFILE="/var/scripts/.version-nc"

# V1.1
if grep -q "1.1 applied" "$VERSIONFILE"; then
  echo "1.1 already applied..."
else
  # Patches etc here...

  # Update and upgrade
  apt autoclean
  apt	autoremove -y
  apt update
  apt full-upgrade -y
  apt install -fy
  dpkg --configure --pending

  # Set what version is installed
  echo "1.1 applied" >> "$VERSIONFILE"
fi

# V1.2
if grep -q "1.2 applied" "$VERSIONFILE"; then
  echo "1.2 already applied..."
else
  # Patches etc here...

  # Update and upgrade
  apt autoclean
  apt	autoremove -y
  apt update
  apt full-upgrade -y
  apt install -fy
  dpkg --configure --pending

  # Set what version is installed
  echo "1.2 applied" >> "$VERSIONFILE"
fi

exit
