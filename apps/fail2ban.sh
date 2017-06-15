#!/bin/bash

# Tech and Me © - 2017, https://www.techandme.se/

# shellcheck disable=2034,2059
true
# shellcheck source=lib.sh
. <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Check if root
if ! is_root
then
    printf "\n${Red}Sorry, you are not root.\n${Color_Off}You must type: ${Cyan}sudo ${Color_Off}bash %s/phpmyadmin_install.sh\n" "$SCRIPTS"
    sleep 3
    exit 1
fi

### Local variables ###
# location of Nextcloud logs
NCLOG="/var/ncdata/nextcloud.log"
# time to ban an IP that exceeded attempts
BANTIME_=600
# cooldown time for incorrect passwords
FINDTIME_=600
#bad attempts before banning an IP
MAXRETRY_=4

apt update -q4 & spinner_loading
check_command apt install fail2ban -y
check_command update-rc.d fail2ban disable

if [ ! -f $NCLOG ]
then
    echo "$NCLOG not found"
    exit 1
else
    touch $NCLOG
    chown www-data:www-data $NCLOG
fi

# Set values in config.php
sudo -u www-data php "$NCPATH/occ" config:system:set loglevel --value=2
sudo -u www-data php "$NCPATH/occ" config:system:set log_type --value=file
sudo -u www-data php "$NCPATH/occ" config:system:set logfile  --value="$NCLOG"
sudo -u www-data php "$NCPATH/occ" config:system:set logtimezone  --value="$(cat /etc/timezone)"

# Create nextcloud.conf file
cat << NCONF > /etc/fail2ban/filter.d/nextcloud.conf
[Definition]
failregex = ^.*Login failed: '.*' \(Remote IP: '<HOST>'.*$
ignoreregex =
NCONF

# Create jail.local file
cat << FCONF > /etc/fail2ban/jail.local
# The DEFAULT allows a global definition of the options. They can be overridden
# in each jail afterwards.
[DEFAULT]

# "ignoreip" can be an IP address, a CIDR mask or a DNS host. Fail2ban will not
# ban a host which matches an address in this list. Several addresses can be
# defined using space separator.
ignoreip = 127.0.0.1/8

# "bantime" is the number of seconds that a host is banned.
bantime  = $BANTIME_

# A host is banned if it has generated "maxretry" during the last "findtime"
# seconds.
findtime = $FINDTIME_
maxretry = $MAXRETRY_

#
# ACTIONS
#
banaction = iptables-multiport
protocol = tcp
chain = INPUT
action_ = %(banaction)s[name=%(__name__)s, port="%(port)s", protocol="%(protocol)s", chain="%(chain)s"]
action_mw = %(banaction)s[name=%(__name__)s, port="%(port)s", protocol="%(protocol)s", chain="%(chain)s"]
action_mwl = %(banaction)s[name=%(__name__)s, port="%(port)s", protocol="%(protocol)s", chain="%(chain)s"]
action = %(action_)s

#
# SSH
#

[ssh]
enabled  = true
port     = ssh
filter   = sshd
logpath  = /var/log/auth.log
maxretry = "$MAXRETRY_"

#
# HTTP servers
#

[nextcloud]
enabled  = true
port     = http,https
filter   = nextcloud
logpath  = "$NCLOG"
maxretry = "$MAXRETRY_"
FCONF

# Update settings
check_command update-rc.d fail2ban defaults
check_command update-rc.d fail2ban enable
check_command service fail2ban restart

# The End
echo "Fail2ban is now sucessfully installed."
echo "Please use 'fail2ban-client set nextcloud unbanip <Banned IP>' to unban certain IPs"
echo "You can alos use 'iptables -L -n' to check which IPs that are banned"
any_key "Press any key to continue..."
clear
