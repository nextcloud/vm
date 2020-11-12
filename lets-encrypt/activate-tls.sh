#!/bin/bash
true
SCRIPT_NAME="Activate TLS"
# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh || source <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)

# T&M Hansson IT AB © - 2020, https://www.hanssonit.se/

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Check if root
root_check

# Information
# Information
msg_box "Before we begin the installation of your TLS certificate you need to:

1. Have a domain like: cloud.example.com
If you want to get a domain at a fair price, please check this out: https://store.binero.se/?lang=en-US

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

msg_box "Before continuing, please make sure that you have you have edited the DNS settings for $TLSDOMAIN, \
and opened port 80 and 443 directly to this servers IP. A full exstensive guide can be found here:
https://www.techandme.se/open-port-80-443

This can be done automatically if you have UNNP enabled in your firewall/router. \
You will be offered to use UNNP in the next step."

if yesno_box_no "Do you want to use UPNP to open port 80 and 443?"
then
    unset FAIL
    open_port 80 TCP
    open_port 443 TCP
    cleanup_open_port
fi

# Curl the lib another time to get the correct https_conf
# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh || source <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)

# Check if $TLSDOMAIN exists and is reachable
echo
print_text_in_color "$ICyan" "Checking if $TLSDOMAIN exists and is reachable..."
domain_check_200 "$TLSDOMAIN"

# Check if port is open with NMAP
sed -i "s|127.0.1.1.*|127.0.1.1       $TLSDOMAIN nextcloud|g" /etc/hosts
network_ok
check_open_port 80 "$TLSDOMAIN"
check_open_port 443 "$TLSDOMAIN"

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

# Only add TLS 1.3 on Ubuntu later than 20.04
if version 20.04 "$DISTRO" 20.04.10
then
    TLS13="+TLSv1.3"
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
    RewriteRule ^(.*)$ https://%{HTTP_HOST}$1 [R=301,L]
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
    Header add Strict-Transport-Security: "max-age=15768000;includeSubdomains"
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

    DocumentRoot $NCPATH

    <Directory $NCPATH>
    Options Indexes FollowSymLinks
    AllowOverride All
    Require all granted
    Satisfy Any
    </Directory>

    <IfModule mod_dav.c>
    Dav off
    </IfModule>

    SetEnv HOME $NCPATH
    SetEnv HTTP_HOME $NCPATH

    # The following lines prevent .htaccess and .htpasswd files from being
    # viewed by Web clients.
    <Files ".ht*">
    Require all denied
    </Files>

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

    SSLCertificateChainFile $CERTFILES/$TLSDOMAIN/chain.pem
    SSLCertificateFile $CERTFILES/$TLSDOMAIN/cert.pem
    SSLCertificateKeyFile $CERTFILES/$TLSDOMAIN/privkey.pem
    SSLOpenSSLConfCmd DHParameters $DHPARAMS_TLS
</VirtualHost>

### EXTRAS ###
    SSLUseStapling On
    SSLStaplingCache "shmcb:logs/ssl_stapling(32768)"
TLS_CREATE
fi

# Check if PHP-FPM is installed and if not, then remove PHP-FPM related lines from config
if ! pgrep php-fpm
then
    sed -i "s|<FilesMatch.*|# Removed due to that PHP-FPM $PHPVER is missing|g" "$tls_conf"
    sed -i "s|SetHandler.*|#|g" "$tls_conf"
    sed -i "s|</FilesMatch.*|#|g" "$tls_conf"
fi

#Generate certs and auto-configure if successful
if generate_cert "$TLSDOMAIN"
then
    if [ -d "$CERTFILES" ]
    then
        # Generate DHparams chifer
        if [ ! -f "$DHPARAMS_TLS" ]
        then
            openssl dhparam -dsaparam -out "$DHPARAMS_TLS" 4096
        fi
        # Activate new config
        check_command bash "$SCRIPTS/test-new-config.sh" "$TLSDOMAIN.conf"
        msg_box "Please remember to keep port 80 (and 443) open so that Let's Encrypt can do \
the automatic renewal of the cert. If port 80 is closed the cert will expire in 3 months.

You don't need to worry about security as port 80 is directly forwarded to 443, so \
no traffic will actually be on port 80, except for the forwarding to 443 (HTTPS)."
        exit 0
    fi
else
    last_fail_tls "$SCRIPTS"/activate-tls.sh cleanup
fi

exit
