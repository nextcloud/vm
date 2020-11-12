#!/bin/bash

# T&M Hansson IT AB © - 2020, https://www.hanssonit.se/

true
SCRIPT_NAME="Nextcloud Talk"
SCRIPT_EXPLAINER="This script installs Nextcloud Talk and also offers the possibility \
to install the so-called High-Performance-Backend, which makes it possible to host more video calls than it would be with the standard Talk app. \
It's called 'Talk Signaling' and you will be offered to install it as part two of this script."
# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh || source <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)

# Get all needed variables from the library
nc_update
turn_install

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Must be root
root_check

# Check if talk_signaling is already installed
if [ -z "$(nextcloud_occ_no_check config:app:get spreed turn_servers | sed 's/\[\]//')" ] \
&& ! is_this_installed coturn
then
    # Ask for installing
    install_popup "$SCRIPT_NAME"
else
    # Ask for removal or reinstallation
    reinstall_remove_menu "$SCRIPT_NAME"
    # Removal
    nextcloud_occ_no_check config:app:delete spreed stun_servers
    nextcloud_occ_no_check config:app:delete spreed turn_servers
    nextcloud_occ_no_check config:app:delete spreed signaling_servers
    nextcloud_occ_no_check app:remove spreed
    rm -rf \
        "$TURN_CONF" \
        "$SIGNALING_SERVER_CONF" \
        /etc/nats \
        /etc/janus \
        /etc/apt/trusted.gpg.d/morph027-janus.asc \
        /etc/apt/trusted.gpg.d/morph027-nats-server.asc \
        /etc/apt/trusted.gpg.d/morph027-nextcloud-spreed-signaling.asc \
        /etc/apt/sources.list.d/morph027-nextcloud-spreed-signaling.list\
        /etc/apt/sources.list.d/morph027-janus.list \
        /etc/apt/sources.list.d/morph027-nats-server.list \
        $VMLOGS/talk_apache_error.log \
        $VMLOGS/talk_apache_access.log \
        $VMLOGS/turnserver.log \
        /var/www/html/error
    APPS=(coturn nats-server janus nextcloud-spreed-signaling)
    for app in "${APPS[@]}"
    do
        if is_this_installed "$app"
        then
            apt purge "$app" -y
        fi
    done
    apt autoremove -y
    # Show successful uninstall if applicable
    removal_popup "$SCRIPT_NAME"
fi

# Must be 20.04
if ! version 20.04 "$DISTRO" 20.04.6
then
    msg_box "Your current Ubuntu version is $DISTRO but must be between 20.04 - 20.04.10 to install Talk"
    msg_box "Please contact us to get support for upgrading your server:
https://www.hanssonit.se/#contact
https://shop.hanssonit.se/"
exit
fi

# Nextcloud 19 is required.
lowest_compatible_nc 19

####################### TALK (COTURN)

# Check if Nextcloud is installed with TLS
check_nextcloud_https "Nextclod Talk"

# Let the user choose port. TURN_PORT in msg_box is taken from lib.sh and later changed if user decides to.
msg_box "The default port for Talk used in this script is port $TURN_PORT.
You can read more about that port here: https://www.speedguide.net/port.php?port=$TURN_PORT
You will now be given the option to change this port to something of your own. 
Please keep in mind NOT to use the following ports as they are likley to be in use already: 
${NONO_PORTS[*]}"

if yesno_box_no "Do you want to change port?"
then
    # Ask for port
    TURN_PORT=$(input_box_flow "Please enter the port you will use for Nextcloud Talk")
fi

containsElement () {
  local e match="$1"
  shift
  for e; do [[ "$e" == "$match" ]] && return 0; done
  return 1
}

if containsElement "$TURN_PORT" "${NONO_PORTS[@]}"
then
    msg_box "You have to choose another port. Please start over."
    exit 1
fi

# Install TURN
check_command install_if_not coturn
check_command sed -i '/TURNSERVER_ENABLED/c\TURNSERVER_ENABLED=1' /etc/default/coturn

# Create log for coturn
install -d -m 777 "$VMLOGS"
install -o turnserver -g turnserver -m 660 /dev/null /var/log

# Generate $TURN_CONF
cat << TURN_CREATE > "$TURN_CONF"
listening-port=$TURN_PORT
fingerprint
use-auth-secret
static-auth-secret=$TURN_SECRET
realm=$TURN_DOMAIN
total-quota=100
bps-capacity=0
stale-nonce
no-multicast-peers
no-stdout-log
simple-log
log-file=$VMLOGS/turnserver.log
TURN_CREATE
if [ -f "$TURN_CONF" ];
then
    print_text_in_color "$IGreen" "$TURN_CONF was successfully created."
else
    print_text_in_color "$IRed" "Unable to create $TURN_CONF, exiting..."
    print_text_in_color "$IRed" "Please report this issue here $ISSUES"
    exit 1
fi

# Restart the TURN server
check_command systemctl restart coturn.service

# Warn user to open port
msg_box "You have to open $TURN_PORT TCP/UDP in your firewall or your TURN/STUN server won't work!

This can be done automatically if you have UNNP enabled in your firewall/router. \
You will be offered to use UNNP in the next step.

After you hit OK, the script will check if the port is open or not. If it fails \
and you want to run this script again, just execute this in your CLI:
sudo bash /var/scripts/menu.sh, and choose 'Talk'."

if yesno_box_no "Do you want to use UPNP to open port $TURN_PORT?"
then
    unset FAIL
    open_port "$TURN_PORT" TCP
    open_port "$TURN_PORT" UDP
    cleanup_open_port
fi

# Check if the port is open
check_open_port "$TURN_PORT" "$TURN_DOMAIN"

# Enable Spreed (Talk)
STUN_SERVERS_STRING="[\"$TURN_DOMAIN:$TURN_PORT\"]"
TURN_SERVERS_STRING="[{\"server\":\"$TURN_DOMAIN:$TURN_PORT\",\"secret\":\"$TURN_SECRET\",\"protocols\":\"udp,tcp\"}]"

if ! is_app_enabled spreed
then
    install_and_enable_app spreed
fi

nextcloud_occ config:app:set spreed stun_servers --value="$STUN_SERVERS_STRING" --output json
nextcloud_occ config:app:set spreed turn_servers --value="$TURN_SERVERS_STRING" --output json
chown -R www-data:www-data "$NC_APPS_PATH"

msg_box "Nextcloud Talk is now installed. For more information about \
Nextcloud Talk and its mobile apps visit:\nhttps://nextcloud.com/talk/"

####################### SIGNALING

SCRIPT_NAME="Talk Signaling Server"

msg_box "You will now be presented with the option to install the Talk Signaling (STUN) server. 
This aims to give you greater performance and ability to have more users in a call at the same time.

You can read more here: 
https://github.com/strukturag/nextcloud-spreed-signaling/blob/master/README.md

We will use apt packages from https://gitlab.com/morph027 which is a trusted contributor to this repository.

The exact sources can be found here:
https://gitlab.com/packaging/nextcloud-spreed-signaling
https://gitlab.com/packaging/janus/"

# Ask the user if he/she wants the HPB server as well
if ! yesno_box_yes "Do you want to install the $SCRIPT_NAME?"
then
    exit 1
fi

# Ask for the domain for Talk
SUBDOMAIN=$(input_box_flow "Talk Signaling Server subdomain e.g: talk.yourdomain.com

NOTE: This domain must be different than your Nextcloud domain. \
They can however be hosted on the same server, but would require seperate DNS entries.")

# curl the lib another time to get the correct https_conf
# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh || source <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)

# Notification
msg_box "Before continuing, please make sure that you have you have \
edited the DNS settings for $SUBDOMAIN, and opened port 80 and 443 \
directly to this servers IP. A full exstensive guide can be found here:
https://www.techandme.se/open-port-80-443

This can be done automatically if you have UNNP enabled in your firewall/router. \
You will be offered to use UNNP in the next step.

PLEASE NOTE:
Using other ports than the default 80 and 443 is not supported, \
though it may be possible with some custom modification:
https://help.nextcloud.com/t/domain-refused-to-connect-collabora/91303/17"

if yesno_box_no "Do you want to use UPNP to open port 80 and 443?"
then
    unset FAIL
    open_port 80 TCP
    open_port 443 TCP
    cleanup_open_port
fi

# Check if $SUBDOMAIN exists and is reachable
print_text_in_color "$ICyan" "Checking if $SUBDOMAIN exists and is reachable..."
domain_check_200 "$SUBDOMAIN"

# Check open ports with NMAP
check_open_port 80 "$SUBDOMAIN"
check_open_port 443 "$SUBDOMAIN"

# NATS
## Pre-Configuration
mkdir -p /etc/nats
echo "listen: 127.0.0.1:4222" > /etc/nats/nats.conf
## Installation
curl -sL -o "/etc/apt/trusted.gpg.d/morph027-nats-server.asc" "https://packaging.gitlab.io/nats-server/gpg.key"
echo "deb [arch=amd64] https://packaging.gitlab.io/nats-server nats main" > /etc/apt/sources.list.d/morph027-nats-server.list
apt update -q4 & spinner_loading
install_if_not nats-server
chown nats:nats /etc/nats/nats.conf
start_if_stopped nats-server
check_command systemctl enable nats-server

# Janus WebRTC Server
## Installation
## TODO Fix shellcheck check, and remove the disable command
# shellcheck disable=SC1091
source /etc/lsb-release
curl -sL -o "/etc/apt/trusted.gpg.d/morph027-janus.asc" "https://packaging.gitlab.io/janus/gpg.key"
echo "deb [arch=amd64] https://packaging.gitlab.io/janus/$DISTRIB_CODENAME $DISTRIB_CODENAME main" > /etc/apt/sources.list.d/morph027-janus.list
apt update -q4 & spinner_loading
install_if_not janus
## Configuration
sed -i "s|#turn_rest_api_key\s*=.*|$JANUS_API_KEY|" /etc/janus/janus.jcfg
sed -i "s|#full_trickle|full_trickle|g" /etc/janus/janus.jcfg
sed -i 's|#interface.*|interface = "lo"|g' /etc/janus/janus.transport.websockets.jcfg
sed -i 's|#ws_interface.*|ws_interface = "lo"|g' /etc/janus/janus.transport.websockets.jcfg
start_if_stopped janus
check_command systemctl enable janus

# HPB
## Installation
curl -sL -o "/etc/apt/trusted.gpg.d/morph027-nextcloud-spreed-signaling.asc" "https://packaging.gitlab.io/nextcloud-spreed-signaling/gpg.key"
echo "deb [arch=amd64] https://packaging.gitlab.io/nextcloud-spreed-signaling signaling main" > /etc/apt/sources.list.d/morph027-nextcloud-spreed-signaling.list
apt update -q4 & spinner_loading
install_if_not nextcloud-spreed-signaling
## Configuration
if [ ! -f "$SIGNALING_SERVER_CONF" ];
then
    cat << SIGNALING_CONF_CREATE > "$SIGNALING_SERVER_CONF"
[http]
listen = 127.0.0.1:8081
[app]
debug = false
[sessions]
hashkey = $(openssl rand -hex 16)
blockkey = $(openssl rand -hex 16)
[clients]
internalsecret = $(openssl rand -hex 16)
[backend]
allowed = ${TURN_DOMAIN}
allowall = false
secret = ${NC_SECRET}
timeout = 10
connectionsperhost = 8
[nats]
url = nats://localhost:4222
[mcu]
type = janus
url = ws://127.0.0.1:8188
[turn]
apikey = ${JANUS_API_KEY}
secret = ${TURN_SECRET}
servers = turn:$TURN_DOMAIN:$TURN_PORT?transport=tcp,turn:$TURN_DOMAIN:$TURN_PORT?transport=udp
SIGNALING_CONF_CREATE
fi
start_if_stopped signaling
check_command systemctl enable signaling

# Apache Proxy
# https://github.com/strukturag/nextcloud-spreed-signaling#apache

# Install Apache2
install_if_not apache2

# Enable Apache2 module's
a2enmod proxy
a2enmod proxy_wstunnel
a2enmod proxy_http
a2enmod ssl
a2enmod headers
a2enmod remoteip

# Allow CustomLog
touch $VMLOGS/talk_apache_access.log
touch $VMLOGS/talk_apache_error.log
chown www-data:www-data $VMLOGS/talk_apache_error.log $VMLOGS/talk_apache_access.log

# Prep the error page
mkdir -p /var/www/html/error
echo "Hi there! :) If you see this page, the Apache2 proxy for $SCRIPT_NAME is up and running." > /var/www/html/error/404_proxy.html
chown -R www-data:www-data /var/www/html/error

# Only add TLS 1.3 on Ubuntu later than 20.04
if version 20.04 "$DISTRO" 20.04.10
then
    TLS13="+TLSv1.3"
fi

if [ -f "$HTTPS_CONF" ]
then
    a2dissite "$SUBDOMAIN.conf"
    rm -f "$HTTPS_CONF"
fi

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
    CustomLog ${APACHE_LOG_DIR}/access.log combined
    ErrorLog ${APACHE_LOG_DIR}/error.log

    # Just in case - see below
    SSLProxyEngine On
    SSLProxyVerify None
    SSLProxyCheckPeerCN Off
    SSLProxyCheckPeerName Off
    # contra mixed content warnings
    RequestHeader set X-Forwarded-Proto "https"
    # Custom error page
    ProxyErrorOverride On
    DocumentRoot "/var/www/html"
    ProxyPass /error/ !
    ErrorDocument 404 /error/404_proxy.html
    # Enable proxying Websocket requests to the standalone signaling server.
    # https://httpd.apache.org/docs/2.4/mod/mod_proxy_wstunnel.html
    ProxyPass / "http://127.0.0.1:8081/"
    RewriteEngine on
    RewriteCond %{HTTP:Upgrade} websocket [NC]
    RewriteCond %{HTTP:Connection} upgrade [NC]
    RewriteRule ^/?(.*) "ws://127.0.0.1:8081/\$1" [P,L]
    # Extra (remote) headers
    RequestHeader set X-Real-IP %{REMOTE_ADDR}s
    Header set X-XSS-Protection "1; mode=block"
    Header set Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
    Header set X-Content-Type-Options nosniff
    Header set Content-Security-Policy "frame-ancestors 'self'"
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

# Generate certs and  auto-configure  if successful
if generate_cert  "$SUBDOMAIN"
then
    # Generate DHparams chifer
    if [ ! -f "$DHPARAMS_SUB" ]
    then
        openssl dhparam -dsaparam -out "$DHPARAMS_SUB" 4096
    fi
    print_text_in_color "$IGreen" "Certs are generated!"
    a2ensite "$SUBDOMAIN.conf"
    restart_webserver
else
    # remove settings to be able to start over again
    rm -f "$HTTPS_CONF"
    last_fail_tls "$SCRIPTS"/apps/talk_signaling.sh
    exit 1
fi

## TODO
# Add to /etc/hosts
# Based on https://help.nextcloud.com/t/nextcloud-talk-signaling-server-now-automated-installation/90567/17?u=enoch85
# echo "127.0.1.1    $SUBDOMAIN" >> /etc/hosts

# Set signaling server strings
SIGNALING_SERVERS_STRING="{\"servers\":[{\"server\":\"https://$SUBDOMAIN/\",\"verify\":true}],\"secret\":\"$NC_SECRET\"}"
nextcloud_occ config:app:set spreed signaling_servers --value="$SIGNALING_SERVERS_STRING" --output json

# Check that everything is working
if ! curl -L https://"$SUBDOMAIN"/api/v1/welcome
then
    msg_box "Installation failed. :/\n\nPlease run this script again to uninstall if you want to clean the system, or choose to reinstall if you want to try again.\n\nLogging can be found by typing: journalctl -lfu signaling"
    exit 1
else
    msg_box "Congratulations, everything is working as intended! The installation succeeded.\n\nLogging can be found by typing: journalctl -lfu signaling"
    exit 0
fi
