#!/bin/bash

# Tech and Me © - 2018, https://www.techandme.se/
# Inspired by https://github.com/nextcloud/nextcloudpi/blob/master/etc/nextcloudpi-config.d/fail2ban.sh

# shellcheck disable=2034,2059
true
# shellcheck source=lib.sh
NC_UPDATE=1 . <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)
unset NC_UPDATE

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Check if root
root_check

# Nextcloud 13 is required.
lowest_compatible_nc 13

### Local variables ###
# location of Nextcloud logs
NCLOG="$(find / -name nextcloud.log)"
# time to ban an IP that exceeded attempts
BANTIME_=600000
# cooldown time for incorrect passwords
FINDTIME_=1800
# failed attempts before banning an IP
MAXRETRY_=10

echo "Installing Fail2ban..."

apt update -q4 & spinner_loading
check_command apt install fail2ban -y
check_command update-rc.d fail2ban disable

if [ -z "$NCLOG" ]
then
    echo "nextcloud.log not found"
    echo "Please add your logpath to $NCPATH/config/config.php and restart this script."
    exit 1
else
    chown www-data:www-data "$NCLOG"
fi

# Set values in config.php
occ_command config:system:set loglevel --value=2
occ_command config:system:set log_type --value=file
occ_command config:system:set logfile  --value="$NCLOG"
occ_command config:system:set logtimezone  --value="$(cat /etc/timezone)"

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
ignoreip = 127.0.0.1/8 192.168.0.0/16 172.16.0.0/12 10.0.0.0/8

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
maxretry = $MAXRETRY_

#
# HTTP servers
#

[nextcloud]

enabled  = true
port     = http,https
filter   = nextcloud
logpath  = $NCLOG
maxretry = $MAXRETRY_
FCONF

# Update settings
check_command update-rc.d fail2ban defaults
check_command update-rc.d fail2ban enable
check_command service fail2ban restart

# The End
msg_box "Fail2ban is now sucessfully installed.

Please use 'fail2ban-client set nextcloud unbanip <Banned IP>' to unban certain IPs
You can also use 'iptables -L -n' to check which IPs that are banned"
clear
