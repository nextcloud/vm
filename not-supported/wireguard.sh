#!/bin/bash

# T&M Hansson IT AB © - 2026, https://www.hanssonit.se/
# Copyright © 2021 Simon Lindner (https://github.com/szaimen)

true
SCRIPT_NAME="WireGuard"
SCRIPT_EXPLAINER="WireGuard is a modern VPN protocol that is much faster and simpler than e.g. OpenVPN.
This script will set up a WireGuard VPN server to connect devices to your home network from everywhere.

It uses wg-easy, which provides a web interface to manage your clients.
This is their official website: https://github.com/wg-easy/wg-easy

This script installs WireGuard in a Docker container."
# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Check if root
root_check

# The port that the WireGuard VPN listens on. This one needs to be forwarded.
WIREGUARD_PORT=51820
# The port that the wg-easy web interface listens on inside the container.
# It is only bound to 127.0.0.1 on the host, since Apache2 proxies it via https.
WIREGUARD_WEB_PORT=51821
# The port that Apache2 listens on to proxy the web interface via https
WIREGUARD_PROXY_PORT=51822
# The name of the docker network that the container runs in.
# wg-easy needs an own network with IPv6 enabled.
WIREGUARD_NETWORK=wg-easy

# Check if already installed
if ! is_docker_running || ! docker ps -a --format "{{.Names}}" | grep -q "^wg-easy$"
then
    # Ask for installing
    install_popup "$SCRIPT_NAME"
else
    # Ask for removal or reinstallation
    reinstall_remove_menu "$SCRIPT_NAME"
    # Removal
    docker rm -f wg-easy &>/dev/null
    docker network rm "$WIREGUARD_NETWORK" &>/dev/null
    # Remove the Apache2 configuration
    if [ -f "$SITES_AVAILABLE/wg-easy.conf" ]
    then
        a2dissite wg-easy.conf &>/dev/null
        rm -f "$SITES_AVAILABLE/wg-easy.conf"
        restart_webserver
    fi
    # Delete firewall entries
    for port in "$WIREGUARD_PORT/udp" "$WIREGUARD_PROXY_PORT/tcp"
    do
        ufw delete allow "$port" &>/dev/null
    done
    # The user-data is kept on purpose so that a reinstallation doesn't lose the clients
    if [ "$REINSTALL_REMOVE" = "Uninstall" ]
    then
        msg_box "The WireGuard configuration and all your clients were NOT removed \
and are still stored in the 'wg_easy' docker volume.

If you want to delete them as well, e.g. to be able to start from scratch \
if you install WireGuard again later on, please run the following command:
'sudo docker volume rm wg_easy'

Please don't forget to close port $WIREGUARD_PORT/udp in your router again \
if you don't need it anymore."
    else
        msg_box "Please note that the WireGuard configuration in the 'wg_easy' \
docker volume will be kept, which means that all your current clients will \
still work after the reinstallation.

This also means that the admin password will stay the same as before, since \
wg-easy only applies the initial password on a fresh installation.

If you want to start from scratch instead, please abort this script now with 'CTRL+C' \
and run the following command before running it again:
'sudo docker volume rm wg_easy'"
    fi
    # Show successful uninstall if applicable
    removal_popup "$SCRIPT_NAME"
fi

# Warn about running this on a public server
msg_box "Attention!

This script opens a VPN entry point into your servers network. \
Only continue if you understand the implications and keep it updated!

It is only intended to be used on a server in a trusted home network. \
Do NOT run this on a public VPS or any other server whose ip address is \
directly reachable from the internet."

if ! yesno_box_yes "Is this server running in a trusted home network?"
then
    exit 1
fi

# wg-easy needs the wireguard kernel module on the host.
# It ships as a loadable module on all kernels since 5.6, but might not be loaded yet.
print_text_in_color "$ICyan" "Checking if the WireGuard kernel module is available..."
if ! lsmod | grep -q "^wireguard"
then
    if ! modprobe wireguard &>/dev/null
    then
        msg_box "The WireGuard kernel module is not available on this server, \
which means that the container would not be able to start.

It ships as a loadable module on all common distributions with kernel 5.6 or \
later. Your current kernel is: $(uname -r)

Please install the WireGuard kernel module on this server first and \
run this script again."
        exit 1
    fi
fi

# Make sure that the module gets loaded again after a reboot
if ! [ -f /etc/modules-load.d/wireguard.conf ]
then
    echo "wireguard" > /etc/modules-load.d/wireguard.conf
fi

# Automatically get the domain
if [ -f "$NCPATH/occ" ]
then
    # Get the NCDOMAIN
    NCDOMAIN=$(nextcloud_occ_no_check config:system:get overwrite.cli.url | sed 's|https://||;s|/||')

    # Check if Nextcloud is installed
    if ! curl -s https://"$NCDOMAIN"/status.php | grep -q 'installed":true' || [ "$NCDOMAIN" = "nextcloud" ]
    then
        msg_box "It seems like Nextcloud is not installed or that you don't use https on:
$NCDOMAIN.

Please install Nextcloud and make sure your domain is reachable, or activate TLS
on your domain to be able to run this script.

We need this to make sure that the domain works for connections over WireGuard."
        exit 1
    fi
fi

# Ask for the domain
if ! [ -f "$NCPATH/occ" ]
then
    # Enter the domain yourself
    NCDOMAIN=$(input_box_flow "Please enter the domain that you want to use for WireGuard.
It should most likely point to your home ip address via DDNS.")
fi

# Inform user to open the port
msg_box "To make WireGuard work, you will need to open port $WIREGUARD_PORT UDP \
in your router and forward it to this server.

Attention! The web interface on port $WIREGUARD_PROXY_PORT TCP must NOT be \
forwarded, since it is only meant to be reachable inside your local network!

You will have the option to automatically open port $WIREGUARD_PORT UDP by \
using UPNP in the next step."

if yesno_box_no "Do you want to use UPNP to open port $WIREGUARD_PORT UDP?"
then
    unset FAIL
    open_port "$WIREGUARD_PORT" UDP
    cleanup_open_port
fi

# Check the port
if ! yesno_box_yes "Unfortunately we are not able to check automatically if port \
$WIREGUARD_PORT UDP is open. So please make sure to open it correctly!
Do you still want to continue?"
then
    exit 1
fi

# Install Docker
install_docker

# Generate a new admin password.
# wg-easy doesn't check the password for complexity but refuses to let the user
# log in if it is too short, which is why we use 16 characters here.
PASSWORD=$(gen_passwd 16 "a-zA-Z0-9")

# The INIT_* variables below are only applied by wg-easy if it doesn't find an
# existing configuration in its volume. So if the volume was kept from a previous
# installation, the old admin password stays in place and the newly generated one
# above would be wrong. We check this here to be able to inform the user correctly.
if docker volume ls --format "{{.Name}}" | grep -q "^wg_easy$"
then
    EXISTING_CONFIG=yes
fi

# Get the docker container
print_text_in_color "$ICyan" "Getting WireGuard..."
docker pull ghcr.io/wg-easy/wg-easy:15

# wg-easy needs an own docker network with IPv6 enabled since it hands out
# IPv6 addresses to its clients. The default bridge network doesn't support this.
if ! docker network ls --format "{{.Name}}" | grep -q "^$WIREGUARD_NETWORK$"
then
    print_text_in_color "$ICyan" "Creating the WireGuard docker network..."
    if ! docker network create \
    --driver bridge \
    --ipv6 \
    --subnet 10.42.42.0/24 \
    --subnet fdcc:ad94:bacf:61a3::/64 \
    "$WIREGUARD_NETWORK"
    then
        msg_box "Failed to create the WireGuard docker network.

Please report this issue here $ISSUES if you can't solve it yourself."
        exit 1
    fi
fi

# Create WireGuard
# The INIT_* variables are only used on the very first start of the container
# and set up the admin account automatically so that the user doesn't need to
# run through the setup wizard in the web interface.
# The web interface is only bound to 127.0.0.1 on the host, since Apache2
# proxies https://$ADDRESS:$WIREGUARD_PROXY_PORT to it further down below.
# 'INSECURE=true' is needed because wg-easy itself only serves plain http and
# doesn't know that it is reached via https through the Apache2 proxy.
print_text_in_color "$ICyan" "Installing WireGuard..."
if ! docker run -d \
--name wg-easy \
--restart always \
--network "$WIREGUARD_NETWORK" \
--ip 10.42.42.42 \
--ip6 fdcc:ad94:bacf:61a3::2a \
-p "$WIREGUARD_PORT":"$WIREGUARD_PORT"/udp \
-p 127.0.0.1:"$WIREGUARD_WEB_PORT":"$WIREGUARD_WEB_PORT"/tcp \
--cap-add NET_ADMIN \
--cap-add SYS_MODULE \
--sysctl net.ipv4.ip_forward=1 \
--sysctl net.ipv4.conf.all.src_valid_mark=1 \
--sysctl net.ipv6.conf.all.disable_ipv6=0 \
--sysctl net.ipv6.conf.all.forwarding=1 \
--sysctl net.ipv6.conf.default.forwarding=1 \
-e TZ="$(cat /etc/timezone)" \
-e INSECURE=true \
-e PORT="$WIREGUARD_WEB_PORT" \
-e INIT_ENABLED=true \
-e INIT_USERNAME=admin \
-e INIT_PASSWORD="$PASSWORD" \
-e INIT_HOST="$NCDOMAIN" \
-e INIT_PORT="$WIREGUARD_PORT" \
-v wg_easy:/etc/wireguard \
-v /lib/modules:/lib/modules:ro \
ghcr.io/wg-easy/wg-easy:15
then
    msg_box "Failed to create the WireGuard container.

Please report this issue here $ISSUES if you can't solve it yourself."
    # Remove the container leftovers so that this script can be run again
    docker rm -f wg-easy &>/dev/null
    exit 1
fi

# Add prune command
add_dockerprune

# Install apache2
install_if_not apache2

# Enable Apache2 module's
a2enmod headers
a2enmod rewrite
a2enmod ssl
a2enmod proxy
a2enmod proxy_http
a2enmod proxy_wstunnel

# Only add TLS 1.3 on supported Ubuntu releases
if version "$SUPPORTED_VERSION_MIN" "$DISTRO" "$SUPPORTED_VERSION_MAX"
then
    TLS13="+TLSv1.3"
fi

# Create the vhost that proxies the wg-easy web interface via https.
# We use a self-signed certificate here since the web interface is only
# meant to be reachable inside the local network via the ip address.
cat << WIREGUARD_CONF > "$SITES_AVAILABLE/wg-easy.conf"
Listen $WIREGUARD_PROXY_PORT
<VirtualHost *:$WIREGUARD_PROXY_PORT>
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

    # This is needed to redirect access on http://$ADDRESS:$WIREGUARD_PROXY_PORT/
    # to https://$ADDRESS:$WIREGUARD_PROXY_PORT/
    ErrorDocument 400 https://$ADDRESS:$WIREGUARD_PROXY_PORT/

    # wg-easy uses websockets to keep the web interface up to date
    RewriteEngine On
    RewriteCond %{HTTP:Upgrade} websocket [NC]
    RewriteCond %{HTTP:Connection} upgrade [NC]
    RewriteRule ^/?(.*) "ws://127.0.0.1:$WIREGUARD_WEB_PORT/\$1" [P,L]

    # basic proxy settings
    ProxyRequests off
    ProxyPass / "http://127.0.0.1:$WIREGUARD_WEB_PORT/"
    ProxyPassReverse / "http://127.0.0.1:$WIREGUARD_WEB_PORT/"
    ProxyPreserveHost On

### LOCATION OF CERT FILES ###
    SSLCertificateFile /etc/ssl/certs/ssl-cert-snakeoil.pem
    SSLCertificateKeyFile /etc/ssl/private/ssl-cert-snakeoil.key
</VirtualHost>
WIREGUARD_CONF

# Enable config
check_command a2ensite wg-easy.conf

# Restart webserver
if ! restart_webserver
then
    msg_box "Apache2 could not restart...
The script will exit."
    exit 1
fi

# Add firewall rules
ufw allow "$WIREGUARD_PORT"/udp comment 'WireGuard VPN' &>/dev/null
ufw allow "$WIREGUARD_PROXY_PORT"/tcp comment 'WireGuard Web' &>/dev/null

# Check if the container is actually running, since it exits on startup
# if e.g. the wireguard kernel module cannot be loaded
countdown "Waiting for WireGuard to start... " 15
if ! docker ps --format "{{.Names}}" | grep -q "^wg-easy$"
then
    msg_box "The WireGuard container was created but is not running.

These are the logs of the container:
$(docker logs --tail 20 wg-easy 2>&1)

Please report this issue here $ISSUES if you can't solve it yourself."
    exit 1
fi

# Inform the user about the successful installation
if [ "$EXISTING_CONFIG" = "yes" ]
then
    # An existing configuration was found, which means that wg-easy ignored the
    # initial admin account and kept the one from the previous installation
    msg_box "Congratulations, your WireGuard server was set up correctly!

The web interface is reachable inside your local network on:
https://$ADDRESS:$WIREGUARD_PROXY_PORT

Since an existing WireGuard configuration was found in the 'wg_easy' docker \
volume, your previous admin account and all your clients were kept. This means \
that you need to log in with the same username and password as before.

If you don't know your password anymore, you can start from scratch by running \
the following commands and running this script again afterwards:
'sudo docker rm -f wg-easy'
'sudo docker volume rm wg_easy'

Attention! This will delete all your clients as well.

Please note that the certificate is self-signed, which means that your browser \
will show a warning that you need to accept."
else
    msg_box "Congratulations, your WireGuard server was set up correctly!

The web interface is reachable inside your local network on:
https://$ADDRESS:$WIREGUARD_PROXY_PORT

Username: admin
Password: $PASSWORD

Please write down this password now! We cannot show it to you again later on, \
since it is only used during the initial setup of the container.

Please note that the certificate is self-signed, which means that your browser \
will show a warning that you need to accept."
fi

msg_box "How to add your devices:

1. Visit https://$ADDRESS:$WIREGUARD_PROXY_PORT and log in
2. Create a new client for each of your devices
3. Scan the shown QR code with the WireGuard app on your phone, \
or download the configuration file for your computer

Attention! Every device needs its own client profile!

Your clients will connect to '$NCDOMAIN' on port $WIREGUARD_PORT UDP. \
You can change this host in the web interface if you want to connect \
via a different address."

msg_box "Concerning updates:
WireGuard runs in a Docker container, which means that you can update it \
by running the following command:
'sudo docker pull ghcr.io/wg-easy/wg-easy:15'

and afterwards running this script again and choosing 'Reinstall'.

Your clients and settings in the 'wg_easy' docker volume will be kept in that \
process, which also means that your admin password will stay the same."

exit
