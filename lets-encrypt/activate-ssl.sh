#!/bin/bash
# shellcheck disable=2034,2059
true
# shellcheck source=lib.sh
. <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)

# Tech and Me © - 2018, https://www.techandme.se/

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

This script is located in $SCRIPTS and you
can run this script after you got a domain.

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

# Check if port is open with NMAP
sed -i "s|127.0.1.1.*|127.0.1.1       $domain nextcloud|g" /etc/hosts
network_ok
check_open_port 80 "$domain"
check_open_port 443 "$domain"

# Fetch latest version of test-new-config.sh
check_command download_le_script test-new-config

# Check if $domain exists and is reachable
echo
echo "Checking if $domain exists and is reachable..."
if wget -q -T 10 -t 2 --spider "$domain"; then
    sleep 1
elif wget -q -T 10 -t 2 --spider --no-check-certificate "https://$domain"; then
    sleep 1
elif curl -s -k -m 10 "$domain"; then
    sleep 1
elif curl -s -k -m 10 "https://$domain" -o /dev/null ; then
    sleep 1
else
msg_box "Nope, it's not there. You have to create $domain and point
it to this server before you can run this script."
    exit 1
fi

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
    echo "$ssl_conf was successfully created"
    sleep 2
    cat << SSL_CREATE > "$ssl_conf"
<VirtualHost *:80>
    ServerName $domain
    Redirect / https://$domain
</VirtualHost>

<VirtualHost *:443>

    Header add Strict-Transport-Security: "max-age=15768000;includeSubdomains"
    SSLEngine on
    SSLCompression off
    SSLProtocol all -SSLv2 -SSLv3
    SSLCipherSuite ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-SHA384:ECDHE-RSA-AES128-SHA256:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES128-SHA256:ECDHE-ECDSA-AES128-SHA:ECDHE-RSA-AES128-SHA:ECDHE-ECDSA-AES256-SHA384:ECDHE-ECDSA-AES256-SHA:ECDHE-RSA-AES256-SHA:DHE-RSA-AES128-SHA256:DHE-RSA-AES128-SHA:DHE-RSA-AES256-SHA256:DHE-RSA-AES256-SHA:ECDHE-ECDSA-DES-CBC3-SHA:ECDHE-RSA-DES-CBC3-SHA:EDH-RSA-DES-CBC3-SHA:AES128-GCM-SHA256:AES256-GCM-SHA384:AES128-SHA256:AES256-SHA256:AES128-SHA:AES256-SHA:DES-CBC3-SHA:!DSS
    SSLHonorCipherOrder on
    
### YOUR SERVER ADDRESS ###

    ServerAdmin admin@$domain
    ServerName $domain

### SETTINGS ###

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


### LOCATION OF CERT FILES ###

    SSLCertificateChainFile $CERTFILES/$domain/chain.pem
    SSLCertificateFile $CERTFILES/$domain/cert.pem
    SSLCertificateKeyFile $CERTFILES/$domain/privkey.pem
    SSLOpenSSLConfCmd DHParameters $DHPARAMS

</VirtualHost>
SSL_CREATE
fi

# Methods
default_le="--rsa-key-size 4096 --renew-by-default --agree-tos -d $domain"

standalone() {
# Generate certs
if eval "certbot certonly --standalone --pre-hook 'service apache2 stop' --post-hook 'service apache2 start' $default_le"
then
    echo "success" > /tmp/le_test
else
    echo "fail" > /tmp/le_test
fi
}
webroot() {
if eval "certbot certonly --webroot --webroot-path $NCPATH $default_le"
then
    echo "success" > /tmp/le_test
else
    echo "fail" > /tmp/le_test
fi
}
dns() {
if eval "certbot --manual --manual-public-ip-logging-ok --preferred-challenges dns certonly $default_le"
then
    echo "success" > /tmp/le_test
else
    echo "fail" > /tmp/le_test
fi
}

methods=(standalone webroot dns)

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
    printf "${ICyan}It seems like no certs were generated, we will do 2 more tries.${Color_Off}\n"
    any_key "Press any key to continue..."
elif [ "$method" == "webroot" ]
then
    printf "${ICyan}It seems like no certs were generated, we will do 1 more try.${Color_Off}\n"
    any_key "Press any key to continue..."
elif [ "$method" == "dns" ]
then
    printf "${ICyan}It seems like no certs were generated, we will do 0 more tries.${Color_Off}\n"
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
apt remove letsencrypt -y
apt autoremove -y
clear
