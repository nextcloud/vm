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

    # The user-data is kept, so an upstream pointing at the unbound that we
    # remove below would survive and break DNS. Reset it while the CLI still works.
    if [ -f /etc/unbound/unbound.conf.d/pi-hole.conf ] \
    && docker ps --format "{{.Names}}" | grep -q "^pihole$"
    then
        print_text_in_color "$ICyan" "Resetting the Pi-hole upstream DNS servers..."
        docker exec pihole pihole-FTL --config dns.upstreams \
'[ "9.9.9.9", "149.112.112.112" ]' &>/dev/null
    fi
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
    ufw delete allow "$PIHOLE_PROXY_PORT/tcp" &>/dev/null
    # Delete the leftover rules of former installations that added them for port 53
    for port in 53/tcp 53/udp
    do
        ufw delete allow "$port" &>/dev/null
    done
    # Delete the unbound rule, if it exists
    DOCKER_GATEWAY="$(docker network inspect bridge --format '{{range .IPAM.Config}}{{.Gateway}}{{end}}' 2>/dev/null)"
    if [ -z "$DOCKER_GATEWAY" ]
    then
        DOCKER_GATEWAY=172.17.0.1
    fi
    ufw delete allow in on docker0 to "$DOCKER_GATEWAY" port 5335 comment 'Pi-hole unbound' &>/dev/null
    # Remove unbound, since it was only installed for Pi-hole
    if [ -f /etc/unbound/unbound.conf.d/pi-hole.conf ]
    then
        rm -f /etc/unbound/unbound.conf.d/pi-hole.conf
        # Remove the daily restart cron job
        crontab -u root -l 2>/dev/null | grep -v "restart unbound" | crontab -u root -
        rm -f /etc/systemd/system/unbound.service.d/ncvm-pihole.conf
        rmdir /etc/systemd/system/unbound.service.d &>/dev/null
        systemctl daemon-reload
        if is_this_installed unbound || is_this_installed unbound-anchor
        then
            apt-get purge unbound unbound-anchor -y
            apt-get autoremove -y
        fi
    fi
    # Re-enable the systemd-resolved stub listener since port 53 is free again
    if [ -f /etc/systemd/resolved.conf.d/ncvm-pihole.conf ]
    then
        rm -f /etc/systemd/resolved.conf.d/ncvm-pihole.conf
        systemctl restart systemd-resolved &>/dev/null
        # Restore the resolv.conf symlink to the stub resolver
        if [ -f /run/systemd/resolve/stub-resolv.conf ]
        then
            ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
        elif ! [ -s /etc/resolv.conf ]
        then
            # Neither the stub nor a usable file exists, so write a static one
            printf 'nameserver 9.9.9.9\nnameserver 149.112.112.112\n' > /etc/resolv.conf
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

# Check for a leftover Pi-hole installation from former versions of this script.
# It runs Pi-hole on the host and occupies port 53 and the lighttpd web interface.
if [ -d /etc/.pihole ] || [ -f /usr/local/bin/pihole ] || [ -f /usr/bin/pihole-FTL ]
then
    msg_box "It seems like an old Pi-hole installation is still present on this server.

Former versions of this script installed Pi-hole directly on the host. It occupies \
port 53 and runs its web interface via lighttpd, which means that the new Pi-hole \
container would not be able to start.

You need to uninstall the old Pi-hole first. You can do this by running the \
following command:
'sudo pihole uninstall'

Afterwards, please remove the leftovers with the following commands:
'sudo rm -rf /etc/.pihole /etc/pihole /etc/lighttpd'
'sudo rm -f /usr/local/bin/pihole /usr/bin/pihole-FTL'

Please note that this will remove all your current Pi-hole settings and \
blocklists. You will have to configure them again afterwards.

Please uninstall the old Pi-hole and run this script again."
    exit 1
fi

# Pi-hole needs port 53, which the systemd-resolved stub listener occupies by
# default. We disable it below, but other DNS servers are up to the user.
print_text_in_color "$ICyan" "Checking if port 53 is already in use..."
# Our own container is already removed here, so any leftover is a real conflict.
# We exclude systemd-resolved by its PID, since 'ss' truncates the process name.
RESOLVED_PID="$(systemctl show -p MainPID --value systemd-resolved 2>/dev/null)"
DNS_IN_USE="$(ss -tulpn 2>/dev/null | grep ":53 ")"
if [ -n "$RESOLVED_PID" ] && [ "$RESOLVED_PID" != "0" ]
then
    DNS_IN_USE="$(echo "$DNS_IN_USE" | grep -v "pid=$RESOLVED_PID,")"
fi
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

# Free port 53 by disabling the systemd-resolved stub listener. systemd-resolved
# keeps running as the host resolver but stops listening on 127.0.0.53:53.
print_text_in_color "$ICyan" "Disabling the systemd-resolved DNS stub listener..."
mkdir -p /etc/systemd/resolved.conf.d
cat << RESOLVED_CONF > /etc/systemd/resolved.conf.d/ncvm-pihole.conf
# This file was created by the NcVM Pi-hole script. Pi-hole needs to bind to
# port 53, which is not possible while the stub listener occupies 127.0.0.53:53.
[Resolve]
DNSStubListener=no
RESOLVED_CONF

# With the stub listener disabled, /etc/resolv.conf must not point to the
# stub resolver anymore, since nothing is listening on 127.0.0.53 any longer.
if [ -f /run/systemd/resolve/resolv.conf ]
then
    ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf
elif [ -L /etc/resolv.conf ] && readlink -f /etc/resolv.conf | grep -q "stub-resolv.conf"
then
    # systemd-resolved doesn't provide the uplink file, so we would be left
    # without any working resolver. Write a static one instead.
    rm -f /etc/resolv.conf
    printf 'nameserver 9.9.9.9\nnameserver 149.112.112.112\n' > /etc/resolv.conf
fi

check_command systemctl restart systemd-resolved

# Make sure that name resolution still works before we continue,
# since we just changed the DNS setup of the host
print_text_in_color "$ICyan" "Checking if DNS resolution still works..."
install_if_not dnsutils
if ! nslookup github.com >/dev/null 2>&1
then
    msg_box "DNS resolution stopped working after disabling the systemd-resolved \
stub listener. We will revert this change now and exit.

Please report this to $ISSUES"
    rm -f /etc/systemd/resolved.conf.d/ncvm-pihole.conf
    # Restart first, so that systemd-resolved recreates the stub file that we
    # link to below. Otherwise the host is left without a working resolver.
    systemctl restart systemd-resolved
    if [ -f /run/systemd/resolve/stub-resolv.conf ]
    then
        ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
    fi
    exit 1
fi

# Create the directories for the persistent data
mkdir -p "$PIHOLE_DIR/etc-pihole"
mkdir -p "$PIHOLE_DIR/etc-dnsmasq.d"

# Generate a new Pi-hole password
PASSWORD=$(gen_passwd 12 "a-zA-Z0-9")

# Get the docker container
print_text_in_color "$ICyan" "Getting Pi-hole..."
if ! docker pull pihole/pihole:latest
then
    msg_box "Failed to download the Pi-hole container image.

Please check your internet connection and report this issue here $ISSUES \
if you can't solve it yourself."
    exit 1
fi

# Create Pi-hole. DHCP is not enabled on purpose, hence no NET_ADMIN capability.
# 'dns_listeningMode=all' is needed for queries from outside the bridge network.
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

# Create the vhost that proxies the Pi-hole web interface via https. The cert is
# self-signed since the admin interface is only reachable in the local network.
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

# Add firewall rules. Port 53 is published by the container, which docker opens
# in the nat table before ufw. Former host installations opened it directly.
for port in 53/tcp 53/udp
do
    ufw delete allow "$port" &>/dev/null
done
ufw allow "$PIHOLE_PROXY_PORT"/tcp comment 'Pi-hole Web' &>/dev/null

# Set up unbound if chosen
if [ "$UNBOUND" = "yes" ]
then
    # Install unbound. We do not use install_if_not here, since it installs
    # with RUNLEVEL=1, which skips parts of the package setup.
    if ! is_this_installed unbound || ! is_this_installed unbound-anchor
    then
        apt-get update -q4 & spinner_loading
        check_command apt-get install unbound unbound-anchor -y
    fi

    # Ubuntu makes unbound listen on 127.0.0.1:53 via resolvconf, which
    # conflicts with port 53 that the Pi-hole container publishes
    systemctl disable --now unbound-resolvconf.service &>/dev/null
    rm -f /etc/unbound/unbound.conf.d/resolvconf_resolvers.conf

    # The DNSSEC root trust anchor is not always created by the package,
    # but unbound refuses to start without it
    if ! [ -f /var/lib/unbound/root.key ]
    then
        print_text_in_color "$ICyan" "Creating the DNSSEC root trust anchor..."
        mkdir -p /var/lib/unbound
        # It returns 1 when it had to bootstrap the key from its built-in
        # copy, which is the expected case on a fresh installation
        unbound-anchor -a /var/lib/unbound/root.key || true
        chown unbound:unbound /var/lib/unbound/root.key &>/dev/null
        if ! [ -f /var/lib/unbound/root.key ]
        then
            msg_box "Could not create the DNSSEC root trust anchor in \
'/var/lib/unbound/root.key', which means that unbound cannot start.

Please report this to $ISSUES"
            exit 1
        fi
    fi

    # unbound listens on the docker bridge gateway so that the container can
    # reach it, since 127.0.0.1 would not be reachable from inside it.
    DOCKER_GATEWAY="$(docker network inspect bridge --format '{{range .IPAM.Config}}{{.Gateway}}{{end}}')"
    DOCKER_SUBNET="$(docker network inspect bridge --format '{{range .IPAM.Config}}{{.Subnet}}{{end}}')"
    if [ -z "$DOCKER_GATEWAY" ]
    then
        DOCKER_GATEWAY=172.17.0.1
    fi
    # The subnet is not necessarily in 172.16.0.0/12, since it can be changed
    # via 'default-address-pools' in the docker daemon configuration
    if [ -z "$DOCKER_SUBNET" ]
    then
        DOCKER_SUBNET=172.17.0.0/16
    fi

    cat << UNBOUND_CONF > /etc/unbound/unbound.conf.d/pi-hole.conf
server:
    # To see what those variables do, look here:
    # https://docs.pi-hole.net/guides/unbound/
    verbosity: 0
    interface: $DOCKER_GATEWAY
    # docker0 doesn't exist yet when unbound starts after a reboot,
    # which is why we need to allow binding to a not yet existing address
    ip-freebind: yes
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
    access-control: $DOCKER_SUBNET allow
UNBOUND_CONF

    # Make sure that unbound starts after docker, so that the bridge that it
    # listens on exists and is reachable after a reboot
    mkdir -p /etc/systemd/system/unbound.service.d
    cat << UNBOUND_SERVICE > /etc/systemd/system/unbound.service.d/ncvm-pihole.conf
# This file was created by the NcVM Pi-hole script
[Unit]
After=docker.service
UNBOUND_SERVICE
    systemctl daemon-reload

    # Allow the container to reach unbound on the docker bridge
    ufw allow in on docker0 to "$DOCKER_GATEWAY" port 5335 comment 'Pi-hole unbound' &>/dev/null

    # Restart unbound. A former failed start can latch the unit into a failed
    # state with 'start request repeated too quickly', which we clear first
    print_text_in_color "$ICyan" "Restarting unbound..."
    systemctl reset-failed unbound &>/dev/null
    systemctl restart unbound &>/dev/null

    # Wait for unbound to actually answer instead of guessing a delay, since
    # a restart can still end in a failed unit or a not yet ready resolver
    UNBOUND_READY=no
    for _ in $(seq 1 30)
    do
        if docker exec pihole dig +time=2 +tries=1 @"$DOCKER_GATEWAY" -p 5335 \
nextcloud.com &>/dev/null
        then
            UNBOUND_READY=yes
            break
        fi
        sleep 1
    done
    if [ "$UNBOUND_READY" != "yes" ]
    then
        msg_box "unbound did not start correctly and does not answer queries.

Please report this to $ISSUES"
        exit 1
    fi

    # Testing DNSSEC from inside the container, since unbound refuses queries
    # from the host. A validated answer carries the 'ad' flag.
    if ! docker exec pihole dig +time=10 +tries=1 @"$DOCKER_GATEWAY" -p 5335 \
sigok.verteiltesysteme.net | grep -q "flags:.* ad[;,]"
    then
        msg_box "Something went wrong while testing DNSSEC validation.
unbound did not return an authenticated answer for a signed domain.

Please report this to $ISSUES"
    # A domain with a broken signature must not resolve. unbound either answers
    # with SERVFAIL or doesn't answer at all while it retries the nameservers
    elif docker exec pihole dig +time=10 +tries=1 @"$DOCKER_GATEWAY" -p 5335 \
sigfail.verteiltesysteme.net | grep -q "flags:.* ad[;,]"
    then
        msg_box "Something went wrong while testing DNSSEC validation.
unbound validated a domain with a broken signature.

Please report this to $ISSUES"
    fi

    # Restart unbound daily, since a failed start at boot latches the unit and
    # would leave the Pi-hole without its upstream DNS server until fixed by hand
    crontab -u root -l 2>/dev/null | grep -v "restart unbound" | crontab -u root -
    crontab -u root -l 2>/dev/null | { cat; echo "0 4 * * * systemctl reset-failed \
unbound && systemctl restart unbound"; } | crontab -u root -

    # Configure Pi-hole to use unbound as its upstream DNS server
    print_text_in_color "$ICyan" "Configuring Pi-hole to use unbound..."
    # Wait for pihole-FTL to accept config changes instead of guessing a delay,
    # since writing the config too early is silently lost on startup
    PIHOLE_READY=no
    for _ in $(seq 1 30)
    do
        if docker exec pihole pihole-FTL --config dns.upstreams &>/dev/null
        then
            PIHOLE_READY=yes
            break
        fi
        sleep 2
    done
    # 'dns.upstreams' is an array, hence the value needs to be a json array.
    # The key and the value need to be separate arguments to actually set it.
    if [ "$PIHOLE_READY" != "yes" ] || ! docker exec pihole pihole-FTL --config dns.upstreams "[ \"$DOCKER_GATEWAY#5335\" ]" &>/dev/null
    then
        msg_box "Could not configure Pi-hole to use unbound automatically.

You can do this yourself by visiting https://$ADDRESS:$PIHOLE_PROXY_PORT/admin \
and entering '$DOCKER_GATEWAY#5335' as custom upstream DNS server under \
'Settings' --> 'DNS'."
    elif ! docker restart pihole &>/dev/null
    then
        msg_box "Pi-hole was configured to use unbound, but the container could \
not be restarted to apply it.

Please restart it yourself with 'sudo docker restart pihole' and report this \
issue here $ISSUES if it keeps failing."
    else
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

exit
