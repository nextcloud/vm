#!/bin/bash

# T&M Hansson IT AB © - 2020, https://www.hanssonit.se/

true
SCRIPT_NAME="Collabora (Docker)"
SCRIPT_EXPLAINER="This script will install the Collabora Office Server bundled with Docker"
# shellcheck source=lib.sh
source <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/szaimen-patch-22/lib.sh)

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Check if root
root_check

# Check if Collabora is already installed
if ! does_this_docker_exist 'collabora/code'
then
    # Ask for installing
    install_popup "$SCRIPT_NAME"
else
    # Ask for removal or reinstallation
    reinstall_remove_menu "$SCRIPT_NAME"
    # Removal
    docker_prune_this 'collabora/code'
    # Remove office Domain
    remove_office_domain "$SCRIPT_NAME"
    # Disable RichDocuments (Collabora App) if activated
    nextcloud_occ_no_check config:app:delete richdocuments wopi_url
    if is_app_installed richdocuments
    then
        nextcloud_occ app:remove richdocuments
    fi
    # Show successful uninstall if applicable
    removal_popup "$SCRIPT_NAME"
fi

# Test RAM size (2GB min) + CPUs (min 2)
ram_check 2 "$SCRIPT_NAME"
cpu_check 2 "$SCRIPT_NAME"

# Check for other Office solutions
if does_this_docker_exist 'onlyoffice/documentserver' || is_app_enabled richdocumentscode
then
    raise_ram_check_4gb "$SCRIPT_NAME"
fi

# Check if Nextcloud is installed with TLS
check_nextcloud_https "$SCRIPT_NAME"

# Nextcloud Main Domain dot-escaped
NCDOMAIN_ESCAPED=${NCDOMAIN//[.]/\\\\.}

# Disable OnlyOffice App if activated
disable_office_integration onlyoffice "OnlyOffice"

# Get domain, etc.
office_domain_flow "$SCRIPT_NAME"

# Open ports
open_standard_ports "$SUBDOMAIN"

# Install Docker
install_docker

# Install Collabora docker
docker pull collabora/code:latest
docker run -t -d -p 127.0.0.1:9980:9980 -e "domain=$NCDOMAIN_ESCAPED" --restart always --name code --cap-add MKNOD collabora/code

# Install Apache2
install_if_not apache2

# Enable Apache2 module's
a2enmod proxy
a2enmod proxy_wstunnel
a2enmod proxy_http
a2enmod ssl
a2enmod headers

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

# Create Vhost for Collabora online in Apache2
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
  CustomLog ${APACHE_LOG_DIR}/access.log combined
  ErrorLog ${APACHE_LOG_DIR}/error.log

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

  # static html, js, images, etc. served from loolwsd
  # loleaflet is the client part of LibreOffice Online
  ProxyPass           /loleaflet https://127.0.0.1:9980/loleaflet retry=0
  ProxyPassReverse    /loleaflet https://127.0.0.1:9980/loleaflet

  # WOPI discovery URL
  ProxyPass           /hosting/discovery https://127.0.0.1:9980/hosting/discovery retry=0
  ProxyPassReverse    /hosting/discovery https://127.0.0.1:9980/hosting/discovery

  # Endpoint with information about availability of various features
  ProxyPass           /hosting/capabilities https://127.0.0.1:9980/hosting/capabilities retry=0
  ProxyPassReverse    /hosting/capabilities https://127.0.0.1:9980/hosting/capabilities

  # Main websocket
  ProxyPassMatch "/lool/(.*)/ws$" wss://127.0.0.1:9980/lool/\$1/ws nocanon

  # Admin Console websocket
  ProxyPass   /lool/adminws wss://127.0.0.1:9980/lool/adminws

  # Download as, Fullscreen presentation and Image upload operations
  ProxyPass           /lool https://127.0.0.1:9980/lool
  ProxyPassReverse    /lool https://127.0.0.1:9980/lool
</VirtualHost>
HTTPS_CREATE

# Check if https_conf got created successfully
check_https_conf "$HTTPS_CONF"

# Generate certs
generate_office_cert "$SUBDOMAIN"

# Install Collabora
install_and_enable_app richdocuments

# Set config for RichDocuments (Collabora App)
if is_app_installed richdocuments
then
    nextcloud_occ config:app:set richdocuments wopi_url --value=https://"$SUBDOMAIN"
    chown -R www-data:www-data "$NC_APPS_PATH"
    nextcloud_occ config:system:set trusted_domains 3 --value="$SUBDOMAIN"
    # Add prune command
    add_dockerprune
    # Restart Docker
    print_text_in_color "$ICyan" "Restarting Docker..."
    systemctl restart docker.service
    docker restart code
    msg_box "Collabora is now successfully installed."
fi

# Make sure the script exits
exit
