#!/bin/bash

# T&M Hansson IT AB © - 2026, https://www.hanssonit.se/
# Copyright © 2021 Simon Lindner (https://github.com/szaimen)

true
SCRIPT_NAME="Jellyfin Media Server"
SCRIPT_EXPLAINER="Jellyfin is a free software media system that lets \
you stream all your photos, music, videos, and movies to any device from your own server."
# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Check if root
root_check

# Check if already installed
if ! is_docker_running || ! docker ps -a --format "{{.Names}}" | grep -q "^jellyfin$"
then
    # Ask for installing
    install_popup "$SCRIPT_NAME"
else
    # Ask for removal or reinstallation
    reinstall_remove_menu "$SCRIPT_NAME"
    # Removal
    # Get the currently used subdomain from the container to be able to remove its vhost
    OLD_SUBDOMAIN="$(docker inspect --format \
'{{range .Config.Env}}{{println .}}{{end}}' jellyfin 2>/dev/null \
| grep "^JELLYFIN_PublishedServerUrl=" | sed 's|^.*://||')"
    docker rm -f jellyfin &>/dev/null
    # Fall back to asking if the subdomain couldn't get read from the container,
    # e.g. if the container was already removed manually beforehand
    if [ -z "$OLD_SUBDOMAIN" ]
    then
        OLD_SUBDOMAIN=$(input_box_flow "Please enter the subdomain that you've used for Jellyfin, \
e.g: jellyfin.yourdomain.com. Its certificate and Apache2 configuration will be removed.")
    fi
    # Remove the certificate
    if [ -f "$CERTFILES/$OLD_SUBDOMAIN/cert.pem" ]
    then
        yes no | certbot revoke --cert-path "$CERTFILES/$OLD_SUBDOMAIN/cert.pem"
        REMOVE_OLD="$(find "$LETSENCRYPTPATH/" -name "$OLD_SUBDOMAIN*")"
        for remove in $REMOVE_OLD
            do rm -rf "$remove"
        done
    fi
    # Remove the Apache2 configuration
    if [ -f "$SITES_AVAILABLE/$OLD_SUBDOMAIN.conf" ]
    then
        a2dissite "$OLD_SUBDOMAIN.conf" &>/dev/null
        rm -f "$SITES_AVAILABLE/$OLD_SUBDOMAIN.conf"
        restart_webserver
    fi
    # Delete firewall entries
    for port in 8096/tcp 8920/tcp 1900/udp 7359/udp
    do
        ufw delete allow "$port" &>/dev/null
    done
    # Remove the daily jail reload timer
    if [ -f /etc/systemd/system/fail2ban-jellyfin-reload.timer ]
    then
        systemctl disable --now fail2ban-jellyfin-reload.timer &>/dev/null
        rm -f /etc/systemd/system/fail2ban-jellyfin-reload.timer
        rm -f /etc/systemd/system/fail2ban-jellyfin-reload.service
        systemctl daemon-reload
    fi
    # Remove the fail2ban jail and filter
    if [ -f /etc/fail2ban/jail.d/jellyfin.local ] || [ -f /etc/fail2ban/filter.d/jellyfin.local ]
    then
        # Unban all ip addresses that are currently banned by the jellyfin jail before
        # removing its configuration. This needs to happen while the jail still exists
        # since reloading fail2ban with the jail already gone would leave its iptables
        # chain and all its ban rules behind without any way to unban them afterwards.
        if is_this_installed fail2ban
        then
            start_if_stopped fail2ban
            countdown "Waiting for fail2ban to start... " 5
            print_text_in_color "$ICyan" "Unbanning all ip addresses that were banned by Jellyfin..."
            fail2ban-client set jellyfin unban --all &>/dev/null
        fi
        rm -f /etc/fail2ban/jail.d/jellyfin.local
        rm -f /etc/fail2ban/filter.d/jellyfin.local
        if is_this_installed fail2ban
        then
            fail2ban-client reload &>/dev/null
        fi
    fi
    # The user-data is kept on purpose so that a reinstallation doesn't lose the library
    if [ "$REINSTALL_REMOVE" = "Uninstall" ]
    then
        msg_box "The Jellyfin user-data was NOT removed and is still stored here:
'/home/plex/jellyfin'

If you want to delete it as well, e.g. to be able to start from scratch \
if you install Jellyfin again later on, please run the following command:
'sudo rm -r /home/plex/jellyfin'

Attention! This will delete your Jellyfin settings, users and metadata. \
The media files on your mounted drives will not be touched."
    else
        msg_box "Please note that the Jellyfin user-data in '/home/plex/jellyfin' \
will be kept, which means that your current settings, users and metadata \
will still be there after the reinstallation.

If you want to start from scratch instead, please abort this script now with 'CTRL+C' \
and run the following command before running it again:
'sudo rm -r /home/plex/jellyfin'"
    fi
    # Show successful uninstall if applicable
    removal_popup "$SCRIPT_NAME"
fi

# Test Hardware transcoding
DRI_DEVICE=(--device=/dev/dri:/dev/dri -d)
if lspci -v -s "$(lspci | grep VGA | cut -d" " -f 1)" | grep -q "Kernel driver in use: i915"
then
    msg_box "Hardware transcoding is available. It is recommended to activate this in Jellyfin later \
under 'Dashboard' --> 'Playback' --> 'Transcoding' by choosing 'Intel QuickSync (QSV)' as hardware acceleration. \
You can learn more about it here: 'https://jellyfin.org/docs/general/administration/hardware-acceleration'"
else
    msg_box "Hardware transcoding is NOT available. It is not recommended to continue."
    if ! yesno_box_no "Do you want to continue nonetheless?"
    then
        exit 1
    fi
    # -d is here since the docker run command would fail if DRI_DEVICE is empty
    DRI_DEVICE=(-d)
fi

# Find mounts
DIRECTORIES=$(find /mnt/ -mindepth 1 -maxdepth 2 -type d | grep -v "/mnt/ncdata")
mapfile -t DIRECTORIES <<< "$DIRECTORIES"
for directory in "${DIRECTORIES[@]}"
do
    # Open directory to make sure that it is accessible
    ls "$directory" &>/dev/null

    # Continue with the logic
    if mountpoint -q "$directory" && [ "$(stat -c '%a' "$directory")" = "770" ]
    then
        if [ "$(stat -c '%U' "$directory")" = "www-data" ] && [ "$(stat -c '%G' "$directory")" = "www-data" ]
        then
            MOUNTS+=(-v "$directory:$directory:ro")
        elif [ "$(stat -c '%U' "$directory")" = "plex" ] && [ "$(stat -c '%G' "$directory")" = "plex" ]
        then
            MOUNTS+=(-v "$directory:$directory:ro")
        fi
    fi
done
if [ -z "${MOUNTS[*]}" ]
then
    msg_box "No usable drive found. You have to mount a new drive in /mnt."
    exit 1
fi

# Ask for the domain for Jellyfin
SUBDOMAIN=$(input_box_flow "Jellyfin subdomain e.g: jellyfin.yourdomain.com
NOTE: This domain must be different than your Nextcloud domain. \
They can however be hosted on the same server, but would require separate DNS entries.")

# Nextcloud Main Domain
NCDOMAIN=$(nextcloud_occ_no_check config:system:get overwrite.cli.url | sed 's|https://||;s|/||')

# Re-source the library so that all variables that depend on $SUBDOMAIN
# (e.g. $HTTPS_CONF and $DHPARAMS_SUB) get set based on the entered subdomain
true
# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh

# Notification
msg_box "Before continuing, please make sure that you have \
edited the DNS settings for $SUBDOMAIN, and opened port 80 and 443 \
directly to this servers IP. A full extensive guide can be found here:
https://www.techandme.se/open-port-80-443

This can be done automatically if you have UPNP enabled in your firewall/router. \
You will be offered to use UPNP in the next step."

if yesno_box_no "Do you want to use UPNP to open port 80 and 443?"
then
    unset FAIL
    open_port 80 TCP
    open_port 443 TCP
    cleanup_open_port
fi

# Get the latest packages
apt-get update -q4 & spinner_loading

# Check if Nextcloud is installed
print_text_in_color "$ICyan" "Checking if Nextcloud is installed..."
if ! curl -s https://"$NCDOMAIN"/status.php | grep -q 'installed":true'
then
    msg_box "It seems like Nextcloud is not installed or that you don't use https on:
$NCDOMAIN.
Please install Nextcloud and make sure your domain is reachable, or activate TLS
on your domain to be able to run this script.
If you use the Nextcloud VM you can use the Let's Encrypt script to get TLS and activate your Nextcloud domain.
When TLS is activated, run these commands from your CLI:
sudo curl -sLO $NOT_SUPPORTED_FOLDER/jellyfin.sh
sudo bash jellyfin.sh"
    exit 1
fi

# Check if $SUBDOMAIN exists and is reachable
print_text_in_color "$ICyan" "Checking if $SUBDOMAIN exists and is reachable..."
domain_check_200 "$SUBDOMAIN"

# Check open ports with NMAP
check_open_port 80 "$SUBDOMAIN"
check_open_port 443 "$SUBDOMAIN"

# Check if Nextcloud is installed with TLS
check_nextcloud_https "Jellyfin"

# Install Docker
install_docker

# Create plex user
# We re-use the plex user here since it also gets created by the mount scripts
# and owns the mounted drives, which is needed to be able to read the media files
if ! id plex &>/dev/null
then
    check_command adduser --no-create-home --quiet --disabled-login --uid 1005 --gid 1006 --force-badname --gecos "" "plex"
fi

# Add the plex user to the www-data group
# This is needed so that the plex user can access the Nextcloud data directory
if ! id -nG plex | grep -qw www-data
then
    check_command usermod --append --groups www-data plex
fi

# Create home directory
# We re-use the plex home directory here since it is already covered
# by the backup- and restore scripts
mkdir -p /home/plex/jellyfin/config
mkdir -p /home/plex/jellyfin/cache
# This can take a while on reinstallations since it recurses through all
# the metadata that Jellyfin and Plex have stored in there over time
print_text_in_color "$ICyan" "Setting the correct permissions for '/home/plex'. This can take a while..."
chown -R plex:plex /home/plex
chmod -R 770 /home/plex

# Get docker container
print_text_in_color "$ICyan" "Getting Jellyfin..."
docker pull jellyfin/jellyfin:latest

# Create Jellyfin
# The host network is needed for DLNA and the automatic server discovery of the Jellyfin clients.
# Apache2 proxies https://$SUBDOMAIN to 127.0.0.1:8096 further down below.
# Jellyfin needs ports: 8096/tcp 8920/tcp 1900/udp 7359/udp
# The container runs as root so that it can access the render device for
# hardware transcoding and read the media files on the mounted drives.
print_text_in_color "$ICyan" "Installing Jellyfin..."
if ! docker run \
--name jellyfin \
--restart always \
--network=host \
-e TZ="$(cat /etc/timezone)" \
-e JELLYFIN_PublishedServerUrl="https://$SUBDOMAIN" \
-v /etc/timezone:/etc/timezone:ro \
-v /etc/localtime:/etc/localtime:ro \
-v /home/plex/jellyfin/config:/config \
-v /home/plex/jellyfin/cache:/cache \
"${MOUNTS[@]}" \
"${DRI_DEVICE[@]}" \
jellyfin/jellyfin:latest
then
    msg_box "Failed to create the Jellyfin container.

Please report this issue here $ISSUES if you can't solve it yourself."
    # Remove the container leftovers so that this script can be run again
    docker rm -f jellyfin &>/dev/null
    exit 1
fi

# Add prune command
add_dockerprune

# Add firewall rules
for port in 8096/tcp 8920/tcp 1900/udp 7359/udp
do
    ufw allow "$port" comment "Jellyfin $port" &>/dev/null
done

# Inform about fail2ban
msg_box "We will now set up fail2ban for you to protect the Jellyfin login \
against brute-force attacks.

Please note that this requires the Jellyfin log level to stay at its default 'Information' \
since Jellyfin doesn't log failed logins on higher log levels. So please don't raise the \
log level in '/home/plex/jellyfin/config/logging.json' if you want to keep fail2ban working.

It will also require one manual step in Jellyfin afterwards to make fail2ban work at all. \
We will show you the needed instructions at the end of this script."

# Install fail2ban
install_if_not fail2ban
systemctl stop fail2ban

# Make sure that the log directory exists since fail2ban would otherwise
# fail to start because it cannot find the logpath of the jail.
# Jellyfin creates the directory itself on its first start, but it can take
# a few seconds until the container is up and running.
mkdir -p /home/plex/jellyfin/config/log
chown -R plex:plex /home/plex/jellyfin/config
chmod -R 770 /home/plex/jellyfin/config

# Jellyfin filter
# The failregex is the one that is recommended by the official Jellyfin documentation:
# https://jellyfin.org/docs/general/post-install/networking/advanced/fail2ban/
# It matches failed logins that Jellyfin logs to its own logfiles like this:
# [2026-01-01 00:00:00.000 +01:00] [INF] [20] Jellyfin.Server.Implementations.Users.UserManager:
# Authentication request for "username" has been denied (IP: "1.2.3.4").
cat << JELLYFIN_CONF > /etc/fail2ban/filter.d/jellyfin.local
[INCLUDES]
before = common.conf

[Definition]
failregex = ^.*Authentication request for .* has been denied \(IP: "<ADDR>"\)\.
ignoreregex =
JELLYFIN_CONF

# Jellyfin jail
# The container runs in the host network, which means that the traffic hits the
# regular INPUT chain of the host and not the DOCKER-USER chain. Hence we use the
# default chain here and not 'chain=DOCKER-USER' as the Jellyfin documentation
# recommends for containers that publish their ports via the docker bridge.
# This only bans anyone if '127.0.0.1' was added to the 'Known proxies' of Jellyfin,
# which the user has to do manually. See the final msg_box of this script.
cat << JELLYFIN_JAIL_CONF > /etc/fail2ban/jail.d/jellyfin.local
[jellyfin]
backend = auto
enabled = true
port = 80,443,8096,8920
filter = jellyfin
action = iptables-allports[name=jellyfin]
logpath = /home/plex/jellyfin/config/log/log_*.log
maxretry = 10
bantime = 1209600
findtime = 1800
ignoreip = 127.0.0.1/8 192.168.0.0/16 172.16.0.0/12 10.0.0.0/8
JELLYFIN_JAIL_CONF

# Jellyfin rotates its logs daily and creates a new logfile in the process.
# fail2ban doesn't pick up the new logfile on its own, which is why the official
# Jellyfin documentation recommends to reload the jail once a day after the rotation.
cat << JELLYFIN_RELOAD_SERVICE > /etc/systemd/system/fail2ban-jellyfin-reload.service
[Unit]
Description=Reload the fail2ban jellyfin jail
# Only run if fail2ban is actually up. Otherwise the reload would fail and
# clutter the journal with failed units, e.g. if the timer fires while
# fail2ban is stopped or not yet started after a reboot.
Requires=fail2ban.service
After=fail2ban.service

[Service]
Type=oneshot
ExecStart=/usr/bin/fail2ban-client reload jellyfin
JELLYFIN_RELOAD_SERVICE

cat << JELLYFIN_RELOAD_TIMER > /etc/systemd/system/fail2ban-jellyfin-reload.timer
[Unit]
Description=Reload the fail2ban jellyfin jail daily

[Timer]
OnCalendar=*-*-* 00:45:00
Persistent=true

[Install]
WantedBy=timers.target
JELLYFIN_RELOAD_TIMER

systemctl daemon-reload

# Start fail2ban before enabling the timer so that the jail is loaded
# and the reload service can talk to a running fail2ban instance
start_if_stopped fail2ban
countdown "Waiting for fail2ban to start... " 5
check_command fail2ban-client reload

check_command systemctl enable --now fail2ban-jellyfin-reload.timer

# Install apache2
install_if_not apache2

# Enable Apache2 module's
a2enmod proxy
a2enmod proxy_wstunnel
a2enmod proxy_http
a2enmod ssl
a2enmod headers
a2enmod rewrite
a2enmod remoteip

# Only add TLS 1.3 on supported Ubuntu releases
if version "$SUPPORTED_VERSION_MIN" "$DISTRO" "$SUPPORTED_VERSION_MAX"
then
    TLS13="+TLSv1.3"
fi

if [ -f "$HTTPS_CONF" ]
then
    a2dissite "$SUBDOMAIN.conf"
    rm -f "$HTTPS_CONF"
fi

# Create Vhost for Jellyfin in Apache2
if [ ! -f "$HTTPS_CONF" ];
then
    cat << HTTPS_CREATE > "$HTTPS_CONF"
<VirtualHost *:443>
     ServerName $SUBDOMAIN:443

    SSLCertificateChainFile $CERTFILES/$SUBDOMAIN/chain.pem
    SSLCertificateFile $CERTFILES/$SUBDOMAIN/cert.pem
    SSLCertificateKeyFile $CERTFILES/$SUBDOMAIN/privkey.pem
    SSLOpenSSLConfCmd DHParameters $DHPARAMS_SUB

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

    # Improve security settings
    Header set X-XSS-Protection "1; mode=block"
    Header set Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
    Header set X-Content-Type-Options nosniff
    Header set Content-Security-Policy "frame-ancestors 'self' $NCDOMAIN"

    # contra mixed content warnings
    RequestHeader set X-Forwarded-Proto "https"

    # Let Jellyfin log the real ip of failed logins instead of 127.0.0.1 for fail2ban.
    # 'set' overwrites the header so that it can't get spoofed to ban an innocent ip.
    RequestHeader set X-Forwarded-For %{REMOTE_ADDR}s

    # basic proxy settings
    ProxyRequests off
    ProxyPreserveHost On

    ProxyPass / "http://127.0.0.1:8096/"
    ProxyPassReverse / "http://127.0.0.1:8096/"
    RewriteEngine on
    RewriteCond %{HTTP:Upgrade} websocket [NC]
    RewriteCond %{HTTP:Connection} upgrade [NC]
    RewriteRule ^/?(.*) "ws://127.0.0.1:8096/\$1" [P,L]

    <Location />
        ProxyPassReverse /
    </Location>
</VirtualHost>
HTTPS_CREATE

    if [ -f "$HTTPS_CONF" ];
    then
        print_text_in_color "$IGreen" "$HTTPS_CONF was successfully created."
        sleep 1
    else
        print_text_in_color "$IRed" "Unable to create vhost, exiting..."
        print_text_in_color "$IRed" "Please report this issue here $ISSUES"
        exit 1
    fi
fi

# Install certbot (Let's Encrypt)
install_certbot

# Generate certs
if generate_cert "$SUBDOMAIN"
then
    # Generate DHparams cipher
    if [ ! -f "$DHPARAMS_SUB" ]
    then
        openssl dhparam -out "$DHPARAMS_SUB" 2048
    fi
    print_text_in_color "$IGreen" "Certs are generated!"
    a2ensite "$SUBDOMAIN.conf"
    restart_webserver
else
    # Remove the container and the vhost to be able to start over again
    docker rm -f jellyfin &>/dev/null
    rm -f "$HTTPS_CONF"
    last_fail_tls "$SCRIPTS"/not-supported/jellyfin.sh
    exit 1
fi

# Inform the user
msg_box "Jellyfin was successfully installed and is now reachable via https://$SUBDOMAIN

Please visit 'https://$SUBDOMAIN' to set up your Jellyfin Media Server next and \
make sure to directly create your admin user since Jellyfin isn't protected before you did that.

Advice: All your drives should be mounted in a subfolder of '/mnt'

Please note that Jellyfin runs in the host network so that DLNA and the automatic server \
discovery of the Jellyfin clients work. This means that Jellyfin is additionally reachable \
unencrypted inside your local network on 'http://$ADDRESS:8096'. \
It is recommended to always use 'https://$SUBDOMAIN' instead.

fail2ban was set up as well and bans ip addresses that failed to log in 20 times within 30 minutes. \
You can unban ip addresses by executing the following command:
'sudo fail2ban-client set jellyfin unbanip XX.XX.XX.XX'

ATTENTION! One manual step is required to make fail2ban work!

Jellyfin runs behind a reverse proxy, which is why it logs '127.0.0.1' for every failed \
login instead of the real ip address of the attacker. Since '127.0.0.1' is on the ignore \
list of fail2ban, nobody would ever get banned like this.

To fix this, please do the following after you have created your admin user:
1. Go to 'Dashboard' --> 'Networking' in Jellyfin
2. Enter '127.0.0.1' in the 'Known proxies' field
3. Click on 'Save'
4. Restart Jellyfin by running 'sudo docker restart jellyfin'

Once you have at least one failed login attempt, you can test the jail with this command:
'sudo fail2ban-regex /home/plex/jellyfin/config/log/log_*.log \
/etc/fail2ban/filter.d/jellyfin.local --print-all-matched'
The ip addresses shown there must be real ip addresses and not '127.0.0.1'."

exit
