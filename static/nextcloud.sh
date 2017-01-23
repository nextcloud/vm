#!/bin/bash
REPO="https://raw.githubusercontent.com/ezraholm50/NextBerry/master/"
CURRENTVERSION=$(sed '1q;d' /var/scripts/.version-nc)
GITHUBVERSION=$(curl -s $REPO/version)
SCRIPTS="/var/scripts"
TEMP=$(vcgencmd measure_temp)
CPUFREQ=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq)
COREVOLT=$(vcgencmd measure_volts core)
MEMARM=$(vcgencmd get_mem arm)
MEMGPU=$(vcgencmd get_mem gpu)
WANIP4=$(curl -s ipinfo.io/ip -m 5)
WANIP6=$(curl -s 6.ifcfg.me -m 5)
ADDRESS=$(hostname -I | cut -d ' ' -f 1)
RELEASE=$(lsb_release -s -d)
clear
figlet -f small NextBerry
echo "https://www.techandme.se"
echo "==============================================================================="
echo "RPI: $TEMP - CPU freq: $CPUFREQ - $COREVOLT - MEM: $MEMGPU $MEMARM"
echo "==============================================================================="
printf "Operating system: %s (%s %s %s)\n" "$RELEASE" "$(uname -o)" "$(uname -r)" "$(uname -m)"
echo "==============================================================================="
/usr/bin/landscape-sysinfo
echo "==============================================================================="
echo "WAN IPv4: $WANIP4 - WAN IPv6: $WANIP6"
echo "LAN IPv4: $ADDRESS"
echo "==============================================================================="
echo "To view your firewall rules, type: sudo firewall-rules"
echo "To monitor your system, type: nextberry-stats"
echo "                              sudo htop"
echo "                              fs-size"
echo "==============================================================================="
if [ "$GITHUBVERSION" -gt "$CURRENTVERSION" ]; then
          echo
          echo "NextBerry update available, run: sudo nextberry-upgrade"
          echo "==============================================================================="

          if              [ -f /var/scripts/nextberry-upgrade.sh ];	then
          		rm /var/scripts/nextcloud_install_production.sh
          fi
              wget -q https://raw.githubusercontent.com/ezraholm50/NextBerry/master/static/nextberry-upgrade.sh -P "$SCRIPTS"
              mv "$SCRIPTS"/nextberry-upgrade.sh /usr/sbin/nextberry-upgrade
              chmod +x /usr/sbin/nextberry-upgrade
          if [[ $? > 0 ]]
          then
                  echo "Download of update script failed. Please file a bug report on https://www.github.com/ezraholm50/NextBerry/"
                  echo "==============================================================================="
          fi
fi
exit 0
