#!/bin/bash

# T&M Hansson IT AB © - 2019, https://www.hanssonit.se/

true
SCRIPT_NAME="OnlyOffice (Docker)"
SCRIPT_EXPLAINER="This script will install the OnlyOffice Document Server bundled with Docker"
# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Check if root
root_check

# Test RAM size (2GB min) + CPUs (min 2)
ram_check 2 OnlyOffice
cpu_check 2 OnlyOffice

# Check if onlyoffice is already installed
if ! does_this_docker_exist 'onlyoffice/documentserver'
then
    # Ask for installing
    install_popup "$SCRIPT_NAME"
else
    # Ask for removal or reinstallation
    reinstall_remove_menu "$SCRIPT_NAME"
    # Removal
    remove_onlyoffice_docker
    # Remove config.php value set when install was successful
    nextcloud_occ config:system:delete allow_local_remote_servers
    nextcloud_occ config:system:delete onlyoffice
    # Show successful uninstall if applicable
    removal_popup "$SCRIPT_NAME"
fi

# Check if collabora is installed and remove every trace of it
if does_this_docker_exist 'collabora/code'
then
    # Removal
    remove_collabora_docker
fi

# Remove all office apps
remove_all_office_apps

# Install certbot (Let's Encrypt)
install_certbot

# Generate certs and auto-configure if successful
export SUBDOMAIN=onlyoffice
if run_script DESEC desec_subdomain
then
    SUBDOMAIN="$(grep onlyoffice -m 1 $SCRIPTS/deSEC/.subdomain | cut -d '=' -f2)"
    # Curl the library another time to get the correct DHPARAMS
    # shellcheck source=lib.sh
    source /var/scripts/fetch_lib.sh || source <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)
    # Generate DHparams cipher
    if [ ! -f "$DHPARAMS_SUB" ]
    then
        openssl dhparam -out "$DHPARAMS_SUB" 2048
    fi
    print_text_in_color "$IGreen" "Certs are generated!"
    # Install OnlyOffice App
    install_and_enable_app onlyoffice
else
    last_fail_tls "$SCRIPTS"/apps/onlyoffice_docker.sh
    exit 1
fi

# Install apache2
install_if_not apache2

# Enable Apache2 module's
a2enmod proxy
a2enmod proxy_wstunnel
a2enmod proxy_http
a2enmod ssl
a2enmod headers

# Only add TLS 1.3 on Ubuntu later than 20.04
if version 20.04 "$DISTRO" 22.04.10
then
    TLS13="+TLSv1.3"
fi

if [ -f "$HTTPS_CONF" ]
then
    a2dissite "$SUBDOMAIN.conf"
    rm -f "$HTTPS_CONF"
fi

# Create Vhost for OnlyOffice Docker online in Apache2
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

    # basic proxy settings
    ProxyRequests off

    ProxyPassMatch (.*)(\/websocket)$ "ws://127.0.0.3:9090/\$1\$2"
    ProxyPass / "http://127.0.0.3:9090/"
    ProxyPassReverse / "http://127.0.0.3:9090/"

    <Location />
        ProxyPassReverse /
    </Location>
</VirtualHost>
HTTPS_CREATE

    if [ -f "$HTTPS_CONF" ];
    then
        print_text_in_color "$IGreen" "$HTTPS_CONF was successfully created."
	a2ensite "$SUBDOMAIN.conf"
        restart_webserver
        sleep 1
    else
        print_text_in_color "$IRed" "Unable to create vhost, exiting..."
        print_text_in_color "$IRed" "Please report this issue here $ISSUES"
        exit 1
    fi
fi

# Check if apache2 evasive-mod is enabled and disable it because of compatibility issues
if [ "$(apache2ctl -M | grep evasive)" != "" ]
then
    msg_box "We noticed that 'mod_evasive' is installed which is the DDOS protection for webservices. \
It has compatibility issues with OnlyOffice and you can now choose to disable it."
    if ! yesno_box_yes "Do you want to disable DDOS protection?"
    then
        print_text_in_color "$ICyan" "Keeping mod_evasive active."
    else
        a2dismod evasive
        # a2dismod mod-evasive # not needed, but existing in the Extra Security script.
        apt-get purge libapache2-mod-evasive -y
	systemctl restart apache2
    fi
fi

# Nextcloud Main Domain
NCDOMAIN=$(nextcloud_occ_no_check config:system:get overwrite.cli.url | sed 's|https://||;s|/||')

true
# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh || source <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)

# Get all needed variables from the library
nc_update

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
sudo curl -sLO $APP/onlyoffice_docker.sh
sudo bash onlyoffice_docker.sh"
    exit 1
fi

# Check if Nextcloud is installed with TLS
check_nextcloud_https "OnlyOffice (Docker)"

# Install Docker
install_docker

ONLYOFFICE_SECRET="$(gen_passwd "$SHUF" "a-zA-Z0-9")"

# Install Onlyoffice docker
docker pull onlyoffice/documentserver:latest
docker run -i -t -d -p 127.0.0.3:9090:80 -e JWT_ENABLED=true -e JWT_HEADER=AuthorizationJwt -e JWT_SECRET="$ONLYOFFICE_SECRET" --restart always --name onlyoffice onlyoffice/documentserver

# Set config for OnlyOffice
if [ -d "$NC_APPS_PATH"/onlyoffice ]
then
    nextcloud_occ config:app:set onlyoffice DocumentServerUrl --value=https://"$SUBDOMAIN/"
    chown -R www-data:www-data "$NC_APPS_PATH"
    # Appending the new domain to trusted domains
    add_to_trusted_domains "$SUBDOMAIN"
    # Allow remote servers with local addresses e.g. in federated shares, webcal services and more
    nextcloud_occ config:system:set allow_local_remote_servers --value="true"
    nextcloud_occ config:system:set onlyoffice jwt_secret --value="$ONLYOFFICE_SECRET"
    nextcloud_occ config:system:set onlyoffice jwt_header --value="AuthorizationJwt"
    # Add prune command
    add_dockerprune
    # Restart Docker
    print_text_in_color "$ICyan" "Restarting Docker..."
    docker restart onlyoffice
    msg_box "OnlyOffice Docker is now successfully installed. 
Please be aware that the container is currently starting which can take a few minutes."
fi

exit