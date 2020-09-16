#!/bin/bash

# T&M Hansson IT AB © - 2020, https://www.hanssonit.se/

# shellcheck disable=2034,2059
true
# shellcheck source=lib.sh
source /var/scripts/lib.sh

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

msg_box "Nice job, you're now done with the setup!

Please open your web browser and go to one of these places:
WAN IPv4: $WANIP4
LAN IPv4: $ADDRESS
WAN IPv6: $WANIP6

If you need support, please visit https://help.nextcloud.com/
If you want the full and extended version of this VM (including TLS, automated apps configuration, and more), please download it here: https://github.com/nextcloud/vm/releases

To remove this prompt, please remove 'bash /home/ncadmin/welcome.sh' in /home/ncadmin/.bash_profile"
