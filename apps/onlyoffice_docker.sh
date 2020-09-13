#!/bin/bash

# T&M Hansson IT AB © - 2019, https://www.hanssonit.se/

# shellcheck disable=2034,2059
true
SCRIPT_NAME="OnlyOffice (Docker)"
# shellcheck source=lib.sh
. <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Check if root
root_check

# Nextcloud 13 is required.
lowest_compatible_nc 13

# Test RAM size (2GB min) + CPUs (min 2)
ram_check 2 OnlyOffice
cpu_check 2 OnlyOffice

# Check if Nextcloud is installed with TLS
check_nextcloud_https "OnlyOffice (Docker)"

# Remove OnlyOffice-documentserver if activated
if is_app_enabled documentserver_community
then
    any_key "The integrated OnlyOffice Documentserver will get uninstalled. Press any key to continue. Press CTRL+C to abort"
    occ_command app:remove documentserver_community
fi

# Check if collabora is already installed
print_text_in_color "$ICyan" "Checking if Onlyoffice Docker is already installed..."
if does_this_docker_exist 'onlyoffice/documentserver'
then
    choice=$(whiptail --title "$TITLE" --menu "It seems like 'Onlyoffice Docker' is already installed.\nChoose what you want to do." "$WT_HEIGHT" "$WT_WIDTH" 4 \
    "Reinstall Onlyoffice Docker" "" \
    "Uninstall Onlyoffice Docker" "" 3>&1 1>&2 2>&3)

    case "$choice" in
        "Uninstall Onlyoffice Docker")
            print_text_in_color "$ICyan" "Uninstalling Onlyoffice Docker..."
            # Check if Collabora is previously installed
            # If yes, then stop and prune the docker container
            docker_prune_this 'onlyoffice/documentserver'
            # Revoke LE
            SUBDOMAIN=$(input_box_flow "Please enter the subdomain you are using for OnlyOffice, e.g: office.yourdomain.com")
            if [ -f "$CERTFILES/$SUBDOMAIN/cert.pem" ]
            then
                yes no | certbot revoke --cert-path "$CERTFILES/$SUBDOMAIN/cert.pem"
                REMOVE_OLD="$(find "$LETSENCRYPTPATH/" -name "$SUBDOMAIN*")"
                for remove in $REMOVE_OLD
                    do rm -rf "$remove"
                done
            fi
            # Remove Apache2 config
            if [ -f "$SITES_AVAILABLE/$SUBDOMAIN.conf" ]
            then
                a2dissite "$SUBDOMAIN".conf
                restart_webserver
                rm -f "$SITES_AVAILABLE/$SUBDOMAIN.conf"
            fi
            # Disable RichDocuments (Collabora App) if activated
            if is_app_installed onlyoffice
            then
                occ_command app:remove onlyoffice
            fi
            # Remove trusted domain
            count=0
            while [ "$count" -lt 10 ]
            do
                if [ "$(occ_command_no_check config:system:get trusted_domains "$count")" == "$SUBDOMAIN" ]
                then
                    occ_command_no_check config:system:delete trusted_domains "$count"
                    break
                else
                    count=$((count+1))
                fi
            done
            
            msg_box "Onlyoffice Docker was successfully uninstalled."
            exit
        ;;
        "Reinstall Onlyoffice Docker")
            print_text_in_color "$ICyan" "Reinstalling Onlyoffice Docker..."
            
            # Check if Collabora is previously installed
            # If yes, then stop and prune the docker container
            docker_prune_this 'onlyoffice/documentserver'
        ;;
        *)
        ;;
    esac
else
    print_text_in_color "$ICyan" "Installing Onlyoffice Docker..."
fi

# Check if collabora is installed and remove every trace of it
if does_this_docker_exist 'collabora/code'
then
    msg_box "You can't run both Collabora and OnlyOffice on the same VM. We will now remove Collabora from the server."
    # Remove docker image
    docker_prune_this 'collabora/code'
    # Revoke LE
    SUBDOMAIN=$(input_box_flow "Please enter the subdomain you are using for Collabora, e.g: office.yourdomain.com")
    if [ -f "$CERTFILES/$SUBDOMAIN/cert.pem" ]
    then
        yes no | certbot revoke --cert-path "$CERTFILES/$SUBDOMAIN/cert.pem"
        REMOVE_OLD="$(find "$LETSENCRYPTPATH/" -name "$SUBDOMAIN*")"
        for remove in $REMOVE_OLD
            do rm -rf "$remove"
        done
    fi
    # Remove Apache2 config
    if [ -f "$SITES_AVAILABLE/$SUBDOMAIN.conf" ]
    then
        a2dissite "$SUBDOMAIN".conf
        restart_webserver
        rm -f "$SITES_AVAILABLE/$SUBDOMAIN.conf"
    fi
    # Disable Collabora App if activated
    if is_app_installed richdocuments
    then
       occ_command app:remove richdocuments
    fi
    # Remove trusted domain
    count=0
    while [ "$count" -lt 10 ]
    do
        if [ "$(occ_command_no_check config:system:get trusted_domains "$count")" == "$SUBDOMAIN" ]
        then
            occ_command_no_check config:system:delete trusted_domains "$count"
            break
        else
            count=$((count+1))
        fi
    done
fi

# Check if apache2 evasive-mod is enabled and disable it because of compatibility issues
if [ "$(apache2ctl -M | grep evasive)" != "" ]
then
    msg_box "We noticed that 'mod_evasive' is installed which is the DDOS protection for webservices. It has comptibility issues with OnlyOffice and you can now choose to disable it."
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

# Ask for the domain for OnlyOffice
SUBDOMAIN=$(input_box_flow "OnlyOffice subdomain e.g: office.yourdomain.com\n\nNOTE: This domain must be different than your Nextcloud domain. They can however be hosted on the same server, but would require seperate DNS entries.")

# Nextcloud Main Domain
NCDOMAIN=$(occ_command_no_check config:system:get overwrite.cli.url | sed 's|https://||;s|/||')

# shellcheck disable=2034,2059
true
# shellcheck source=lib.sh
. <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)

# Get all needed variables from the library
nc_update

# Notification
msg_box "Before you start, please make sure that port 80+443 is directly forwarded to this machine!"

# Get the latest packages
apt update -q4 & spinner_loading

# Check if Nextcloud is installed
print_text_in_color "$ICyan" "Checking if Nextcloud is installed..."
if ! curl -s https://"$NCDOMAIN"/status.php | grep -q 'installed":true'
then
msg_box "It seems like Nextcloud is not installed or that you don't use https on:
$NCDOMAIN.
Please install Nextcloud and make sure your domain is reachable, or activate TLS
on your domain to be able to run this script.
If you use the Nextcloud VM you can use the Let's Encrypt script to get TLS and activate your Nextcloud domain.
When TLS is activated, run these commands from your terminal:
sudo curl -sLO $APP/onlyoffice_docker.sh
sudo bash onlyoffice_docker.sh"
    exit 1
fi

# Check if $SUBDOMAIN exists and is reachable
print_text_in_color "$ICyan" "Checking if $SUBDOMAIN exists and is reachable..."
domain_check_200 "$SUBDOMAIN"

# Check open ports with NMAP
check_open_port 80 "$SUBDOMAIN"
check_open_port 443 "$SUBDOMAIN"

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
    # Generate DHparams chifer
    if [ ! -f "$DHPARAMS_SUB" ]
    then
        openssl dhparam -dsaparam -out "$DHPARAMS_SUB" 4096
    fi
    print_text_in_color "$IGreen" "Certs are generated!"
    a2ensite "$SUBDOMAIN.conf"
    restart_webserver
    # Install OnlyOffice
    install_and_enable_app onlyoffice
else
    last_fail_tls "$SCRIPTS"/apps/onlyoffice.sh
    exit 1
fi

# Set config for OnlyOffice
if [ -d "$NC_APPS_PATH"/onlyoffice ]
then
    occ_command config:app:set onlyoffice DocumentServerUrl --value=https://"$SUBDOMAIN/"
    chown -R www-data:www-data "$NC_APPS_PATH"
    occ_command config:system:set trusted_domains 3 --value="$SUBDOMAIN"
    # Add prune command
    add_dockerprune
    # Restart Docker
    print_text_in_color "$ICyan" "Restaring Docker..."
    systemctl restart docker.service
    docker restart onlyoffice
    msg_box "OnlyOffice Docker is now successfully installed."
fi

exit
