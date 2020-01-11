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

echo
while true
do
# Ask for domain name
cat << ENTERDOMAIN
+---------------------------------------------------------------+
|    Please enter the domain name you will use for Nextcloud:   |
|    Like this: example.com, or nextcloud.example.com           |
+---------------------------------------------------------------+
ENTERDOMAIN
echo
read -r domain
echo
if [[ "yes" == $(ask_yes_or_no "Is this correct? $domain") ]]
then
    break
fi
done

# Check if $domain exists and is reachable
echo
print_text_in_color "$ICyan" "Checking if $domain exists and is reachable..."
domain_check_200 "$domain"

# Check if port is open with NMAP
sed -i "s|127.0.1.1.*|127.0.1.1       $domain nextcloud|g" /etc/hosts
network_ok
check_open_port 80 "$domain"
check_open_port 443 "$domain"

# Fetch latest version of test-new-config.sh
check_command download_le_script test-new-config

# Install certbot (Let's Encrypt)
install_certbot

#Fix issue #28
ssl_conf="/etc/apache2/sites-available/"$domain.conf""

# DHPARAM
DHPARAMS="$CERTFILES/$domain/dhparam.pem"

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

    ServerAdmin admin@$domain
    ServerName $domain

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

    SSLCertificateChainFile $CERTFILES/$domain/chain.pem
    SSLCertificateFile $CERTFILES/$domain/cert.pem
    SSLCertificateKeyFile $CERTFILES/$domain/privkey.pem
    SSLOpenSSLConfCmd DHParameters $DHPARAMS

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

# Methods
# https://certbot.eff.org/docs/using.html#certbot-command-line-options
default_le="--rsa-key-size 4096 --renew-by-default --no-eff-email --agree-tos --uir --hsts --server https://acme-v02.api.letsencrypt.org/directory -d $domain"

standalone() {
# Generate certs
if eval "certbot certonly --standalone --pre-hook 'service apache2 stop' --post-hook 'service apache2 start' $default_le"
then
    echo "success" > /tmp/le_test
else
    echo "fail" > /tmp/le_test
fi
}
tls-alpn-01() {
if eval "certbot certonly --preferred-challenges tls-alpn-01 $default_le"
then
    echo "success" > /tmp/le_test
else
    echo "fail" > /tmp/le_test
fi
}
dns() {
if eval "certbot certonly --manual --manual-public-ip-logging-ok --preferred-challenges dns $default_le"
then
    echo "success" > /tmp/le_test
else
    echo "fail" > /tmp/le_test
fi
}

methods=(standalone dns)

create_config() {
# $1 = method
local method="$1"
# Check if $CERTFILES exists
if [ -d "$CERTFILES" ]
 then
    # Generate DHparams chifer
    if [ ! -f "$DHPARAMS" ]
    then
        openssl dhparam -dsaparam -out "$DHPARAMS" 4096
    fi
    # Activate new config
    check_command bash "$SCRIPTS/test-new-config.sh" "$domain.conf"
    exit
fi
}

attempts_left() {
local method="$1"
if [ "$method" == "standalone" ]
then
    printf "%b" "${ICyan}It seems like no certs were generated, we will do 1 more try.\n${Color_Off}"
    any_key "Press any key to continue..."
#elif [ "$method" == "tls-alpn-01" ]
#then
#    printf "%b" "${ICyan}It seems like no certs were generated, we will do 1 more try.\n${Color_Off}"
#    any_key "Press any key to continue..."
elif [ "$method" == "dns" ]
then
    printf "%b" "${IRed}It seems like no certs were generated, please check your DNS and try again.\n${Color_Off}"
    any_key "Press any key to continue..."
fi
}

# Generate the cert
for f in "${methods[@]}"; do "$f"
if [ "$(grep 'success' /tmp/le_test)" == 'success' ]; then
    rm -f /tmp/le_test
    create_config "$f"
else
    rm -f /tmp/le_test
    attempts_left "$f"
fi
done

# Failed
msg_box "Sorry, last try failed as well. :/

The script is located in $SCRIPTS/activate-ssl.sh
Please try to run it again some other time with other settings.

There are different configs you can try in Let's Encrypt's user guide:
https://letsencrypt.readthedocs.org/en/latest/index.html
Please check the guide for further information on how to enable SSL.

This script is developed on GitHub, feel free to contribute:
https://github.com/nextcloud/vm

The script will now do some cleanup and revert the settings."

# Cleanup
apt remove certbot -y
apt autoremove -y
clear
