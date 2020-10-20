#!/bin/bash

# T&M Hansson IT AB © - 2019, https://www.hanssonit.se/

# shellcheck disable=2034,2059
true
SCRIPT_NAME="OnlyOffice (Docker)"
SCRIPT_EXPLAINER="This script will install the OnlyOffice Document Server bundled with Docker"
# shellcheck source=lib.sh
source <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/szaimen-patch-22/lib.sh)

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Check if root
root_check

# Check if collabora is already installed
if ! does_this_docker_exist 'onlyoffice/documentserver'
then
    # Ask for installing
    install_popup "$SCRIPT_NAME"
else
    # Ask for removal or reinstallation
    reinstall_remove_menu "$SCRIPT_NAME"
    # Removal
    docker_prune_this 'onlyoffice/documentserver'
    # Remove office Domain
    remove_office_domain "$SCRIPT_NAME"
    # Disable onlyoffice if activated
    nextcloud_occ_no_check config:app:delete onlyoffice DocumentServerUrl
    if is_app_installed onlyoffice
    then
        nextcloud_occ app:remove onlyoffice
    fi
    # Show successful uninstall if applicable
    removal_popup "$SCRIPT_NAME"
fi

# Nextcloud 18 is required.
lowest_compatible_nc 18

# Test RAM size (2GB min) + CPUs (min 2)
ram_check 2 "$SCRIPT_NAME"
cpu_check 2 "$SCRIPT_NAME"

# Check for other Office solutions
if does_this_docker_exist 'collabora/code' || is_app_enabled richdocumentscode
then
    raise_ram_check_4gb "$SCRIPT_NAME"
fi

# Check if Nextcloud is installed with TLS
check_nextcloud_https "$SCRIPT_NAME"

# Disable Collabora App if activated
disable_office_integration richdocuments "Collabora Online"

# Check if apache2 evasive-mod is enabled and disable it because of compatibility issues
disable_mod_evasive

# Get domain, etc.
office_domain_flow "$SCRIPT_NAME"

# Open ports
open_standard_ports "$SUBDOMAIN"

# Install Docker
install_docker

# Install Onlyoffice docker
docker pull onlyoffice/documentserver:latest
docker run -i -t -d -p 127.0.0.3:9090:80 --restart always --name onlyoffice onlyoffice/documentserver

# Licensed version
# https://helpcenter.onlyoffice.com/server/integration-edition/docker/docker-installation.aspx
# docker run -i -t -d -p 127.0.0.3:9090:80 --restart=always --name onlyoffice \
# -v /app/onlyoffice/DocumentServer/data:/var/www/onlyoffice/Data  onlyoffice/documentserver-ie

# Install apache2
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
    check_command rm "$HTTPS_CONF"
fi

# Create Vhost for OnlyOffice Docker online in Apache2
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

    # Improve security settings
    Header set X-XSS-Protection "1; mode=block"
    Header set Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
    Header set X-Content-Type-Options nosniff
    Header set Content-Security-Policy "frame-ancestors 'self' $NCDOMAIN"

    # contra mixed content warnings
    RequestHeader set X-Forwarded-Proto "https"

    # basic proxy settings
    ProxyRequests off

    ProxyPassMatch (.*)(\/websocket)$ "ws://127.0.0.3:9090/$1$2"
    ProxyPass / "http://127.0.0.3:9090/"
    ProxyPassReverse / "http://127.0.0.3:9090/"
        
    <Location />
        ProxyPassReverse /
    </Location>
</VirtualHost>
HTTPS_CREATE

# Check if https_conf got created successfully
check_https_conf "$HTTPS_CONF"

# Generate certs
generate_office_cert "$SUBDOMAIN"

# Install OnlyOffice
install_and_enable_app onlyoffice

# Set config for OnlyOffice
if [ -d "$NC_APPS_PATH"/onlyoffice ]
then
    nextcloud_occ config:app:set onlyoffice DocumentServerUrl --value=https://"$SUBDOMAIN/"
    chown -R www-data:www-data "$NC_APPS_PATH"
    nextcloud_occ config:system:set trusted_domains 3 --value="$SUBDOMAIN"
    # Check the connection
    nextcloud_occ app:update onlyoffice
    nextcloud_occ onlyoffice:documentserver --check
    # Add prune command
    add_dockerprune
    # Restart Docker
    print_text_in_color "$ICyan" "Restaring Docker..."
    systemctl restart docker.service
    docker restart onlyoffice
    msg_box "OnlyOffice Docker is now successfully installed."
fi

exit
