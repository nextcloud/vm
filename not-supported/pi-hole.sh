#!/bin/bash

# T&M Hansson IT AB © - 2026, https://www.hanssonit.se/
# Copyright © 2021 Simon Lindner (https://github.com/szaimen)

true
SCRIPT_NAME="Pi-hole"
SCRIPT_EXPLAINER="The Pi-hole® is a DNS sinkhole that protects your devices from unwanted content, \
without installing any client-side software.
This is their official website: https://pi-hole.net

This script installs Pi-hole in a Docker container."
# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Check if root
root_check

# The port that the Pi-hole web interface listens on inside the container.
# We don't use 80 here since that port is already occupied by Apache2 on the host.
PIHOLE_WEB_PORT=8573
# The port that Apache2 listens on to proxy the web interface via https
PIHOLE_PROXY_PORT=8094
# Where the Pi-hole configuration and databases are stored on the host
PIHOLE_DIR=/opt/pihole

# Check if already installed
if ! is_docker_running || ! docker ps -a --format "{{.Names}}" | grep -q "^pihole$"
then
    # Ask for installing
    install_popup "$SCRIPT_NAME"
else
    # Ask for removal or reinstallation
    reinstall_remove_menu "$SCRIPT_NAME"
    # Removal
    docker rm -f pihole &>/dev/null
    # Remove the Apache2 configuration
    if [ -f "$SITES_AVAILABLE/pihole.conf" ]
    then
        a2dissite pihole.conf &>/dev/null
        rm -f "$SITES_AVAILABLE/pihole.conf"
        restart_webserver
    fi
    # Delete firewall entries
    for port in 53/tcp 53/udp "$PIHOLE_PROXY_PORT/tcp"
    do
        ufw delete allow "$port" &>/dev/null
    done
    # Re-enable the systemd-resolved stub listener since port 53 is free again
    if [ -f /etc/systemd/resolved.conf.d/ncvm-pihole.conf ]
    then
        rm -f /etc/systemd/resolved.conf.d/ncvm-pihole.conf
        systemctl restart systemd-resolved &>/dev/null
        # Restore the resolv.conf symlink to the stub resolver
        if [ -f /run/systemd/resolve/stub-resolv.conf ]
        then
            ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
        fi
    fi
    # The user-data is kept on purpose so that a reinstallation doesn't lose the settings
    if [ "$REINSTALL_REMOVE" = "Uninstall" ]
    then
        msg_box "The Pi-hole user-data was NOT removed and is still stored here:
'$PIHOLE_DIR'

If you want to delete it as well, e.g. to be able to start from scratch \
if you install Pi-hole again later on, please run the following command:
'sudo rm -r $PIHOLE_DIR'

Attention! Please don't forget to reset the DNS server on your router and/or \
your clients to restore their internet connectivity, if you had configured them \
to use this server as their DNS server."
    else
        msg_box "Please note that the Pi-hole user-data in '$PIHOLE_DIR' \
will be kept, which means that your current settings, blocklists and \
statistics will still be there after the reinstallation.

If you want to start from scratch instead, please abort this script now with 'CTRL+C' \
and run the following command before running it again:
'sudo rm -r $PIHOLE_DIR'"
    fi
    # Show successful uninstall if applicable
    removal_popup "$SCRIPT_NAME"
fi

# Warn about running this on a public server
msg_box "Please note that Pi-hole is only intended to be run on a server \
in a trusted home network.

You should NOT run this on a public VPS or any other server whose ip address \
is directly reachable from the internet, since an open DNS resolver can be \
abused for DNS amplification attacks."

if ! yesno_box_yes "Is this server running in a trusted home network?"
then
    exit 1
fi

# Pi-hole needs port 53. On the NcVM this port is by default occupied by the
# systemd-resolved stub listener on 127.0.0.53, which prevents the container
# from binding to 53 on all interfaces. We disable the stub listener further
# down below, but any other DNS server needs to be handled by the user.
print_text_in_color "$ICyan" "Checking if port 53 is already in use..."
install_if_not net-tools
DNS_IN_USE="$(netstat -tulpn 2>/dev/null | grep ":53 " | grep -v "127.0.0.53:53" | grep -v "docker-proxy")"
if [ -n "$DNS_IN_USE" ]
then
    msg_box "It seems like another DNS server is already listening on port 53:

$DNS_IN_USE

Pi-hole cannot be installed while another DNS server occupies this port. \
Please stop and disable that DNS server first and run this script again.

Please report this to $ISSUES if you think that this is a mistake."
    exit 1
fi

# Ask if the user wants to use unbound as recursive DNS server
if yesno_box_yes "Do you want to enable your Pi-hole to be a recursive DNS server?

If you choose 'yes', we will additionally install unbound and configure your \
Pi-hole to use it as its upstream DNS server. This means that your Pi-hole will \
resolve all DNS queries itself instead of forwarding them to a public DNS \
provider like Google or Cloudflare, which improves your privacy."
then
    UNBOUND=yes
fi

# Install Docker
install_docker

# Free port 53 by disabling the systemd-resolved stub listener.
# systemd-resolved itself keeps running as the local resolver for the host,
# but stops listening on 127.0.0.53:53 so that Pi-hole can bind to port 53.
print_text_in_color "$ICyan" "Disabling the systemd-resolved DNS stub listener..."
mkdir -p /etc/systemd/resolved.conf.d
cat << RESOLVED_CONF > /etc/systemd/resolved.conf.d/ncvm-pihole.conf
# This file was created by the NcVM Pi-hole script.
# Pi-hole needs to bind to port 53 on all interfaces, which is not possible
# while the systemd-resolved stub listener occupies 127.0.0.53:53.
[Resolve]
DNSStubListener=no
RESOLVED_CONF

# With the stub listener disabled, /etc/resolv.conf must not point to the
# stub resolver anymore, since nothing is listening on 127.0.0.53 any longer.
if [ -f /run/systemd/resolve/resolv.conf ]
then
    ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf
fi

check_command systemctl restart systemd-resolved

# Make sure that name resolution still works before we continue,
# since we just changed the DNS setup of the host
print_text_in_color "$ICyan" "Checking if DNS resolution still works..."
if ! nslookup github.com >/dev/null 2>&1
then
    msg_box "DNS resolution stopped working after disabling the systemd-resolved \
stub listener. We will revert this change now and exit.

Please report this to $ISSUES"
    rm -f /etc/systemd/resolved.conf.d/ncvm-pihole.conf
    if [ -f /run/systemd/resolve/stub-resolv.conf ]
    then
        ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
    fi
    systemctl restart systemd-resolved
    exit 1
fi

# Create the directories for the persistent data
mkdir -p "$PIHOLE_DIR/etc-pihole"
mkdir -p "$PIHOLE_DIR/etc-dnsmasq.d"

# Generate a new Pi-hole password
PASSWORD=$(gen_passwd 12 "a-zA-Z0-9")

# Get the docker container
print_text_in_color "$ICyan" "Getting Pi-hole..."
docker pull pihole/pihole:latest

# Create Pi-hole
# The web interface listens on $PIHOLE_WEB_PORT inside the container since port 80
# is already used by Apache2 on the host. Apache2 proxies https://$ADDRESS:8094
# to 127.0.0.1:$PIHOLE_WEB_PORT further down below.
# 'FTLCONF_dns_listeningMode=all' is needed because the container runs in the
# docker bridge network and would otherwise only answer queries that originate
# from the same subnet as the container itself.
# The DHCP functionality is not enabled on purpose, which is why the container
# doesn't need the NET_ADMIN capability and port 67/udp.
print_text_in_color "$ICyan" "Installing Pi-hole..."
if ! docker run -d \
--name pihole \
--restart always \
-p 53:53/tcp \
-p 53:53/udp \
-p 127.0.0.1:"$PIHOLE_WEB_PORT":"$PIHOLE_WEB_PORT"/tcp \
-e TZ="$(cat /etc/timezone)" \
-e FTLCONF_webserver_api_password="$PASSWORD" \
-e FTLCONF_dns_listeningMode=all \
-e FTLCONF_webserver_port="$PIHOLE_WEB_PORT" \
-v "$PIHOLE_DIR/etc-pihole:/etc/pihole" \
-v "$PIHOLE_DIR/etc-dnsmasq.d:/etc/dnsmasq.d" \
pihole/pihole:latest
then
    msg_box "Failed to create the Pi-hole container.

Please report this issue here $ISSUES if you can't solve it yourself."
    # Remove the container leftovers so that this script can be run again
    docker rm -f pihole &>/dev/null
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

# Only add TLS 1.3 on supported Ubuntu releases
if version "$SUPPORTED_VERSION_MIN" "$DISTRO" "$SUPPORTED_VERSION_MAX"
then
    TLS13="+TLSv1.3"
fi

# Create the vhost that proxies the Pi-hole web interface via https.
# We use a self-signed certificate here since the Pi-hole admin interface is
# only meant to be reachable inside the local network via the ip address.
cat << PIHOLE_CONF > "$SITES_AVAILABLE/pihole.conf"
Listen $PIHOLE_PROXY_PORT
<VirtualHost *:$PIHOLE_PROXY_PORT>
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

    # This is needed to redirect access on http://$ADDRESS:$PIHOLE_PROXY_PORT/
    # to https://$ADDRESS:$PIHOLE_PROXY_PORT/
    ErrorDocument 400 https://$ADDRESS:$PIHOLE_PROXY_PORT/admin/

    # basic proxy settings
    ProxyRequests off
    ProxyPass / "http://127.0.0.1:$PIHOLE_WEB_PORT/"
    ProxyPassReverse / "http://127.0.0.1:$PIHOLE_WEB_PORT/"
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

# Add firewall rules
ufw allow 53/tcp comment 'Pi-hole TCP' &>/dev/null
ufw allow 53/udp comment 'Pi-hole UDP' &>/dev/null
ufw allow "$PIHOLE_PROXY_PORT"/tcp comment 'Pi-hole Web' &>/dev/null

# Set up unbound if chosen
if [ "$UNBOUND" = "yes" ]
then
    # Install needed tools
    install_if_not unbound

    # unbound listens on port 5335 on the docker bridge gateway so that the
    # Pi-hole container can reach it. 127.0.0.1 would not be reachable from
    # inside the container.
    DOCKER_GATEWAY="$(docker network inspect bridge --format '{{range .IPAM.Config}}{{.Gateway}}{{end}}')"
    if [ -z "$DOCKER_GATEWAY" ]
    then
        DOCKER_GATEWAY=172.17.0.1
    fi

    cat << UNBOUND_CONF > /etc/unbound/unbound.conf.d/pi-hole.conf
server:
    # To see what those variables do, look here:
    # https://docs.pi-hole.net/guides/unbound/
    verbosity: 0
    interface: $DOCKER_GATEWAY
    port: 5335
    do-ip4: yes
    do-udp: yes
    do-tcp: yes
    do-ip6: no
    prefer-ip6: no
    harden-glue: yes
    harden-dnssec-stripped: yes
    use-caps-for-id: no
    edns-buffer-size: 1232
    prefetch: yes
    num-threads: 1
    so-rcvbuf: 1m
    private-address: 192.168.0.0/16
    private-address: 169.254.0.0/16
    private-address: 172.16.0.0/12
    private-address: 10.0.0.0/8
    private-address: fd00::/8
    private-address: fe80::/10
    # Only allow the Pi-hole container to use this resolver
    access-control: 0.0.0.0/0 refuse
    access-control: 127.0.0.0/8 allow
    access-control: 172.16.0.0/12 allow
UNBOUND_CONF

    # Restart unbound
    print_text_in_color "$ICyan" "Restarting unbound..."
    check_command systemctl restart unbound
    countdown "Waiting for unbound to start... " 10

    # Testing DNSSEC
    install_if_not dnsutils
    if ! dig sigfail.verteiltesysteme.net @"$DOCKER_GATEWAY" -p 5335 | grep -q "SERVFAIL"
    then
        msg_box "Something went wrong while testing SERVFAIL.
Please report this to $ISSUES"
    elif ! dig sigok.verteiltesysteme.net @"$DOCKER_GATEWAY" -p 5335 | grep -q "NOERROR"
    then
        msg_box "Something went wrong while testing NOERROR.
Please report this to $ISSUES"
    fi

    # Allow the container to reach unbound on the docker bridge
    ufw allow in on docker0 to "$DOCKER_GATEWAY" port 5335 comment 'Pi-hole unbound' &>/dev/null

    # Configure Pi-hole to use unbound as its upstream DNS server
    print_text_in_color "$ICyan" "Configuring Pi-hole to use unbound..."
    countdown "Waiting for Pi-hole to start... " 15
    if ! docker exec pihole pihole-FTL --config "dns.upstreams=$DOCKER_GATEWAY#5335" &>/dev/null
    then
        msg_box "Could not configure Pi-hole to use unbound automatically.

You can do this yourself by visiting https://$ADDRESS:$PIHOLE_PROXY_PORT/admin \
and entering '$DOCKER_GATEWAY#5335' as custom upstream DNS server under \
'Settings' --> 'DNS'."
    else
        docker restart pihole &>/dev/null
        msg_box "unbound was successfully installed and Pi-hole was successfully \
configured to use it as recursive DNS server."
    fi
fi

# Show that everything was set up correctly
msg_box "Congratulations, your Pi-hole was set up correctly!
It is now reachable on:
https://$ADDRESS:$PIHOLE_PROXY_PORT/admin

Your password is: $PASSWORD

Please note that the certificate is self-signed, which means that your browser \
will show a warning that you need to accept."

# Show the address
msg_box "You can now configure your devices to use the Pi-hole as their DNS server \
by entering the following ip address as DNS server in your router:
$ADDRESS

Additionally, you can configure the docker daemon to use it by editing \
'/etc/docker/daemon.json' and adding '\"dns\" : [ \"$ADDRESS\", \"9.9.9.9\" ]'."

# Show how to use pihole in the command line
msg_box "How to use Pi-hole on the command line:

You can run any Pi-hole command inside the container like this:
'sudo docker exec -it pihole pihole -h'

Please note that the admin password is set via an environment variable of the \
container, which makes it read-only for the web interface and the command line. \
If you want to change it, you can run this script again and choose 'Reinstall', \
which will generate and show you a new password while keeping all your settings.

Please also note that the DHCP functionality of Pi-hole is not enabled since the \
container doesn't run in the host network."

# Inform about updates
msg_box "Concerning updates:
Pi-hole runs in a Docker container, which means that you can update it \
by running the following commands:
'sudo docker pull pihole/pihole:latest'
and afterwards running this script again and choosing 'Reinstall'.

Your settings and statistics in '$PIHOLE_DIR' will be kept in that process."

exit
