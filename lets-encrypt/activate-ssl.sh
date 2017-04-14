#!/bin/bash
# shellcheck disable=2034,2059
true
# shellcheck source=lib.sh
. <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)

# Tech and Me © - 2017, https://www.techandme.se/

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Check if root
if ! is_root
then
    printf "\n${Red}Sorry, you are not root.\n${Color_Off}You need to type: ${Cyan}sudo ${Color_Off}bash %s/activate-ssl.sh\n" "$SCRIPTS"
    exit 1
fi

clear

cat << STARTMSG
+---------------------------------------------------------------+
|       Important! Please read this!                            |
|                                                               |
|       This script will install SSL from Let's Encrypt.        |
|       It's free of charge, and very easy to use.              |
|                                                               |
|       Before we begin the installation you need to have       |
|       a domain that the SSL certs will be valid for.          |
|       If you don't have a domain yet, get one before          |
|       you run this script!                                    |
|                                                               |
|       You also have to open port 443 against this VMs         |
|       IP address: "$ADDRESS" - do this in your router.    |
|       Here is a guide: https://goo.gl/Uyuf65                  |
|                                                               |
|       This script is located in "$SCRIPTS" and you        |
|       can run this script after you got a domain.             |
|                                                               |
|       Please don't run this script if you don't have          |
|       a domain yet. You can get one for a fair price here:    |
|       https://www.citysites.eu/                               |
|                                                               |
+---------------------------------------------------------------+

STARTMSG

if [[ "no" == $(ask_yes_or_no "Are you sure you want to continue?") ]]
then
    echo
    echo "OK, but if you want to run this script later, just type: sudo bash $SCRIPTS/activate-ssl.sh"
    any_key "Press any key to continue..."
exit
fi

if [[ "no" == $(ask_yes_or_no "Have you forwarded port 443 in your router?") ]]
then
    echo
    echo "OK, but if you want to run this script later, just type: sudo bash /var/scripts/activate-ssl.sh"
    any_key "Press any key to continue..."
    exit
fi

if [[ "yes" == $(ask_yes_or_no "Do you have a domain that you will use?") ]]
then
    sleep 1
else
    echo
    echo "OK, but if you want to run this script later, just type: sudo bash /var/scripts/activate-ssl.sh"
    any_key "Press any key to continue..."
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

# Check if 443 is open using nmap, if not notify the user
apt update -q4 & spinner_loading
if [ "$(dpkg-query -W -f='${Status}' nmap 2>/dev/null | grep -c "ok installed")" == "1" ]
then
    echo "nmap is already installed..."
else
    apt install nmap -y
fi

if [ "$(nmap -sS -p 443 "$WANIP4" -PN | grep -c "open")" == "1" ]
then
    apt remove --purge nmap -y
else
    echo "Port 443 is not open on $WANIP4. We will do a second try on $domain instead."
    any_key "Press any key to test $domain... "
    if [[ $(nmap -sS -PN -p 443 "$domain" | grep -m 1 "open" | awk '{print $2}') = open ]]
    then
        apt remove --purge nmap -y
    else
        echo "Port 443 is not open on $domain. Please follow this guide to open ports in your router: https://www.techandme.se/open-port-80-443/"
        any_key "Press any key to exit..."
        apt remove --purge nmap -y
        exit 1
    fi
fi

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
    echo "Nope, it's not there. You have to create $domain and point"
    echo "it to this server before you can run this script."
    any_key "Press any key to continue..."
    exit 1
fi

# Install letsencrypt
letsencrypt --version 2> /dev/null
LE_IS_AVAILABLE=$?
if [ $LE_IS_AVAILABLE -eq 0 ]
then
    letsencrypt --version
else
    echo "Installing letsencrypt..."
    add-apt-repository ppa:certbot/certbot -y
    apt update -q4 & spinner_loading
    apt install letsencrypt -y -q
    apt update -q4 & spinner_loading
    apt dist-upgrade -y
fi

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
    SSLCipherSuite EECDH+AESGCM:EDH+AESGCM:AES256+EECDH:ECDHE-RSA-AES128-SHA:DHE-RSA-AES128-GCM-SHA256:AES256+EDH:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-SHA384:ECDHE-RSA-AES128-SHA256:ECDHE-RSA-AES256-SHA:DHE-RSA-AES256-SHA256:DHE-RSA-AES128-SHA256:DHE-RSA-AES256-SHA:DHE-RSA-AES128-SHA:ECDHE-RSA-DES-CBC3-SHA:EDH-RSA-DES-CBC3-SHA:AES256-GCM-SHA384:AES128-GCM-SHA256:AES256-SHA256:AES128-SHA256:AES256-SHA:AES128-SHA:DES-CBC3-SHA:HIGH:!aNULL:!eNULL:!EXPORT:!DES:!MD5:!PSK:!RC4

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
# Stop Apache to avoid port conflicts
a2dissite 000-default.conf
sudo service apache2 stop
# Generate certs
eval "letsencrypt certonly --standalone $default_le"
if [ "$?" -eq 0 ]; then
    echo "success" > /tmp/le_test
else
    echo "fail" > /tmp/le_test
fi
# Activate Apache again (Disabled during standalone)
service apache2 start
a2ensite 000-default.conf
service apache2 reload
}
webroot() {
eval "letsencrypt certonly --webroot --webroot-path $NCPATH $default_le"
if [ "$?" -eq 0 ]; then
    echo "success" > /tmp/le_test
else
    echo "fail" > /tmp/le_test
fi
}
certonly() {
eval "letsencrypt certonly $default_le"
if [ "$?" -eq 0 ]; then
    echo "success" > /tmp/le_test
else
    echo "fail" > /tmp/le_test
fi
}

methods=(standalone webroot certonly)

create_config() {
# $1 = method
local method="$1"
# Check if $CERTFILES exists
if [ -d "$CERTFILES" ]
 then
    # Generate DHparams chifer
    if [ ! -f "$DHPARAMS" ]
    then
        openssl dhparam -dsaparam -out "$DHPARAMS" 8192
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
elif [ "$method" == "certonly" ]
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

printf "${ICyan}Sorry, last try failed as well. :/${Color_Off}\n\n"
cat << ENDMSG
+------------------------------------------------------------------------+
| The script is located in $SCRIPTS/activate-ssl.sh                  |
| Please try to run it again some other time with other settings.        |
|                                                                        |
| There are different configs you can try in Let's Encrypt's user guide: |
| https://letsencrypt.readthedocs.org/en/latest/index.html               |
| Please check the guide for further information on how to enable SSL.   |
|                                                                        |
| This script is developed on GitHub, feel free to contribute:           |
| https://github.com/nextcloud/vm                                        |
|                                                                        |
| The script will now do some cleanup and revert the settings.           |
+------------------------------------------------------------------------+
ENDMSG
any_key "Press any key to revert settings and exit... "

# Cleanup
apt remove letsencrypt -y
apt autoremove -y
clear
