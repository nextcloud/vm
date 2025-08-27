#!/bin/bash

# T&M Hansson IT AB © - 2024, https://www.hanssonit.se/

true
SCRIPT_NAME="Collabora (Docker)"
SCRIPT_EXPLAINER="This script will install the Collabora Office Server bundled with Docker"
# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh || source <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/main/lib.sh)
# To work with https://github.com/nextcloud/richdocuments/pull/2235

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Check if root
root_check

# Check if Collabora is already installed
print_text_in_color "$ICyan" "Checking if Collabora is already installed..."
if ! does_this_docker_exist 'collabora/code'
then
    # Ask for installing
    install_popup "$SCRIPT_NAME"
else
    # Ask for removal or reinstallation
    reinstall_remove_menu "$SCRIPT_NAME"
    # Removal
    remove_collabora_docker
    # Remove config.php value set when install was successful
    nextcloud_occ config:system:delete allow_local_remote_servers
    # Show successful uninstall if applicable
    removal_popup "$SCRIPT_NAME"
fi

# Check if OnlyOffice is previously installed
# If yes, then stop and prune the docker container
if does_this_docker_exist 'onlyoffice/documentserver'
then
    # Removal
    remove_onlyoffice_docker
fi

# Remove all office apps
remove_all_office_apps

# Ask for the domain for Collabora
SUBDOMAIN=$(input_box_flow "Collabora subdomain e.g: office.yourdomain.com

NOTE: This domain must be different than your Nextcloud domain. \
They can however be hosted on the same server, but would require separate DNS entries.")

# Nextcloud Main Domain
NCDOMAIN=$(nextcloud_occ_no_check config:system:get overwrite.cli.url | sed 's|https://||;s|/||')

# Curl the library another time to get the correct https_conf
# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh || source <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/main/lib.sh)

# Get all needed variables from the library
nc_update

# Notification
msg_box "Before continuing, please make sure that you have you have \
edited the DNS settings for $SUBDOMAIN, and opened port 80 and 443 \
directly to this servers IP. A full exstensive guide can be found here:
https://www.techandme.se/open-port-80-443

This can be done automatically if you have UPNP enabled in your firewall/router. \
You will be offered to use UPNP in the next step.

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
sudo curl -sLO $APP/collabora.sh
sudo bash collabora.sh"
    exit 1
fi

# Check if $SUBDOMAIN exists and is reachable
print_text_in_color "$ICyan" "Checking if $SUBDOMAIN exists and is reachable..."
domain_check_200 "$SUBDOMAIN"

# Check open ports with NMAP
check_open_port 80 "$SUBDOMAIN"
check_open_port 443 "$SUBDOMAIN"

# Test RAM size (2GB min) + CPUs (min 2)
ram_check 2 Collabora
cpu_check 2 Collabora

# Check if Nextcloud is installed with TLS
check_nextcloud_https "Collabora (Docker)"

# Install Docker
install_docker

# Install Collabora docker
docker pull collabora/code:latest
docker run -t -d -p 127.0.0.1:9980:9980 -e "aliasgroup1=https://$NCDOMAIN:443" --restart always --name code --cap-add MKNOD collabora/code

# Install Apache2
install_if_not apache2

# Enable Apache2 module's
a2enmod proxy
a2enmod proxy_wstunnel
a2enmod proxy_http
a2enmod ssl
a2enmod headers

# Only add TLS 1.3 on Ubuntu later than 22.04
if version 22.04 "$DISTRO" 24.04.10
then
    TLS13="+TLSv1.3"
fi

if [ -f "$HTTPS_CONF" ]
then
    a2dissite "$SUBDOMAIN.conf"
    rm -f "$HTTPS_CONF"
fi

# Create Vhost for Collabora online in Apache2
if [ ! -f "$HTTPS_CONF" ];
then
    cat << HTTPS_CREATE > "$HTTPS_CONF"
<VirtualHost *:443>
  ServerName $SUBDOMAIN:443

  <Directory /var/www>
  Options -Indexes
  </Directory>

  # TLS configuration, you may want to take the easy route instead and use Lets Encrypt!
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

  # Encoded slashes need to be allowed
  AllowEncodedSlashes NoDecode

  # Container uses a unique non-signed certificate
  SSLProxyEngine On
  SSLProxyVerify None
  SSLProxyCheckPeerCN Off
  SSLProxyCheckPeerName Off

  # Improve security settings
  Header set X-XSS-Protection "1; mode=block"
  Header set Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
  Header set X-Content-Type-Options nosniff
  Header set Content-Security-Policy "frame-ancestors 'self' $NCDOMAIN"

  # keep the host
  ProxyPreserveHost On

  # static html, js, images, etc. served from coolwsd
  # browser is the client part of LibreOffice Online
  ProxyPass           /browser https://127.0.0.1:9980/browser retry=0
  ProxyPassReverse    /browser https://127.0.0.1:9980/browser

  # WOPI discovery URL
  ProxyPass           /hosting/discovery https://127.0.0.1:9980/hosting/discovery retry=0
  ProxyPassReverse    /hosting/discovery https://127.0.0.1:9980/hosting/discovery

  # Endpoint with information about availability of various features
  ProxyPass           /hosting/capabilities https://127.0.0.1:9980/hosting/capabilities retry=0
  ProxyPassReverse    /hosting/capabilities https://127.0.0.1:9980/hosting/capabilities

  # Main websocket
  ProxyPassMatch "/cool/(.*)/ws$" wss://127.0.0.1:9980/cool/\$1/ws nocanon

  # Admin Console websocket
  ProxyPass   /cool/adminws wss://127.0.0.1:9980/cool/adminws

  # Download as, Fullscreen presentation and Image upload operations
  ProxyPass           /cool https://127.0.0.1:9980/cool
  ProxyPassReverse    /cool https://127.0.0.1:9980/cool
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
    # Generate DHparams cipher
    if [ ! -f "$DHPARAMS_SUB" ]
    then
        openssl dhparam -out "$DHPARAMS_SUB" 2048
    fi
    print_text_in_color "$IGreen" "Certs are generated!"
    a2ensite "$SUBDOMAIN.conf"
    restart_webserver
    # Install Collabora App
    install_and_enable_app richdocuments
else
    last_fail_tls "$SCRIPTS"/apps/collabora.sh
    exit 1
fi

# Set config for RichDocuments (Collabora App)
if is_app_installed richdocuments
then
    nextcloud_occ config:app:set richdocuments wopi_url --value=https://"$SUBDOMAIN"
    chown -R www-data:www-data "$NC_APPS_PATH"
    # Appending the new domain to trusted domains
    add_to_trusted_domains "$SUBDOMAIN"
    # Allow remote servers with local addresses e.g. in federated shares, webcal services and more
    nextcloud_occ config:system:set allow_local_remote_servers --value="true"
    # Add prune command
    add_dockerprune
    print_text_in_color "$ICyan" "Restarting Docker..."
    docker restart code
    msg_box "Collabora Docker is now successfully installed. 
Please be aware that the container is currently starting which can take a few minutes."
fi

# Make sure the script exits
exit
