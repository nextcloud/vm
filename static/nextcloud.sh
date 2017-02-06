#!/bin/bash
REPO="https://raw.githubusercontent.com/ezraholm50/NextBerry/master/"
CURRENTVERSION=$(sed '1q;d' /var/scripts/.version-nc)
CLEANVERSION=$(sed '2q;d' /var/scripts/.version-nc)
GITHUBVERSION=$(curl -s $REPO/version)
SCRIPTS="/var/scripts"
FIGLET="/usr/bin/figlet"
TEMP=$(vcgencmd measure_temp)
CPUFREQ=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq)
COREVOLT=$(vcgencmd measure_volts core)
MEMARM=$(vcgencmd get_mem arm)
MEMGPU=$(vcgencmd get_mem gpu)
LANDSCAPE=$(/usr/bin/landscape-sysinfo  --exclude-sysinfo-plugins=LandscapeLink)
WANIP4=$(curl -s ipinfo.io/ip -m 5)
WANIP6=$(curl -s 6.ifcfg.me -m 5)
ADDRESS=$(hostname -I | cut -d ' ' -f 1)
RELEASE=$(lsb_release -s -d)
BIN_UPTIME=$(/usr/bin/uptime --pretty)
HTML=/var/www
NCPATH=$HTML/nextcloud
NCREPO="https://download.nextcloud.com/server/releases"
CURRENTVERSIONNC=$(sudo -u www-data php $NCPATH/occ status | grep "versionstring" | awk '{print $3}')
NCVERSION=$(curl -s --max-time 900 $NCREPO/ | tac | grep unknown.gif | sed 's/.*"nextcloud-\([^"]*\).zip.sha512".*/\1/;q')
COLOR_WHITE='\033[1;37m'
COLOR_DEFAULT='\033[0m'
OS=$(printf "Operating system: %s (%s %s %s)\n" "$RELEASE" "$(uname -o)" "$(uname -r)" "$(uname -m)")
clear
echo -e "$COLOR_WHITE $($FIGLET -ckw 80 -f small NextBerry $CLEANVERSION) $COLOR_DEFAULT"
echo -e "$COLOR_WHITE https://www.techandme.se                Uptime: $BIN_UPTIME $COLOR_DEFAULT"
echo -e "$COLOR_WHITE =============================================================================== $COLOR_DEFAULT"
echo -e "$COLOR_WHITE RPI: $TEMP - CPU freq: $CPUFREQ - $COREVOLT - MEM: $MEMGPU $MEMARM $COLOR_DEFAULT"
echo -e "$COLOR_WHITE =============================================================================== $COLOR_DEFAULT"
echo -e "$COLOR_WHITE $OS $COLOR_DEFAULT"
echo -e "$COLOR_WHITE =============================================================================== $COLOR_DEFAULT"
echo -e "$COLOR_WHITE $LANDSCAPE $COLOR_DEFAULT"
echo -e "$COLOR_WHITE =============================================================================== $COLOR_DEFAULT"
echo -e "$COLOR_WHITE WAN IPv4: $WANIP4 - WAN IPv6: $WANIP6 $COLOR_DEFAULT"
echo -e "$COLOR_WHITE LAN IPv4: $ADDRESS $COLOR_DEFAULT"
echo -e "$COLOR_WHITE =============================================================================== $COLOR_DEFAULT"
echo -e "$COLOR_WHITE To upload your installation log, type:        sudo install-log $COLOR_DEFAULT"
echo -e "$COLOR_WHITE To view your firewall rules, type:            sudo firewall-rules $COLOR_DEFAULT"
echo -e "$COLOR_WHITE To connect to a wifi network, type:           sudo wireless $COLOR_DEFAULT"
echo -e "$COLOR_WHITE To view RPI config settings, type:            sudo rpi-conf $COLOR_DEFAULT"
echo -e "$COLOR_WHITE To monitor your system, type:                 sudo htop $COLOR_DEFAULT"
echo -e "$COLOR_WHITE                                               sudo fs-size $COLOR_DEFAULT"
# Log file check
if [ -f $SCRIPTS/.pastebinit ];	then
  INSLOG=$(cat $SCRIPTS/.pastebinit)
  echo -e "$COLOR_WHITE =============================================================================== $COLOR_DEFAULT"
  echo -e "$COLOR_WHITE Your installation log: $INSLOG $COLOR_DEFAULT"
fi
echo -e "$COLOR_WHITE =============================================================================== $COLOR_DEFAULT"
# NextBerry version check
if [ "$GITHUBVERSION" -gt "$CURRENTVERSION" ]; then
  echo -e "$COLOR_LIGHT_GREEN NextBerry update available, run: sudo bash /home/ncadmin/nextberry-upgrade.sh $COLOR_DEFAULT"
  echo -e "$COLOR_WHITE =============================================================================== $COLOR_DEFAULT"
  if [ -f /home/ncadmin/nextberry-upgrade.sh ];	then
      rm /home/ncadmin/nextberry-upgrade.sh
  fi
      wget -q https://raw.githubusercontent.com/ezraholm50/NextBerry/master/static/nextberry-upgrade.sh -P /home/ncadmin/ && chmod +x /home/ncadmin/nextberry-upgrade.sh
      if [[ $? > 0 ]]; then
      echo -e "$COLOR_WHITE Download of update script failed. Please file a bug report on https://github.com/ezraholm50/NextBerry/issues/new $COLOR_DEFAULT"
      echo -e "$COLOR_WHITE =============================================================================== $COLOR_DEFAULT"
      fi
fi
# Nextcloud version check
function version_gt() { local v1 v2 IFS=.; read -ra v1 <<< "$1"; read -ra v2 <<< "$2"; printf -v v1 %03d "${v1[@]}"; printf -v v2 %03d "${v2[@]}"; [[ $v1 > $v2 ]]; }
if version_gt "$NCVERSION" "$CURRENTVERSIONNC"
then
  echo -e "$COLOR_LIGHT_GREEN Nextcloud update available, run: sudo bash $SCRIPTS/update.sh $COLOR_DEFAULT"
  echo -e "$COLOR_WHITE =============================================================================== $COLOR_DEFAULT"
fi
exit 0
