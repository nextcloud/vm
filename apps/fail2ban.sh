#!/bin/bash

# T&M Hansson IT AB © - 2024, https://www.hanssonit.se/
# Inspired by https://github.com/nextcloud/nextcloudpi/blob/main/etc/nextcloudpi-config.d/fail2ban.sh

true
SCRIPT_NAME="Fail2ban"
SCRIPT_EXPLAINER="Fail2ban provides extra Brute Force protection for Nextcloud.
It scans the Nextcloud and SSH log files and bans IPs that show malicious \
signs -- too many password failures, seeking for exploits, etc. 
Generally Fail2Ban is then used to update firewall rules to \
reject the IP addresses for a specified amount of time."
# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh

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
    if ! does_this_docker_exist vaultwarden && ! does_this_docker_exist bitwarden_rs
    then
        print_text_in_color "$ICyan" "Unbanning all currently blocked IPs..."
        fail2ban-client unban --all
        apt-get purge fail2ban -y
        rm -rf /etc/fail2ban
        crontab -u root -l | grep -v "$SCRIPTS/daily_fail2ban_report.sh"  | crontab -u root -
        rm -rf "$SCRIPTS/daily_fail2ban_report.sh"
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

# Check if the DIR actually is a file
if [ -f /var/log/nextcloud ]
then
    rm -f /var/log/nextcloud
fi

# Create $VMLOGS dir
mkdir -p "$VMLOGS"

find_log() {
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
    fi
}

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
        else
           find_log
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
        find_log
        break
    fi
done

# Install iptables
install_if_not iptables

# remove ncdata, else it will be used
rm -f "$NCDATA"/nextcloud.log

# Add auth.log just in case it's not created
if ! [ -f /var/log/auth.log ]
then
    touch /var/log/auth.log
fi

# time to ban an IP that exceeded attempts
BANTIME_=1209600
# cooldown time for incorrect passwords
FINDTIME_=1800
# failed attempts before banning an IP
MAXRETRY_=20

apt-get update -q4 & spinner_loading
install_if_not fail2ban -y
check_command update-rc.d fail2ban disable

# Set timezone
nextcloud_occ config:system:set logtimezone --value="$(cat /etc/timezone)"

# Create nextcloud.conf file
# Using https://docs.nextcloud.com/server/stable/admin_manual/installation/harden_server.html#setup-a-filter-and-a-jail-for-nextcloud
cat << NCONF > /etc/fail2ban/filter.d/nextcloud.conf
[Definition]
_groupsre = (?:(?:,?\s*"\w+":(?:"[^"]+"|\w+))*)
failregex = ^\{%(_groupsre)s,?\s*"remoteAddr":"<HOST>"%(_groupsre)s,?\s*"message":"Login failed:
            ^\{%(_groupsre)s,?\s*"remoteAddr":"<HOST>"%(_groupsre)s,?\s*"message":"Trusted domain error.
datepattern = ,?\s*"time"\s*:\s*"%%Y-%%m-%%d[T ]%%H:%%M:%%S(%%z)?"
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
msg_box "Fail2ban is now successfully installed.

Please use 'fail2ban-client set nextcloud unbanip <Banned IP>' to unban certain IPs
You can also use 'iptables -L -n' to check which IPs that are banned"

# Daily ban notification
if ! yesno_box_no "Do you want to get notified about daily bans?\n
If you choose 'yes', you will receive a notification about daily bans at 23:59h."
then
  exit
fi

# Create Fail2ban report script
cat << FAIL2BAN_REPORT > "$SCRIPTS/daily_fail2ban_report.sh"
#!/bin/bash
# T&M Hansson IT AB © - 2024, https://www.hanssonit.se/

# Look for ip addresses
BANNED_IPS=\$(grep "Ban " /var/log/fail2ban.log | grep "\$(date +%Y-%m-%d)" \
| awk -F "NOTICE  " '{print "Jail:",\$2}' | sort)

# Exit if nothing was found
if [ -z "\$BANNED_IPS" ]
then
    exit
fi

# Report if something was found
source /var/scripts/fetch_lib.sh
if ! send_mail "Your daily Fail2Ban report" "These IP's got banned today:
\$BANNED_IPS"
then
    notify_admin_gui "Your daily Fail2Ban report" "These IP's got banned today:
\$BANNED_IPS"
fi
FAIL2BAN_REPORT

# Add crontab entry
crontab -u root -l | grep -v "$SCRIPTS/daily_fail2ban_report.sh"  | crontab -u root -
crontab -u root -l | { cat; echo "59 23 * * * $SCRIPTS/daily_fail2ban_report.sh > /dev/null"; } | crontab -u root -

# Adjust access rights
chown root:root "$SCRIPTS/daily_fail2ban_report.sh"
chmod 700 "$SCRIPTS/daily_fail2ban_report.sh"

# Inform user
msg_box "The daily Fail2Ban report was successfully configured.\n
You will get notified at 23:59h if new bans were made that day."

exit
