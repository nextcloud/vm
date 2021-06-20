#!/bin/bash

# T&M Hansson IT AB © - 2021, https://www.hanssonit.se/

true
SCRIPT_NAME="Extra Security"
SCRIPT_EXPLAINER="This script is based on:
http://www.techrepublic.com/blog/smb-technologist/secure-your-apache-server-from-ddos-slowloris-and-dns-injection-attacks/
https://github.com/wallyhall/spamhaus-drop

As it's kind of intrusive, it could lead to things stop working. But on the other hand it raises the security on the server.

Please run it own your own risk!"

# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh || source <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Must be root
root_check

# Check if Extra Security is already installed
if ! [ -d /var/log/apache2/evasive ]
then
    # Ask for installing
    install_popup "$SCRIPT_NAME"
else
    # Ask for removal or reinstallation
    reinstall_remove_menu "$SCRIPT_NAME"
    # Removal
    apt-get purge libapache2-mod-evasive -y
    rm -rf /var/log/apache2/evasive
    rm -f "$ENVASIVE"
    a2dismod reqtimeout
    bash "$SCRIPTS"/spamhaus_cronjob.sh deletechain
    rm -f "$SCRIPTS"/spamhaus_cronjob.sh
    crontab -u root -l | grep -v "$SCRIPTS/spamhaus_crontab.sh 2>&1" | crontab -u root -
    restart_webserver
    # Show successful uninstall if applicable
    removal_popup "$SCRIPT_NAME"
fi

# Protect against DDOS
apt-get update -q4 & spinner_loading
install_if_not libapache2-mod-evasive
mkdir -p /var/log/apache2/evasive
chown -R www-data:root /var/log/apache2/evasive
if [ ! -f "$ENVASIVE" ]
then
    touch "$ENVASIVE"
    cat << ENVASIVE > "$ENVASIVE"
DOSHashTableSize 2048
DOSPageCount 20  # maximum number of requests for the same page
DOSSiteCount 300  # total number of requests for any object by the same client IP on the same listener
DOSPageInterval 1.0 # interval for the page count threshold
DOSSiteInterval 1.0  # interval for the site count threshold
DOSBlockingPeriod 10.0 # time that a client IP will be blocked for
DOSLogDir
ENVASIVE
fi

# Protect against Slowloris
#install_if_not libapache2-mod-qos
a2enmod reqtimeout # http://httpd.apache.org/docs/2.4/mod/mod_reqtimeout.html

cat << SPAMHAUS_ENABLE > "$SCRIPTS/spamhaus_cronjob.sh"
#!/bin/bash

## Source: https://raw.githubusercontent.com/wallyhall/spamhaus-drop/master/spamhaus-drop
## Initially forked from cowgill, extended and improved for our mailserver needs.
## Credit: https://github.com/cowgill/spamhaus/blob/master/spamhaus.sh

# based off the following two scripts
# http://www.theunsupported.com/2012/07/block-malicious-ip-addresses/
# http://www.cyberciti.biz/tips/block-spamming-scanning-with-iptables.html

# path to iptables
IPTABLES="/sbin/iptables"

# list of known spammers
URLS="www.spamhaus.org/drop/drop.lasso www.spamhaus.org/drop/edrop.lasso"

# save local copy here
FILE="/tmp/drop.lasso"

# iptables custom chain
CHAIN="Spamhaus"

# check to see if the chain already exists
if \$IPTABLES -L "\$CHAIN" -n
then
    # flush the old rules
    \$IPTABLES -D INPUT -j "\$CHAIN"
    \$IPTABLES -D FORWARD -j "\$CHAIN"
    \$IPTABLES -F "\$CHAIN"

    if [ -n "\$1" ]
    then
        \$IPTABLES -X "\$CHAIN"
        echo "\$CHAIN removed in iptables."
        exit
    else
        echo "Flushed old rules. Applying updated Spamhaus list...."
    fi
else
    # create a new chain set
    \$IPTABLES -N "\$CHAIN"

    # tie chain to input rules so it runs
    \$IPTABLES -A INPUT -j "\$CHAIN"

    # don't allow this traffic through
    \$IPTABLES -A FORWARD -j "\$CHAIN"

    echo "Chain not detected. Creating new chain and adding Spamhaus list...."
fi;

for URL in \$URLS; do
    # get a copy of the spam list
    echo "Fetching \$URL ..."
    wget -qc "\$URL" -O "\$FILE"
    tail "\$FILE"

    # iterate through all known spamming hosts
    for IP in \$( cat "\$FILE" | egrep -v '^;' | cut -d' ' -f1 ); do
        # add the ip address log rule to the chain
        \$IPTABLES -A "\$CHAIN" -p 0 -s "\$IP" -j LOG --log-prefix "[SPAMHAUS BLOCK]" -m limit --limit 3/min --limit-burst 10

        # add the ip address to the chain
        \$IPTABLES -A "\$CHAIN" -p 0 -s "\$IP" -j DROP

        echo "\$IP"
    done

    # remove the spam list
    unlink "\$FILE"
done

echo "Done!"
SPAMHAUS_ENABLE

# Make the file executable
chmod +x "$SCRIPTS"/spamhaus_cronjob.sh

# Add it to crontab
crontab -u root -l | grep -v "$SCRIPTS/spamhaus_crontab.sh 2>&1" | crontab -u root -
crontab -u root -l | { cat; echo "10 2 * * * $SCRIPTS/spamhaus_crontab.sh 2>&1"; } | crontab -u root -

# Run it for the first time
msg_box "We will now add a number of bad IP-addresses to your IPtables block list, meaning that all IPs on that list will be blocked as they are known for doing bad stuff.

The script will be run on a schelude to update the IP-addresses, and can be found in $SCRIPTS/spamhaus_cronjob.sh.

To disable it, please remove the crontab by executing 'crontab -e' and remove this:
10 2 * * * $SCRIPTS/spamhaus_crontab.sh 2>&1"

if check_command bash "$SCRIPTS"/spamhaus_cronjob.sh
then
    print_text_in_color "$IGreen" "Security added!"
    restart_webserver
fi
