#!/bin/bash
true
SCRIPT_NAME="Activate TLS"
# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh

# T&M Hansson IT AB © - 2024, https://www.hanssonit.se/

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Check if root
root_check

# Information
if [ -n "$DEDYNDOMAIN" ]
then
    TLSDOMAIN="$DEDYNDOMAIN"
else
    msg_box "Before we begin the installation of your TLS certificate you need to:

1. Have a domain like: cloud.example.com
If you want to get a domain at a fair price, please check this out: https://www.websupport.se/en/

2. Open port 80 and 443 against this servers IP address: $ADDRESS.
Here is a guide: https://www.techandme.se/open-port-80-443
It's also possible to automatically open ports with UPNP, if you have that enabled in your firewall/router.

PLEASE NOTE:
This script can be run again by executing: sudo bash $SCRIPTS/menu.sh, and choose 'Server Configuration' --> 'Activate TLS'"

    if ! yesno_box_yes "Are you sure you want to continue?"
    then
        msg_box "OK, but if you want to run this script later, just execute this in your CLI: sudo \
bash /var/scripts/menu.sh and choose 'Server Configuration' --> 'Activate TLS'"
        exit
    fi

    if ! yesno_box_yes "Have you opened port 80 and 443 in your router, or are you using UPNP?"
    then
        msg_box "OK, but if you want to run this script later, just execute this in your CLI: sudo \
bash /var/scripts/menu.sh and choose 'Server Configuration' --> 'Activate TLS'"
        exit
    fi

    if ! yesno_box_yes "Do you have a domain that you will use?"
    then
        msg_box "OK, but if you want to run this script later, just execute this in your CLI: sudo \
bash /var/scripts/menu.sh and choose 'Server Configuration' --> 'Activate TLS'"
        exit
    fi

    # Nextcloud Main Domain (activate-tls.sh)
    TLSDOMAIN=$(input_box_flow "Please enter the domain name you will use for Nextcloud.
Make sure it looks like this:\nyourdomain.com, or cloud.yourdomain.com")
fi

if [ -z "$DEDYNDOMAIN" ]
then
   msg_box "Before continuing, please make sure that you have you have edited the DNS settings for $TLSDOMAIN, \
and opened port 80 and 443 directly to this servers IP. A full extensive guide can be found here:
https://www.techandme.se/open-port-80-443

This can be done automatically if you have UPNP enabled in your firewall/router. \
You will be offered to use UPNP in the next step."

    if yesno_box_no "Do you want to use UPNP to open port 80 and 443?"
    then
        unset FAIL
        open_port 80 TCP
        open_port 443 TCP
        cleanup_open_port
    fi
fi

# Curl the lib another time to get the correct https_conf
# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh

# Check if $TLSDOMAIN exists and is reachable
echo
print_text_in_color "$ICyan" "Checking if $TLSDOMAIN exists and is reachable..."
domain_check_200 "$TLSDOMAIN"

# Set /etc/hosts domain
sed -i "s|127.0.1.1.*|127.0.1.1       $TLSDOMAIN nextcloud|g" /etc/hosts
network_ok
    
if [ -z "$DEDYNDOMAIN" ]
then
    # Check if port is open with NMAP
    check_open_port 80 "$TLSDOMAIN"
    check_open_port 443 "$TLSDOMAIN"
fi

# Fetch latest version of test-new-config.sh
check_command download_script LETS_ENC test-new-config

# Install certbot (Let's Encrypt)
install_certbot

#Fix issue #28
tls_conf="$SITES_AVAILABLE/$TLSDOMAIN.conf"

# Check if "$tls.conf" exists, and if, then delete
if [ -f "$tls_conf" ]
then
    rm -f "$tls_conf"
fi

# Check current PHP version --> PHPVER
# To get the correct version for the Apache conf file
check_php

# Only add TLS 1.3 on Ubuntu later than 22.04
if version 22.04 "$DISTRO" 24.04.10
then
    TLS13="+TLSv1.3"
fi

# Fix zero file sizes
# See https://github.com/nextcloud/server/issues/3056
if version 24.04 "$DISTRO" 26.04.10
then
    SETENVPROXY="SetEnv proxy-sendcl 1"
fi

# Install Brotli
if version 24.04 "$DISTRO" 26.04.10
then
    if ! [ -f /etc/apache2/conf-available/brotli.conf ]
    then
        # Install needed packaages
        install_if_not brotli

        # Add the config
        {
            echo "# Brotli support"
            echo "<IfModule mod_brotli.c>"
            echo "    AddOutputFilterByType BROTLI_COMPRESS text/html text/plain text/xml text/css text/javascript application/x-javascript application/javascript application/json application/x-font-ttf application/vnd.ms-fontobject image/x-icon"
            echo "</IfModule>"
        } > /etc/apache2/conf-available/brotli.conf

        # Enable the config
        a2enmod brotli
        a2enconf brotli
    fi
fi

# Generate nextcloud_tls_domain.conf
if [ ! -f "$tls_conf" ]
then
    touch "$tls_conf"
    print_text_in_color "$IGreen" "$tls_conf was successfully created."
    sleep 2
    cat << TLS_CREATE > "$tls_conf"
<VirtualHost *:80>
    RewriteEngine On
    RewriteRule ^(.*)$ https://%{HTTP_HOST}\$1 [END,NE,R=permanent]
</VirtualHost>

<VirtualHost *:443>
### YOUR SERVER ADDRESS ###

    ServerAdmin admin@$TLSDOMAIN
    ServerName $TLSDOMAIN

### SETTINGS ###
    <FilesMatch "\.php$">
        SetHandler "proxy:unix:/run/php/php$PHPVER-fpm.nextcloud.sock|fcgi://localhost"
    </FilesMatch>

    # Intermediate configuration
    Header add Strict-Transport-Security: "max-age=15552000;includeSubdomains"
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

    # Document root folder
    DocumentRoot $NCPATH

    # The Nextcloud folder
    <Directory $NCPATH>
    Options Indexes FollowSymLinks
    AllowOverride All
    Require all granted
    Satisfy Any
    # This is to include all the Nextcloud rules due to that we use PHP-FPM and .htaccess aren't read
    Include $NCPATH/.htaccess
    </Directory>

    # Deny access to your data directory
    <Directory $NCDATA>
    Require all denied
    </Directory>

    # Deny access to the Nextcloud config folder
    <Directory $NCPATH/config/>
    Require all denied
    </Directory>

    <IfModule mod_dav.c>
    Dav off
    </IfModule>

    # The following lines prevent .htaccess and .htpasswd files from being viewed by Web clients.
    <Files ".ht*">
    Require all denied
    </Files>

    SetEnv HOME $NCPATH
    SetEnv HTTP_HOME $NCPATH

    # Disable HTTP TRACE method.
    TraceEnable off
    # Disable HTTP TRACK method.
    RewriteEngine On
    RewriteCond %{REQUEST_METHOD} ^TRACK
    RewriteRule .* - [R=405,L]

    # Avoid "Sabre\DAV\Exception\BadRequest: expected filesize XXXX got XXXX"
    <IfModule mod_reqtimeout.c>
    RequestReadTimeout body=0
    </IfModule>

### LOCATION OF CERT FILES ###

    # SSLCertificateChainFile $CERTFILES/$TLSDOMAIN/chain.pem
    SSLCertificateFile $CERTFILES/$TLSDOMAIN/fullchain.pem
    SSLCertificateKeyFile $CERTFILES/$TLSDOMAIN/privkey.pem
    SSLOpenSSLConfCmd DHParameters $DHPARAMS_TLS
</VirtualHost>

### EXTRAS ###
    SSLUseStapling On
    SSLStaplingCache "shmcb:logs/ssl_stapling(32768)"
    $SETENVPROXY
TLS_CREATE
fi

# Check if PHP-FPM is installed and if not, then remove PHP-FPM related lines from config
if ! pgrep php-fpm
then
    sed -i "s|<FilesMatch.*|# Removed due to that PHP-FPM $PHPVER is missing|g" "$tls_conf"
    sed -i "s|SetHandler.*|#|g" "$tls_conf"
    sed -i "s|</FilesMatch.*|#|g" "$tls_conf"
fi

# Generate certs and auto-configure if successful
if [ -n "$DEDYNDOMAIN" ]
then
    print_text_in_color "$ICyan" "Generating new TLS cert with DNS and deSEC, please don't abort the hook, it may take a while..."
    # Renew with DNS by default
    if certbot certonly --manual --text --key-type ecdsa --renew-by-default --server https://acme-v02.api.letsencrypt.org/directory --no-eff-email --agree-tos --preferred-challenges dns --manual-auth-hook "$SCRIPTS"/deSEC/hook.sh --manual-cleanup-hook "$SCRIPTS"/deSEC/hook.sh -d "$DEDYNDOMAIN"
    then
        # Generate DHparams cipher
        if [ -f "$DHPARAMS_TLS" ]
        then
            rm -f "$DHPARAMS_TLS"
            openssl dhparam -out "$DHPARAMS_TLS" 2048
        else
            openssl dhparam -out "$DHPARAMS_TLS" 2048
        fi
        # Choose which port for public access
        msg_box "You will now be able to choose which port you want to put your Nextcloud on for public access.\n
The default port is 443 for HTTPS and if you don't change port, that's the port we will use.\n
Please keep in mind NOT to use the following ports as they are likely in use already:
${NONO_PORTS[*]}"
        if yesno_box_no "Do you want to change the default HTTPS port (443) to something else?"
        then
            # Ask for port
            while :
            do
                DEDYNPORT=$(input_box_flow "Please choose which port you want between 1024 - 49151.\n\nPlease remember to open this port in your firewall.")
                if (("$DEDYNPORT" >= 1024 && "$DEDYNPORT" <= 49151))
                then
                    if check_nono_ports "$DEDYNPORT"
                    then
                        print_text_in_color "$ICyan" "Changing to port $DEDYNPORT for public access..."
                        # Main port
                        sed -i "s|VirtualHost \*:443|VirtualHost \*:$DEDYNPORT|g" "$tls_conf"
                        if ! grep -q "Listen $DEDYNPORT" /etc/apache2/ports.conf
                        then
                            echo "Listen $DEDYNPORT" >> /etc/apache2/ports.conf
                        fi
                        # HTTP redirect
                        if ! grep -q '{HTTP_HOST}':"$DEDYNPORT" "$tls_conf"
                        then
                            sed -i "s|{HTTP_HOST}|{HTTP_HOST}:$DEDYNPORT|g" "$tls_conf"
                        fi
                        # Test everything
                        check_command bash "$SCRIPTS/test-new-config.sh" "$TLSDOMAIN.conf"
                        if restart_webserver
                        then
                            msg_box "Congrats! You should now be able to access Nextcloud publicly on: https://$TLSDOMAIN:$DEDYNPORT, after you opened port $DEDYNPORT in your firewall."
                            break
                        fi
                    fi
                else
                    msg_box "The port number needs to be between 1024 - 49151, please try again."
                fi
            done
        else
            if [ -f "$SCRIPTS/test-new-config.sh" ]
            then
                check_command bash "$SCRIPTS/test-new-config.sh" "$TLSDOMAIN.conf"
                if restart_webserver
                then
                    msg_box "Congrats! You should now be able to access Nextcloud publicly on: https://$TLSDOMAIN after you opened port 443 in your firewall."
                fi
            fi
        fi
    fi
else
    if generate_cert "$TLSDOMAIN"
    then
        if [ -d "$CERTFILES" ]
        then
            # Generate DHparams cipher
            if [ -f "$DHPARAMS_TLS" ]
            then
                rm -f "$DHPARAMS_TLS"
                openssl dhparam -out "$DHPARAMS_TLS" 2048
            else
                openssl dhparam -out "$DHPARAMS_TLS" 2048
            fi
            # Activate new config
            check_command bash "$SCRIPTS/test-new-config.sh" "$TLSDOMAIN.conf"
            msg_box "Please remember to keep port 80 (and 443) open so that Let's Encrypt can do
the automatic renewal of your cert. If port 80 is closed the cert will expire in 3 months!

We follow best practice standards and redirect all traffic from port 80 to 443. We also configured the TLS settings itself to be very secure.
You can read more about what Let's Encrypt recommend here: https://letsencrypt.org/docs/allow-port-80/

It's A+ grade security, see for yourself: https://www.ssllabs.com/ssltest/"

msg_box "Let's Encrypt is 100% free. You can read more about it here:
https://letsencrypt.org/about/

Please consider showing them your gratitude:
https://letsencrypt.org/become-a-sponsor/

If you want to contribute to these scripts, have a look here:
https://github.com/nextcloud/vm/tree/main/lets-encrypt"
            exit 0
        fi
    else
        last_fail_tls "$SCRIPTS"/activate-tls.sh cleanup
    fi
fi

exit
