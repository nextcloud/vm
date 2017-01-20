#!/bin/bash
REPO="https://raw.githubusercontent.com/ezraholm50/NextBerry/master/"
CURRENTVERSION=$(sed '1q;d' /var/scripts/.version-nc)
GITHUBVERSION=$(curl -s $REPO/version)
SCRIPTS="/var/scripts"
WANIP4=$(curl -s ipinfo.io/ip -m 5)
WANIP6=$(curl -s 6.ifcfg.me -m 5)
ADDRESS=$(hostname -I | cut -d ' ' -f 1)
clear
figlet -f small NextBerry
echo "     https://www.nextcloud.com"
echo "     https://www.techandme.se"
echo
echo
echo "WAN IPv4: $WANIP4"
echo "WAN IPv6: $WANIP6"
echo "LAN IPv4: $ADDRESS"
echo
echo "To view your firewall rules type: sudo firewall-rules"
if [ "$GITHUBVERSION" -gt "$CURRENTVERSION" ]; then
          echo
          echo "NextBerry update available, run: sudo nextberry-upgrade"

          if              [ -f /var/scripts/nextberry-upgrade.sh ];	then
          		rm /var/scripts/nextcloud_install_production.sh
          else
              wget -q https://raw.githubusercontent.com/ezraholm50/NextBerry/master/static/nextberry-upgrade.sh -P "$SCRIPTS"
              mv "$SCRIPTS"/nextberry-upgrade.sh /usr/sbin/nextberry-upgrade
              chmod +x /usr/sbin/nextberry-upgrade
          fi
          if [[ $? > 0 ]]
          then
                  echo "Download of update script failed. Please file a bug report on https://www.github.com/ezraholm50/NextBerry/"
          fi
fi
exit 0
