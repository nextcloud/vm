#!/bin/bash
# shellcheck disable=2034,2059
true
# shellcheck source=lib.sh
. <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)

# T&M Hansson IT AB © - 2020, https://www.hanssonit.se/

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Check if root
root_check

# Information
msg_box "Important! Please read this:

This script will install SSL from Let's Encrypt.
It's free of charge, and very easy to maintain.

Before we begin the installation you need to have
a domain that the SSL certs will be valid for.
If you don't have a domain yet, get one before
you run this script!

You also have to open port 80+443 against this VMs
IP address: $ADDRESS - do this in your router/FW.
Here is a guide: https://goo.gl/Uyuf65

You can find the script here: $SCRIPTS/activate-ssl.sh
and you can run it after you got a domain.

Please don't run this script if you don't have
a domain yet. You can get one for a fair price here:
https://store.binero.se/?lang=en-US"

if [[ "no" == $(ask_yes_or_no "Are you sure you want to continue?") ]]
then
msg_box "OK, but if you want to run this script later,
just type: sudo bash $SCRIPTS/activate-ssl.sh"
    exit
fi

if [[ "no" == $(ask_yes_or_no "Have you forwarded port 80+443 in your router?") ]]
then
msg_box "OK, but if you want to run this script later,
just type: sudo bash /var/scripts/activate-ssl.sh"
    exit
fi

if [[ "yes" == $(ask_yes_or_no "Do you have a domain that you will use?") ]]
then
    sleep 1
else
msg_box "OK, but if you want to run this script later,
just type: sudo bash /var/scripts/activate-ssl.sh"
    exit
fi

# shellcheck disable=2034,2059
true
# shellcheck source=lib.sh
TLS_INSTALL=1 . <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)
unset TLS_INSTALL
while true
do
# Ask for domain name
if [[ "yes" == $(ask_yes_or_no "Is this correct? $TLSDOMAIN") ]]
then
    break
fi
done

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
check_command download_le_script test-new-config

# Install certbot (Let's Encrypt)
install_certbot

#Fix issue #28
ssl_conf="/etc/apache2/sites-available/"$TLSDOMAIN.conf""

# Check if "$ssl.conf" exists, and if, then delete
if [ -f "$ssl_conf" ]
then
    rm -f "$ssl_conf"
fi

# Generate nextcloud_ssl_domain.conf
if [ ! -f "$ssl_conf" ]
then
    touch "$ssl_conf"
    print_text_in_color "$IGreen" "$ssl_conf was successfully created."
    sleep 2
    cat << SSL_CREATE > "$ssl_conf"
<VirtualHost *:80>
    RewriteEngine On
    RewriteRule ^(.*)$ https://%{HTTP_HOST}$1 [R=301,L]
</VirtualHost>

<VirtualHost *:443>

    Header add Strict-Transport-Security: "max-age=15768000;includeSubdomains"
    SSLEngine on
    SSLCompression off
    SSLProtocol all -SSLv3 -TLSv1 -TLSv1.1
    SSLHonorCipherOrder on
    SSLCipherSuite ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384
    SSLSessionTickets off

### YOUR SERVER ADDRESS ###

    ServerAdmin admin@$TLSDOMAIN
    ServerName $TLSDOMAIN

### SETTINGS ###
    <FilesMatch "\.php$">
        SetHandler "proxy:unix:/run/php/php$PHPVER-fpm.nextcloud.sock|fcgi://localhost"
    </FilesMatch>

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
SSL_CREATE
fi

# Check if PHP-FPM is installed and if not, then remove PHP-FPM related lines from config
if [ ! -f "$PHP_POOL_DIR"/nextcloud.conf ]
then
    sed -i "s|<FilesMatch.*|# Removed due to that PHP-FPM is missing|g" "$ssl_conf"
    sed -i "s|SetHandler.*|#|g" "$ssl_conf"
    sed -i "s|</FilesMatch.*|#|g" "$ssl_conf"
elif ! is_this_installed php"$PHPVER"-fpm
then
    sed -i "s|<FilesMatch.*|# Removed due to that PHP-FPM is missing|g" "$1"
    sed -i "s|SetHandler.*|#|g" "$ssl_conf"
    sed -i "s|</FilesMatch.*|#|g" "$ssl_conf"
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
        exit 0
    fi
else
    last_fail_tls "$SCRIPTS"/activate-ssl.sh cleanup
fi

exit
