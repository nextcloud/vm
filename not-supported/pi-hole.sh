#!/bin/bash

# T&M Hansson IT AB © - 2024, https://www.hanssonit.se/
# Copyright © 2021 Simon Lindner (https://github.com/szaimen)

# shellcheck disable=2016,2034,2059,2178,2317
true
SCRIPT_NAME="Pi-hole"
SCRIPT_EXPLAINER="The Pi-hole® is a DNS sinkhole that protects your devices from unwanted content, \
without installing any client-side software.
This is their official website: https://pi-hole.net"
# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Check if root
root_check

msg_box "The pi-hole script is unfortunately deprecated as it needs a rewrite since many parts in the upstream pi-hole project changed.
Feel free to subscribe to https://github.com/szaimen/Nextcloud-NAS-Guide/issues/133 in the meantime."
exit 1

# Check if already installed
if ! pihole &>/dev/null
then
    # Ask for installing
    install_popup "$SCRIPT_NAME"
else
    # Choose to uninstall
    if ! yesno_box_no "It seems like Pi-hole is already installed.
Do you want to uninstall Pi-hole and reset all its settings?"
    then
        exit 1
    fi

    # Check if PiVPN is installed
    if pivpn &>/dev/null
    then
        msg_box "It seems like PiVPN is installed.
We recommend urgently to uninstall PiVPN before uninstalling Pi-hole \
because it could happen, that PiVPN doesn't work anymore after uninstalling Pi-hole."
        exit 1
    fi

    # Warning
    msg_box "Warning!
Uninstalling Pi-hole will reset all its config and will reboot your NcVM afterwards automatically."
    
    # Last choice
    if ! yesno_box_no "Do you want to continue nonetheless?"
    then
        exit 1
    fi

    # Get initially installed programs from pihole-update.sh
    INSTALLED=$(grep "Pi-hole installed programs=" "$SCRIPTS/pihole-update.sh")
    INSTALLED="${INSTALLED##*programs=}"

    # Inform the user
    if ! yesno_box_yes "These are all packets that where installed during your initial Pi-hole installation:
$INSTALLED

Do they look correct to you? If not, you can press 'no' and we will not remove anything.
If you press 'yes', we will remove Pi-hole, its settings and all those listed programs."
    then
        exit 1
    fi
    
    # Make an array from installed applications
    read -r -a INSTALLED <<< "$INSTALLED"

    # /opt/pihole/uninstall.sh edit file and put setupVars variable setupVars="/etc/pihole/setupVars.conf" at 5th line or something

    UNINSTALL="/etc/.pihole/automated install/uninstall.sh"
    # Uninstall pihole; we need to modify it, else it is not unattended
    if ! [ -f "$UNINSTALL" ] || ! grep -q "######### SCRIPT ###########" "$UNINSTALL" || ! grep -q "removeNoPurge()" "$UNINSTALL"
    then
        msg_box "It seems like some uninstall functions changed.
Please report this to $ISSUES"
        exit 1
    fi

    # Continue with preparation
    check_command cp "/etc/.pihole/automated install/uninstall.sh" "$SCRIPTS"/pihole-uninstall.sh
    check_command sed -i '/######### SCRIPT ###########/q' "$SCRIPTS"/pihole-uninstall.sh
    check_command echo "removeNoPurge" >> "$SCRIPTS"/pihole-uninstall.sh
    
    # Uninstall Pi-hole
    check_command yes | bash "$SCRIPTS"/pihole-uninstall.sh

    # Remove the file and crontab
    crontab -u root -l | grep -v "pihole-update.sh"  | crontab -u root -
    check_command rm "$SCRIPTS"/pihole-uninstall.sh

    # Delete the pihole user
    if id pihole &>/dev/null
    then
        check_command killall -u pihole
        check_command deluser pihole &>/dev/null
        check_command groupdel pihole
    fi

    # Delete all its config data
    rm -rf /etc/.pihole
    rm -rf /etc/pihole
    rm -rf /opt/pihole
    rm -rf /usr/bin/pihole-FTL
    rm -rf /usr/local/bin/pihole
    rm -rf /var/www/html/admin
    rm -f /var/www/html/pihole

    # Delete unbound config
    crontab -u root -l | grep -v "systemctl restart unbound"  | crontab -u root -
    rm /etc/unbound/unbound.conf.d/pi-hole.conf

    # Remove update script
    rm -f "$SCRIPTS/pihole-update.sh"

    # Remove all initially installed applications
    for program in "${INSTALLED[@]}"
    do
        apt-get purge "$program" -y
    done

    # Remove unbound
    if is_this_installed unbound
    then
        apt-get purge unbound -y
    fi

    # Remove not needed dependencies
    apt-get autoremove -y

    # Delete other files
    rm -f /var/www/html/index.lighttpd.orig
    rm -rf /etc/lighttpd

    # Remove apache conf
    a2dissite pihole.conf &>/dev/null
    rm -f "$SITES_AVAILABLE/pihole.conf"
    restart_webserver
    
    # Delete firewall entry
    ufw delete allow 53/tcp &>/dev/null
    ufw delete allow 53/udp &>/dev/null
    ufw delete allow 8094/tcp &>/dev/null

    # Inform the user
    msg_box "Pi-hole was successfully uninstalled!
Please reset the DNS on your router/clients to restore internet connectivity"
    msg_box "After you hit OK, your NcVM will get restarted."
    rm -f "$SCRIPTS/pi-hole.sh"
    # Reboot the NcVM because it would cause problems if not
    reboot
fi

# Inform the user
msg_box "Before installing the Pi-hole, please make sure that you have a backup of your NcVM.
The reason is, that to install the Pi-hole we will need to run a 3rd party script on your NcVM.
Something could go wrong. So please keep backups!"

# Ask if backups are ready
if ! yesno_box_no "Have you made a backup of your NcVM?
This is the last possibility to quit!
If you choose 'yes' we will continue with the installtion."
then
    exit 1
fi

# Inform the user
print_text_in_color "$ICyan" "Installing Pi-hole..."

# Download the script
mkdir -p "$SCRIPTS"
check_command curl -sfL https://install.pi-hole.net  -o "$SCRIPTS"/pihole-install.sh 

# Check that all patterns match
if ! grep -q 'displayFinalMessage "${pw}"' "$SCRIPTS"/pihole-install.sh  || ! grep -q "setAdminFlag$" "$SCRIPTS"/pihole-install.sh \
|| ! grep -q "chooseInterface$" "$SCRIPTS"/pihole-install.sh || ! grep -q "getStaticIPv4Settings$" "$SCRIPTS"/pihole-install.sh
then
    msg_box "It seems like some functions in pihole-install.sh have changed.
Please report this to $ISSUES"
    exit 1
fi

# Continue with the process
sed -i 's|displayFinalMessage "${pw}"|echo displayFinalMessage|' "$SCRIPTS"/pihole-install.sh # We don't want to display the final message
sed -i "s|setAdminFlag$|echo setAdminFlag|" "$SCRIPTS"/pihole-install.sh # We want to install the web-interface and lighttpd
sed -i "s|chooseInterface$|echo chooseInterface|" "$SCRIPTS"/pihole-install.sh # We don't want the user choose the interface
sed -i "s|getStaticIPv4Settings$|echo getStaticIPv4Settings|" "$SCRIPTS"/pihole-install.sh # We don't want to set a static ip4

# Export default values
PIHOLE_INTERFACE="$IFACE"
export PIHOLE_INTERFACE

# Fix php versions getting hold for pi-hole install script
apt-mark unhold php"$PHPVER"*

# Run the script
bash "$SCRIPTS"/pihole-install.sh | tee "$SCRIPTS"/pihole-install.report

# Get all installed and remove pihole-install.sh
unset INSTALLED
INSTALLED=$(grep "Checking for" "$SCRIPTS"/pihole-install.report | grep "will be installed" | awk '{print $8}')
check_command rm "$SCRIPTS"/pihole-install.sh
check_command rm "$SCRIPTS"/pihole-install.report

# Check if at least one app got installed
if [ -z "${INSTALLED[*]}" ]
then
    msg_bos "Something is wrong. Didn't expect that no requirement get installed.
Please report this to $ISSUES"
fi

# Make an array from installed applications
mapfile -t INSTALLED <<< "${INSTALLED[@]}"

# Create update script
mkdir -p "$SCRIPTS"

# Insert the new lines into pihole-update.sh
cat << PIHOLE_UPDATE > "$SCRIPTS/pihole-update.sh"
#!/bin/bash
. <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/main/lib.sh)
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/snap/bin
notify_admin_gui "Starting the Pi-hole update." "You will be notified when it is done."
# Create backup first
if [ -f "\$SCRIPTS/daily-borg-backup.sh" ]
then
    rm -f /tmp/DAILY_BACKUP_CREATION_SUCCESSFUL
    export SKIP_DAILY_BACKUP_CHECK=1
    bash "\$SCRIPTS/daily-borg-backup.sh"
    if ! [ -f "/tmp/DAILY_BACKUP_CREATION_SUCCESSFUL" ]
        then
            notify_admin_gui "Pi-hole update failed because backup could not be created!" \
            "Could not create a backup! \$(date +%T)"
            exit 1
        fi
fi
check_command pihole -up
systemctl stop lighttpd
check_command sed -i 's|^server\.port.*|server\.port = 8093|' /etc/lighttpd/lighttpd.conf
sleep 10 # Wait for lighttpd
check_command systemctl start lighttpd
# Please don't remove or change this line! Pi-hole installed programs=${INSTALLED[@]}
notify_admin_gui "Pi-hole update successful!" ""
PIHOLE_UPDATE

# Secure the file
chown root:root "$SCRIPTS/pihole-update.sh"
chmod 700 "$SCRIPTS/pihole-update.sh"

# Check if Pi-hole was successfully installed
if ! pihole &>/dev/null
then
    msg_box "Something got wrong during pihole-install.sh
Please report this to $ISSUES"
    exit 1
fi

# Set up REV_SERVER for local DNS entries because Pi-hole isn't the DHCP server and some other settings
if [ -f /etc/pihole/setupVars.conf ] && ! grep -q "REV_SERVER" /etc/pihole/setupVars.conf
then
    cat << PIHOLE_CONF >> /etc/pihole/setupVars.conf
REV_SERVER=true
REV_SERVER_CIDR=$(ip route | grep -v "default via" | grep "$IFACE" | awk '{print $1}' | grep "/")
REV_SERVER_TARGET=$GATEWAY
REV_SERVER_DOMAIN=
PIHOLE_CONF
fi

# Make sure that local DNS entries work
if [ -f /etc/pihole/setupVars.conf ] && ! grep -q "DNS_FQDN_REQUIRED" /etc/pihole/setupVars.conf && ! grep -q "DNS_BOGUS_PRIV" /etc/pihole/setupVars.conf
then
    cat << PIHOLE_CONF >> /etc/pihole/setupVars.conf
DNS_FQDN_REQUIRED=false
DNS_BOGUS_PRIV=false
PIHOLE_CONF
fi

# Wait for pihole to restart
print_text_in_color "$ICyan" "Restarting pihole..."
sleep 5

# Try to restart Pi-hole to apply the new settings
if ! pihole restartdns
then
    msg_box "Something got wrong during the Pi-hole restart.
Please report this to $ISSUES"
    exit 1
fi

# Change the port to 8093
check_command sudo sed -i '/^server.port/s/80/8093/' /etc/lighttpd/lighttpd.conf

# Wait for lighttpd to startup
print_text_in_color "$ICyan" "Restarting lighttpd..."
sleep 5

# Restart lighttpd
if ! systemctl restart lighttpd
then
    msg_box "Couldn't restart lighttpd.
Please report this to $ISSUES"
    exit 1
fi

# Install Apache2 
print_text_in_color "$ICyan" "Configuring Apache..."
install_if_not apache2
a2enmod headers
a2enmod rewrite
a2enmod ssl
a2enmod proxy
a2enmod proxy_http

# Only add TLS 1.3 on Ubuntu later than 22.04
if version 22.04 "$DISTRO" 24.04.10
then
    TLS13="+TLSv1.3"
fi

cat << PIHOLE_CONF > "$SITES_AVAILABLE/pihole.conf"
Listen 8094
<VirtualHost *:8094>
    Header add Strict-Transport-Security: "max-age=15768000;includeSubdomains"
		
    # Intermediate configuration
    SSLEngine               on
    SSLCompression          off
    SSLProtocol             -all +TLSv1.2 $TLS13
    SSLCipherSuite          ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384 
    SSLHonorCipherOrder     off
    SSLSessionTickets       off
    ServerSignature         off
		
    # Logs
    LogLevel warn
    CustomLog \${APACHE_LOG_DIR}/access.log combined
    ErrorLog \${APACHE_LOG_DIR}/error.log
		
    # Just in case - see below
    SSLProxyEngine On
    SSLProxyVerify None
    SSLProxyCheckPeerCN Off
    SSLProxyCheckPeerName Off
		
    # This is needed to redirect access on http://$ADDRESS:8094/ to https://$ADDRESS:8094/
    ErrorDocument 400 https://$ADDRESS:8094/admin/
		
    # basic proxy settings
    ProxyRequests off
    ProxyPass / "http://127.0.0.1:8093/"
    ProxyPassReverse / "http://127.0.0.1:8093/"
    ProxyPreserveHost On
		
### LOCATION OF CERT FILES ###
    SSLCertificateFile /etc/ssl/certs/ssl-cert-snakeoil.pem
    SSLCertificateKeyFile /etc/ssl/private/ssl-cert-snakeoil.key
</VirtualHost>
PIHOLE_CONF

# Enable config
check_command a2ensite pihole.conf

# Restart webserver
if ! restart_webserver
then
    msg_box "Apache2 could not restart...
The script will exit."
    exit 1
fi

# Generate new Pi-hole password
PASSWORD=$(gen_passwd 12 "a-zA-Z0-9")

# Set a new admin password
check_command pihole -a -p "$PASSWORD"

# Get the ipv6-address from the config file
IPV6_ADDRESS=$(grep "IPV6_ADDRESS=" /etc/pihole/setupVars.conf)
IPV6_ADDRESS="${IPV6_ADDRESS##*IPV6_ADDRESS=}"

# Create contab entry
crontab -u root -l | grep -v "pihole-update.sh"  | crontab -u root -
crontab -u root -l | { cat; echo "30 19 * * 6 $SCRIPTS/pihole-update.sh >/dev/null" ; } | crontab -u root -

# Add firewall entry
ufw allow 53/tcp comment 'Pi-hole TCP' &>/dev/null
ufw allow 53/udp comment 'Pi-hole UDP' &>/dev/null
ufw allow 8094/tcp comment 'Pi-hole Web' &>/dev/null

# Show that everything was set up correctly
msg_box "Congratulations, your Pi-hole was set up correctly!
It is now reachable on:
https://$ADDRESS:8094/admin

Your password is: $PASSWORD"

# Show the address
msg_box "You can now configure your devices to use the Pi-hole as their DNS server using:
IPv4:	$ADDRESS
IPv6:	${IPV6_ADDRESS:-Not Configured}"

# Show how to use pihole in the command line
msg_box "How to use Pi-hole on the command line:

You can reset the Pi-hole admin password by running:
'pihole -a -p'

A list of available options is shown by running:
'pihole -h'"

# Inform about updates
msg_box "Concerning updates:
We have created an update script that you can use to update your Pi-hole by running:
'bash $SCRIPTS/pihole-update.sh'

Updates will automatically be executed every saturday at 19:30"

# Ask if the user wants to install unbound
if ! yesno_box_yes "Do you want to enables your Pi-hole to be a recursive DNS server?
If you press 'yes', we will install unbound and configure your Pi-hole to use that."
then
    exit
fi

# Install needed tools
install_if_not unbound

cat << UNBOUND_CONF > /etc/unbound/unbound.conf.d/pi-hole.conf
server:
    # To see what those variables do, look here:
    # https://docs.pi-hole.net/guides/unbound/
    verbosity: 0
    interface: 127.0.0.1
    port: 5335
    do-ip4: yes
    do-udp: yes
    do-tcp: yes
    do-ip6: no
    prefer-ip6: no
    harden-glue: yes
    harden-dnssec-stripped: yes
    use-caps-for-id: no
    edns-buffer-size: 1472
    prefetch: yes
    num-threads: 1
    so-rcvbuf: 1m
    private-address: 192.168.0.0/16
    private-address: 169.254.0.0/16
    private-address: 172.16.0.0/12
    private-address: 10.0.0.0/8
    private-address: fd00::/8
    private-address: fe80::/10
UNBOUND_CONF

# Wait for unbound to restart
print_text_in_color "$ICyan" "Restarting unbound..."
sleep 10 & spinner_loading

# Restart unbound
check_command service unbound restart

# Testing DNSSEC
if ! dig sigfail.verteiltesysteme.net @127.0.0.1 -p 5335 | grep -q "SERVFAIL" 
then
    msg_box "Something got wrong while testing SERVFAIL.
Please report this to $ISSUES"
elif ! dig sigok.verteiltesysteme.net @127.0.0.1 -p 5335 | grep -q "NOERROR"
then
    msg_box "Something got wrong while testing NOERROR.
Please report this to $ISSUES"
fi

# Set up Pi-hole
sed -i 's|^PIHOLE_DNS_1=.*|PIHOLE_DNS_1=127.0.0.1#5335|' /etc/pihole/setupVars.conf
sed -i '/^PIHOLE_DNS_2=.*/d' /etc/pihole/setupVars.conf

# Wait for pihole to restart
print_text_in_color "$ICyan" "Restarting pihole..."
sleep 5

# Try to restart Pi-hole to apply the new settings
if ! pihole restartdns
then
    msg_box "Something got wrong during the Pi-hole unbound restart.
Please report this to $ISSUES"
    exit 1
fi

# Fix dns disconnections
crontab -u root -l | grep -v "systemctl restart unbound"  | crontab -u root -
crontab -u root -l | { cat; echo "@hourly systemctl restart unbound" ; } | crontab -u root -

# Inform the user
msg_box "Congratulations!
Unbound was successfully installed and Pi-hole was successfully configured as recursive DNS server."

exit
