#!/bin/bash

# T&M Hansson IT AB © - 2020, https://www.hanssonit.se/

# shellcheck disable=2034,2059
true
# shellcheck source=lib.sh
NC_UPDATE=1 && TURN_INSTALL=1 . <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)
unset NC_UPDATE
unset TURN_INSTALL

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Must be root
root_check

# Must be 20.04
if ! version 20.04 "$DISTRO" 20.04.6
then
msg_box "Your current Ubuntu version is $DISTRO but must be between 20.04 - 20.04.6 to install Talk"
msg_box "Please contact us to get support for upgrading your server:
https://www.hanssonit.se/#contact
https://shop.hanssonit.se/"
exit
fi

# Nextcloud 13 is required.
lowest_compatible_nc 19

####################### TALK (COTURN)

# Check if adminer is already installed
print_text_in_color "$ICyan" "Checking if Talk is already installed..."
if [ -n "$(occ_command_no_check config:app:get spreed turn_servers | sed 's/\[\]//')" ] || is_this_installed coturn
then
    choice=$(whiptail --radiolist "It seems like 'Nextcloud Talk' is already installed.\nChoose what you want to do.\nSelect by pressing the spacebar and ENTER" "$WT_HEIGHT" "$WT_WIDTH" 4 \
    "Uninstall Nextcloud Talk" "" OFF \
    "Reinstall Nextcloud Talk" "" ON 3>&1 1>&2 2>&3)
    
    case "$choice" in
        "Uninstall Nextcloud Talk")
            print_text_in_color "$ICyan" "Uninstalling Nextcloud Talk and resetting all settings..."
            occ_command_no_check config:app:delete spreed stun_servers
            occ_command_no_check config:app:delete spreed turn_servers
            occ_command_no_check app:remove spreed
            rm $TURN_CONF
            apt-get purge coturn -y
            msg_box "Nextcloud Talk was successfully uninstalled and all settings were resetted."
            exit
        ;;
        "Reinstall Nextcloud Talk")
            print_text_in_color "$ICyan" "Reinstalling Nextcloud Talk..."
            occ_command_no_check config:app:delete spreed stun_servers
            occ_command_no_check config:app:delete spreed turn_servers
            occ_command_no_check app:remove spreed
            rm $TURN_CONF
            apt-get purge coturn -y
        ;;
        *)
        ;;
    esac
else
    print_text_in_color "$ICyan" "Installing Nextcloud Talk..."
fi

# Check if Nextcloud is installed
print_text_in_color "$ICyan" "Checking if Nextcloud is installed..."
if ! curl -s https://"${TURN_DOMAIN//\\/}"/status.php | grep -q 'installed":true'
then
msg_box "It seems like Nextcloud is not installed or that you don't use https on:
${TURN_DOMAIN//\\/}
Please install Nextcloud and make sure your domain is reachable, or activate TLS
on your domain to be able to run this script.
If you use the Nextcloud VM you can use the Let's Encrypt script to get TLS and activate your Nextcloud domain.
When TLS is activated, run these commands from your terminal:
sudo curl -sLO $APP/talk.sh
sudo bash talk.sh"
    exit 1
fi

# Let the user choose port. TURN_PORT in msg_box is taken from lib.sh and later changed if user decides to.
NONO_PORTS=(22 25 53 80 443 3306 5178 5179 5432 7983 8983 10000)
msg_box "The default port for Talk used in this script is port $TURN_PORT.
You can read more about that port here: https://www.speedguide.net/port.php?port=$TURN_PORT
You will now be given the option to change this port to something of your own. 
Please keep in mind NOT to use the following ports as they are likley to be in use already: 
${NONO_PORTS[*]}"

if [[ "yes" == $(ask_yes_or_no "Do you want to change port?") ]]
then
    while true
    do
    # Ask for port
cat << ENTERDOMAIN
+---------------------------------------------------------------+
|    Please enter the port you will use for Nextcloud Talk:     |
+---------------------------------------------------------------+
ENTERDOMAIN
    echo
    read -r TURN_PORT
    echo
    if [[ "yes" == $(ask_yes_or_no "Is this correct? $TURN_PORT") ]]
    then
        break
    fi
    done
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
mkdir -p "$VMLOGS"
touch "$VMLOGS"/turnserver.log

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
After you hit OK the script will check for the firewall and eventually exit on failure.
To run again the setup, after fixing your firewall:
sudo -sLO $APP/talk.sh
sudo bash talk.sh"

# Check if the port is open
check_open_port "$TURN_PORT" "$TURN_DOMAIN"

# Enable Spreed (Talk)
STUN_SERVERS_STRING="[\"$TURN_DOMAIN:$TURN_PORT\"]"
TURN_SERVERS_STRING="[{\"server\":\"$TURN_DOMAIN:$TURN_PORT\",\"secret\":\"$TURN_SECRET\",\"protocols\":\"udp,tcp\"}]"
if ! is_app_installed spreed
then
    install_and_enable_app spreed
    occ_command config:app:set spreed stun_servers --value="$STUN_SERVERS_STRING" --output json
    occ_command config:app:set spreed turn_servers --value="$TURN_SERVERS_STRING" --output json
    chown -R www-data:www-data "$NC_APPS_PATH"
fi

if is_app_installed spreed
then
msg_box "Nextcloud Talk is now installed. For more information about Nextcloud Talk and its mobile apps visit:
https://nextcloud.com/talk/"
fi

####################### SIGNALING

DESCRIPTION="Talk Signaling Server"

# Ask the user if he/she wants the HPB server as well
if [[ "no" == $(ask_yes_or_no "Do you want to install the DESCRIPTION?") ]]
then
    exit 1
fi

# Check if Nextcloud is installed with TLS
check_nextcloud_https "$DESCRIPTION"

# Check if $SUBDOMAIN exists and is reachable
print_text_in_color "$ICyan" "Checking if $SUBDOMAIN exists and is reachable..."
domain_check_200 "$SUBDOMAIN"

# Check open ports with NMAP
check_open_port 80 "$SUBDOMAIN"
check_open_port 443 "$SUBDOMAIN"

# Check if HPB is already installed
is_process_running dpkg
is_process_running apt
print_text_in_color "$ICyan" "Checking if ${DESCRIPTION} is already installed..."
if ! is_this_installed nextcloud-spreed-signaling
then
    choice=$(whiptail --radiolist "It seems like '${DESCRIPTION}' is already installed.\nChoose what you want to do.\nSelect by pressing the spacebar and ENTER" "$WT_HEIGHT" "$WT_WIDTH" 4 \
    "Uninstall ${DESCRIPTION}" "" OFF \
    "Reinstall ${DESCRIPTION}" "" ON 3>&1 1>&2 2>&3)
    case "$choice" in
        "Uninstall ${DESCRIPTION}")
          # TODO: remove nats, janus and signaling-server
          :
        ;;
        "Reinstall ${DESCRIPTION}")
          # TODO: remove nats, janus and signaling-server
          :
        ;;
        *)
        ;;
    esac
else
    print_text_in_color "$ICyan" "Installing ${DESCRIPTION}..."
fi

# Install
. /etc/lsb-release
for repo in nats-server nextcloud-spreed-signaling janus
do
  # curl_to_dir doesn't fit here as the name of the fetched file and output differs
  curl -sL -o "/etc/apt/trusted.gpg.d/morph027-${repo}.asc" "https://packaging.gitlab.io/${repo}/gpg.key"
done

echo "deb [arch=amd64] https://packaging.gitlab.io/nextcloud-spreed-signaling signaling main" > /etc/apt/sources.list.d/morph027-nextcloud-spreed-signaling.list
echo "deb [arch=amd64] https://packaging.gitlab.io/janus/$DISTRIB_CODENAME $DISTRIB_CODENAME main" > /etc/apt/sources.list.d/morph027-janus.list
echo "deb [arch=amd64] https://packaging.gitlab.io/nats-server nats main" > /etc/apt/sources.list.d/morph027-nats-server.list

apt update -q4 & spinner_loading
check_command apt-get install -y nextcloud-spreed-signaling nats-server janus
check_command systemctl restart janus
check_command systemctl enable janus

### PROXY ###
# https://github.com/strukturag/nextcloud-spreed-signaling#apache

# Check if $SUBDOMAIN exists and is reachable
print_text_in_color "$ICyan" "Checking if $SUBDOMAIN exists and is reachable..."
domain_check_200 "$SUBDOMAIN"

# Check open ports with NMAP
check_open_port 80 "$SUBDOMAIN"
check_open_port 443 "$SUBDOMAIN"

# Install Apache2
install_if_not apache2

# Enable Apache2 module's
a2enmod proxy
a2enmod proxy_wstunnel
a2enmod proxy_http
a2enmod ssl
a2enmod headers
a2enmod remoteip

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
    SSLEngine on
    ServerSignature On
    SSLHonorCipherOrder on
    SSLCertificateChainFile $CERTFILES/$SUBDOMAIN/chain.pem
    SSLCertificateFile $CERTFILES/$SUBDOMAIN/cert.pem
    SSLCertificateKeyFile $CERTFILES/$SUBDOMAIN/privkey.pem
    SSLOpenSSLConfCmd DHParameters $DHPARAMS_SUB
    SSLProtocol TLSv1.2
    SSLCipherSuite ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA256:ECDHE-ECDSA-AES128-SHA:ECDHE-RSA-AES256-SHA384:ECDHE-RSA-AES128-SHA:ECDHE-ECDSA-AES256-SHA384:ECDHE-ECDSA-AES256-SHA:ECDHE-RSA-AES256-SHA:DHE-RSA-AES128-SHA256:DHE-RSA-AES128-SHA:DHE-RSA-AES256-SHA256:DHE-RSA-AES256-SHA:ECDHE-ECDSA-DES-CBC3-SHA:ECDHE-RSA-DES-CBC3-SHA:EDH-RSA-DES-CBC3-SHA:AES128-GCM-SHA256:AES256-GCM-SHA384:AES128-SHA256:AES256-SHA256:AES128-SHA:AES256-SHA:DES-CBC3-SHA:!DSS
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
    # basic proxy settings
    # Enable proxying Websocket requests to the standalone signaling server.
    ProxyPass "/standalone-signaling/"  "ws://127.0.0.1:8080/"
    RewriteEngine On
    # Websocket connections from the clients.
    RewriteRule ^/standalone-signaling/spreed$ - [L]
    # Backend connections from Nextcloud.
    RewriteRule ^/standalone-signaling/api/(.*) http://127.0.0.1:8080/api/$1 [L,P]
    # Extra (remote) headers
    RequestHeader set X-Real-IP %{REMOTE_ADDR}s
    Header set X-XSS-Protection "1; mode=block"
    Header set Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
    Header set X-Content-Type-Options nosniff
    Header set Content-Security-Policy "frame-ancestors 'self'"
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

# Add prune command
add_dockerprune

# Configuration
## Janus WebRTC Server
sed -i "s|turn_rest_api_key|$TURN_SECRET|g" /etc/janus/janus.jcfg
sed -i "s|#full_trickle|full_trickle|g" /etc/janus/janus.jcfg
sed -i 's|#interface.*|interface = "lo"|g' /etc/janus/janus.transport.websockets.jcfg
sed -i 's|#ws_interface.*|ws_interface = "lo"|g' /etc/janus/janus.transport.websockets.jcfg
check_command systemctl restart janus

nc_secret="$(openssl rand -hex 16)"
janus_api_key="$(openssl rand -base64 16)"

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
# do we know about the domain and the endpoint in some variable?
# looks like: turn:example.com:3478?transport=tcp
servers = ${TURN_SERVER}
SIGNALING_CONF_CREATE

sed -i 's,#turn_rest_api_key\s*=.*,turn_rest_api_key = "'"${JANUS_API_KEY}"'",' /etc/janus/janus.jcfg.dpkg-dist
systemctl restart janus
# We could just add this in there instead:
msg_box "Please enter nc secret into your Talk settings: ${NC_SECRET}"



## NATS server
mkdir -p /etc/nats
sudo install -d -o nats -g nats /etc/nats
sudo -u nats echo "listen: 127.0.0.1:4222" | sudo tee -a /etc/nats/nats.conf
install_if_not nats-server
start_if_stopped nats-server
check_command systemctl enable nats-server

## nextcloud-spreed-signaling server (HPB)
# TODO: create keys, setup config for janus and hpb (get turn server url from coturn app)

# Install with apt: https://morph027.gitlab.io/blog/nextcloud-spreed-signaling/
install_if_not nextcloud-spreed-signaling-proxy
install_if_not nextcloud-spreed-signaling
cp -f /usr/share/signaling/server.conf /etc/signaling/server.conf
cp -f /usr/share/signaling/proxy.conf /etc/signaling/proxy.conf
