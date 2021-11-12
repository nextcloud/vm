#!/bin/bash

# T&M Hansson IT AB © - 2021, https://www.hanssonit.se/

msg_box() {
    [ -n "$2" ] && local SUBTITLE=" - $2"
    whiptail --title "$TITLE$SUBTITLE" --msgbox "$1" "$WT_HEIGHT" "$WT_WIDTH" 3>&1 1>&2 2>&3
}

msg_box "PLEASE NOTE: This VM is just meant for testing Nextcloud, it's *not* the full version!

If you want the full and extended version of this VM, please download it here:
- https://github.com/nextcloud/vm/releases
- https://www.hanssonit.se/nextcloud-vm/

The full-version includes;
- TLS (a real trusted certificate from Let's Encrypt)
- deSEC (desec.io)
- Automated apps configuration (OnlyOffice, Collabora, Talk, and more)
- Automated updates
- and much more...

Please press [ENTER] to start using your Nextcloud VM appliance."

WANIP6=$(curl -s -k -m 5 -6 https://api64.ipify.org)
WANIP4=$(curl -s -k -m 5 -4 https://api64.ipify.org)
ADDRESS=$(hostname -I | cut -d ' ' -f 1)

clear
figlet -f small Nextcloud
echo "https://github.com/nextcloud/vm"
echo
echo
echo "Hostname: $(hostname -s)"
echo "WAN IPv4: $WANIP4"
echo "WAN IPv6: $WANIP6"
echo "LAN IPv4: $ADDRESS"
echo
exit 0
