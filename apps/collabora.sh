#!/bin/bash

# T&M Hansson IT AB © - 2020, https://www.hanssonit.se/

# shellcheck disable=2034,2059
true
# shellcheck source=lib.sh
source /var/scripts/main/lib.sh &>/dev/null || . <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh) &>/dev/null

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
ram_check 2 Collabora
cpu_check 2 Collabora

# Check if collabora is already installed
print_text_in_color "$ICyan" "Checking if Collabora is already installed..."
if does_this_docker_exist 'collabora/code'
then
    choice=$(whiptail --radiolist "It seems like 'Collabora' is already installed.\nChoose what you want to do.\nSelect by pressing the spacebar and ENTER" "$WT_HEIGHT" "$WT_WIDTH" 4 \
    "Uninstall Collabora" "" OFF \
    "Reinstall Collabora" "" ON 3>&1 1>&2 2>&3)

    case "$choice" in
        "Uninstall Collabora")
            print_text_in_color "$ICyan" "Uninstalling Collabora..."
            # Check if Collabora is previously installed
            # If yes, then stop and prune the docker container
            docker_prune_this 'collabora/code'
            # Revoke LE
            SUBDOMAIN=$(whiptail --title "T&M Hansson IT - Collabora" --inputbox "Please enter the subdomain you are using for Collabora, eg: office.yourdomain.com" "$WT_HEIGHT" "$WT_WIDTH" 3>&1 1>&2 2>&3)
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

            msg_box "Collabora was successfully uninstalled."
            exit
        ;;
        "Reinstall Collabora")
            print_text_in_color "$ICyan" "Reinstalling Collabora..."

            # Check if Collabora is previously installed
            # If yes, then stop and prune the docker container
            docker_prune_this 'collabora/code'
        ;;
        *)
        ;;
    esac
else
    print_text_in_color "$ICyan" "Installing Collabora..."
fi

# Check if OnlyOffice is previously installed
# If yes, then stop and prune the docker container
if does_this_docker_exist 'onlyoffice/documentserver'
then
    docker_prune_this 'onlyoffice/documentserver'
    # Revoke LE
    SUBDOMAIN=$(whiptail --title "T&M Hansson IT - Collabora" --inputbox "Please enter the subdomain you are using for OnlyOffice, eg: office.yourdomain.com" "$WT_HEIGHT" "$WT_WIDTH" 3>&1 1>&2 2>&3)
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

# remove OnlyOffice-documentserver if activated
if is_app_enabled documentserver_community
then
    any_key "OnlyOffice will get uninstalled. Press any key to continue. Press CTRL+C to abort"
    occ_command app:remove documentserver_community
fi

# Disable OnlyOffice App if activated
if is_app_installed onlyoffice
then
    occ_command app:remove onlyoffice
fi

# Get needed variables
nc_update
collabora_install

# Notification
msg_box "Before you start, please make sure that port 80+443 is directly forwarded to this machine!"

# Get the latest packages
apt update -q4 & spinner_loading

# Check if Nextcloud is installed
print_text_in_color "$ICyan" "Checking if Nextcloud is installed..."
if ! curl -s https://"${NCDOMAIN//\\/}"/status.php | grep -q 'installed":true'
then
msg_box "It seems like Nextcloud is not installed or that you don't use https on:
${NCDOMAIN//\\/}.
Please install Nextcloud and make sure your domain is reachable, or activate TLS
on your domain to be able to run this script.

If you use the Nextcloud VM you can use the Let's Encrypt script to get TLS and activate your Nextcloud domain.
When TLS is activated, run these commands from your terminal:
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

# Install Docker
install_docker

# Install Collabora docker
docker pull collabora/code:latest
docker run -t -d -p 127.0.0.1:9980:9980 -e "domain=$NCDOMAIN" --restart always --name code --cap-add MKNOD collabora/code

# Install Apache2
install_if_not apache2

# Enable Apache2 module's
a2enmod proxy
a2enmod proxy_wstunnel
a2enmod proxy_http
a2enmod ssl

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
  SSLEngine on
  SSLCertificateChainFile $CERTFILES/$SUBDOMAIN/chain.pem
  SSLCertificateFile $CERTFILES/$SUBDOMAIN/cert.pem
  SSLCertificateKeyFile $CERTFILES/$SUBDOMAIN/privkey.pem
  SSLOpenSSLConfCmd DHParameters $DHPARAMS_SUB
  SSLProtocol             all -SSLv2 -SSLv3
  SSLCipherSuite ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA256:ECDHE-ECDSA-AES128-SHA:ECDHE-RSA-AES256-SHA384:ECDHE-RSA-AES128-SHA:ECDHE-ECDSA-AES256-SHA384:ECDHE-ECDSA-AES256-SHA:ECDHE-RSA-AES256-SHA:DHE-RSA-AES128-SHA256:DHE-RSA-AES128-SHA:DHE-RSA-AES256-SHA256:DHE-RSA-AES256-SHA:ECDHE-ECDSA-DES-CBC3-SHA:ECDHE-RSA-DES-CBC3-SHA:EDH-RSA-DES-CBC3-SHA:AES128-GCM-SHA256:AES256-GCM-SHA384:AES128-SHA256:AES256-SHA256:AES128-SHA:AES256-SHA:DES-CBC3-SHA:!DSS
  SSLHonorCipherOrder     on
  SSLCompression off

  # Encoded slashes need to be allowed
  AllowEncodedSlashes NoDecode

  # Container uses a unique non-signed certificate
  SSLProxyEngine On
  SSLProxyVerify None
  SSLProxyCheckPeerCN Off
  SSLProxyCheckPeerName Off

  # keep the host
  ProxyPreserveHost On

  # static html, js, images, etc. served from loolwsd
  # loleaflet is the client part of LibreOffice Online
  ProxyPass           /loleaflet https://127.0.0.1:9980/loleaflet retry=0
  ProxyPassReverse    /loleaflet https://127.0.0.1:9980/loleaflet

  # WOPI discovery URL
  ProxyPass           /hosting/discovery https://127.0.0.1:9980/hosting/discovery retry=0
  ProxyPassReverse    /hosting/discovery https://127.0.0.1:9980/hosting/discovery

  # Main websocket
  ProxyPassMatch "/lool/(.*)/ws$" wss://127.0.0.1:9980/lool/\$1/ws nocanon

  # Admin Console websocket
  ProxyPass   /lool/adminws wss://127.0.0.1:9980/lool/adminws

  # Download as, Fullscreen presentation and Image upload operations
  ProxyPass           /lool https://127.0.0.1:9980/lool
  ProxyPassReverse    /lool https://127.0.0.1:9980/lool
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
    printf "%b" "${IGreen}Certs are generated!\n${Color_Off}"
    a2ensite "$SUBDOMAIN.conf"
    restart_webserver
    # Install Collabora App
    install_and_enable_app richdocuments
else
    last_fail_tls "$SCRIPTS"/apps/collabora.sh
fi

# Set config for RichDocuments (Collabora App)
if is_app_installed richdocuments
then
    occ_command config:app:set richdocuments wopi_url --value=https://"$SUBDOMAIN"
    chown -R www-data:www-data "$NC_APPS_PATH"
    occ_command config:system:set trusted_domains 3 --value="$SUBDOMAIN"
    # Add prune command
    {
    echo "#!/bin/bash"
    echo "docker system prune -a --force"
    echo "exit"
    } > "$SCRIPTS/dockerprune.sh"
    chmod a+x "$SCRIPTS/dockerprune.sh"
    crontab -u root -l | { cat; echo "@weekly $SCRIPTS/dockerprune.sh"; } | crontab -u root -
    print_text_in_color "$ICyan" "Docker automatic prune job added."
    systemctl restart docker.service
    docker restart code
    print_text_in_color "$IGreen" "Collabora is now successfully installed."
    any_key "Press any key to continue... "
fi

# Make sure the script exits
exit
