#!/bin/bash
VERSIONFILE="/var/scripts/.version-nc"
SCRIPTS="/var/scripts"
GITHUB_REPO="https://raw.githubusercontent.com/ezraholm50/NextBerry/master"
STATIC="https://raw.githubusercontent.com/ezraholm50/NextBerry/master/static"

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

  # Actual version additions
  apt update
  apt install -y  build-essential \
                  lm-sensors \
                  landscape-common \
                  ncdu

  # NCDU
  echo "sudo ncdu /" > /usr/sbin/fs-size
  chmod +x /usr/sbin/fs-size

  # Remove first MOTD
  rm /etc/update-motd.d/50-landscape-sysinfo

  # Also stop it from running at everylogin, only called by nextcloud.sh
  whiptail --msgbox "In the next screen please select:  \n\n        Do not display sysinfo on login" 10 60
  dpkg-reconfigure landscape-common

  # Set what version is installed
  echo "11 applied" >> "$VERSIONFILE"
  # Change current version var
  sed -i 's|010|011|g' "$VERSIONFILE"
  sed -i 's|V1.0|V1.1|g' "$VERSIONFILE"
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

# Unattended-upgrades
# Install packages
apt update
DEBIAN_FRONTEND=noninteractive apt install -y unattended-upgrades \
                                                update-notifier-common

# Set apt config
echo "APT::Periodic::Update-Package-Lists "1";" > /etc/apt/apt.conf.d/20auto-upgrades
echo "APT::Periodic::Unattended-Upgrade "1";" >> /etc/apt/apt.conf.d/20auto-upgrades
echo "APT::Periodic::Enable "1";" > /etc/apt/apt.conf.d/10periodic
echo "APT::Periodic::AutocleanInterval "1";" >> /etc/apt/apt.conf.d/10periodic

if [ -f /etc/apt/apt.conf.d/50unattended-upgrades ]
then
  rm /etc/apt/apt.conf.d/50unattended-upgrades
  wget -q $STATIC/50unattended-upgrades -P /etc/apt/apt.conf.d/
else
  wget -q $STATIC/50unattended-upgrades -P /etc/apt/apt.conf.d/
fi
if [ -f /etc/apt/apt.conf.d/50unattended-upgrades ]
then
  chmod 644 /etc/apt/apt.conf.d/50unattended-upgrades
else
  echo "Script failed to download. Please run: 'sudo bash /var/scripts/nextberry-upgrade.sh' again."
  exit 1
fi

# New wifi setup
apt update
sudo usermod -a -G netdev ncadmin
DEBIAN_FRONTEND=noninteractive apt install -y wicd-curses

if [ -f $SCRIPTS/wireless.sh ] then
    rm $SCRIPTS/wireless.sh
    wget -q $STATIC/wireless.sh -P $SCRIPTS
else
    wget -q $STATIC/wireless.sh -P $SCRIPTS
fi
if [ -f $SCRIPTS/wireless.sh ] then
    sleep 0.1
else
    echo "Script failed to download. Please run: 'sudo bash /var/scripts/nextberry-upgrade.sh' again."
    exit 1
fi
mv $SCRIPTS/wireless.sh /usr/sbin/wireless
chmod +x /usr/sbin/wireless

# Rpi config
echo "vcgencmd get_config int" > /usr/sbin/rpi-conf

# Set what version is installed
echo "12 applied" >> "$VERSIONFILE"
# Change current version var
sed -i 's|011|012|g' "$VERSIONFILE"
sed -i 's|V1.1|V1.2|g' "$VERSIONFILE"

# Done - Move this line to the new release on every new version.
whiptail --msgbox "Successfully installed V1.2, please manually reboot..." 10 65
fi

exit
