#!/bin/bash

# T&M Hansson IT AB © - 2020, https://www.hanssonit.se/
# Inspired by https://github.com/nextcloud/nextcloudpi/blob/master/etc/nextcloudpi-config.d/fail2ban.sh

true
SCRIPT_NAME="Fail2ban"
SCRIPT_EXPLAINER="Fail2ban provides extra Brute Force protextion for Nextcloud.
It scans the Nextcloud and SSH log files and bans IPs that show malicious \
signs -- too many password failures, seeking for exploits, etc. 
Generally Fail2Ban is then used to update firewall rules to \
reject the IP addresses for a specified amount of time."
# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh || source <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)

# Get all needed variables from the library
nc_update

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Check if root
root_check

# Check if fail2ban is already installed
if ! [ -f /etc/fail2ban/filter.d/nextcloud.conf ] || ! is_this_installed fail2ban
then
    # Ask for installing
    install_popup "$SCRIPT_NAME"
else
    # Ask for removal or reinstallation
    reinstall_remove_menu "$SCRIPT_NAME"
    # Removal
    if ! does_this_docker_exist bitwarden_rs
    then
        print_text_in_color "$ICyan" "Unbanning all currently blocked IPs..."
        fail2ban-client unban --all
        apt purge fail2ban -y
        rm -rf /etc/fail2ban
    else
        print_text_in_color "$ICyan" "Unbanning all currently blocked IPs..."
        fail2ban-client unban --all
        sleep 5
        rm /etc/fail2ban/filter.d/nextcloud.conf
        sed -i '/^\[sshd\]$/,$d' /etc/fail2ban/jail.local
        check_command systemctl restart fail2ban
    fi
    # Show successful uninstall if applicable
    removal_popup "$SCRIPT_NAME"
fi

# Create $VMLOGS dir
mkdir -p "$VMLOGS"

### Local variables ###
# location of Nextcloud logs
print_text_in_color "$ICyan" "Finding nextcloud.log..."
while :
do
    if [ "$(nextcloud_occ_no_check config:system:get logfile)" = "$VMLOGS/nextcloud.log" ]
    then
        if [ -f "$VMLOGS/nextcloud.log" ]
        then
            chown www-data:www-data "$VMLOGS/nextcloud.log"
            nextcloud_occ config:system:set log_type --value=file
            nextcloud_occ config:system:set loglevel --value=2
            break
        fi
    elif [ -n "$(nextcloud_occ_no_check config:system:get logfile)" ]
    then
        # Set logging
        nextcloud_occ config:system:set log_type --value=file
        nextcloud_occ config:system:set logfile --value="$VMLOGS/nextcloud.log"
        nextcloud_occ config:system:set loglevel --value=2
        touch "$VMLOGS/nextcloud.log"
        chown www-data:www-data "$VMLOGS/nextcloud.log"
        break
    else
        NCLOG=$(find / -type f -name "nextcloud.log" 2> /dev/null)
        if [ "$NCLOG" != "$VMLOGS/nextcloud.log" ]
        then
            # Might enter here if no OR multiple logs already exist, tidy up any existing logs and set the correct path
            print_text_in_color "$ICyan" "Unexpected or non-existent logging configuration - \
deleting any discovered nextcloud.log files and creating a new one at $VMLOGS/nextcloud.log..."
            xargs rm -f <<< "$NCLOG"
            # Set logging
            nextcloud_occ config:system:set log_type --value=file
            nextcloud_occ config:system:set logfile --value="$VMLOGS/nextcloud.log"
            nextcloud_occ config:system:set loglevel --value=2
            touch "$VMLOGS/nextcloud.log"
            chown www-data:www-data "$VMLOGS/nextcloud.log"
            break
        fi
    fi
done
# remove ncdata, else it will be used
rm -f $NCDATA/nextcloud.log
# time to ban an IP that exceeded attempts
BANTIME_=1209600
# cooldown time for incorrect passwords
FINDTIME_=1800
# failed attempts before banning an IP
MAXRETRY_=20

apt update -q4 & spinner_loading
install_if_not fail2ban -y
check_command update-rc.d fail2ban disable

# Set timezone
nextcloud_occ config:system:set logtimezone --value="$(cat /etc/timezone)"

# Create nextcloud.conf file
# Test: failregex = Login failed.*Remote IP.*<HOST>
cat << NCONF > /etc/fail2ban/filter.d/nextcloud.conf
[Definition]
failregex=^{"reqId":".*","remoteAddr":".*","app":"core","message":"Login failed: '.*' \(Remote IP: '<HOST>'\)","level":2,"time":".*"}$
            ^{"reqId":".*","level":2,"time":".*","remoteAddr":".*","app":"core".*","message":"Login failed: '.*' \(Remote IP: '<HOST>'\)".*}$
            ^.*\"remoteAddr\":\"<HOST>\".*Trusted domain error.*\$
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

[sshd]

enabled  = true
maxretry = $MAXRETRY_

#
# HTTP servers
#

[nextcloud]

enabled  = true
port     = http,https
filter   = nextcloud
logpath  = $VMLOGS/nextcloud.log
maxretry = $MAXRETRY_
FCONF

# Update settings
check_command update-rc.d fail2ban defaults
check_command update-rc.d fail2ban enable
check_command systemctl restart fail2ban.service

# The End
msg_box "Fail2ban is now sucessfully installed.

Please use 'fail2ban-client set nextcloud unbanip <Banned IP>' to unban certain IPs
You can also use 'iptables -L -n' to check which IPs that are banned"

exit
