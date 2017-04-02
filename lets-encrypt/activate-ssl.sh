#!/bin/bash

# Tech and Me ©2017 - www.techandme.se

NCPATH=/var/www/nextcloud
WANIP4=$(dig +short myip.opendns.com @resolver1.opendns.com)
ADDRESS=$(hostname -I | cut -d ' ' -f 1)
certfiles=/etc/letsencrypt/live
SCRIPTS=/var/scripts

# Check if root
if [[ "$EUID" -ne 0 ]]
then
    echo
    printf "\e[31mSorry, you are not root.\n\e[0mYou need to type: \e[36msudo \e[0mbash %s/activate-ssl.sh" "$SCRIPTS"
    echo
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
|       IP address: "$ADDRESS" - do this in your router.      |
|       Here is a guide: https://goo.gl/Uyuf65                  |
|                                                               |
|       This script is located in "$SCRIPTS" and you          |
|       can run this script after you got a domain.             |
|                                                               |
|       Please don't run this script if you don't have          |
|       a domain yet. You can get one for a fair price here:    |
|       https://www.citysites.eu/                               |
|                                                               |
+---------------------------------------------------------------+

STARTMSG

ask_yes_or_no() {
    read -p "$1 ([y]es or [N]o): "
    case ${REPLY,,} in
    y|yes) echo "yes" ;;
    *)     echo "no" ;;
esac
}

if [[ "no" == $(ask_yes_or_no "Are you sure you want to continue?") ]]
then
    echo
    echo "OK, but if you want to run this script later, just type: sudo bash $SCRIPTS/activate-ssl.sh"
    read -p $'\n\e\[32mPress any key to continue...\e[0m\n' -n1 -s
exit
fi

if [[ "no" == $(ask_yes_or_no "Have you forwarded port 443 in your router?") ]]
then
    echo
    echo "OK, but if you want to run this script later, just type: sudo bash /var/scripts/activate-ssl.sh"
    echo -e "\e[32m"
    read -p "Press any key to continue... " -n1 -s
    echo -e "\e[0m"
    exit
fi

if [[ "yes" == $(ask_yes_or_no "Do you have a domain that you will use?") ]]
then
    sleep 1
else
    echo
    echo "OK, but if you want to run this script later, just type: sudo bash /var/scripts/activate-ssl.sh"
    echo -e "\e[32m"
    read -p "Press any key to continue... " -n1 -s
    echo -e "\e[0m"
    exit
fi

echo
# Ask for domain name
cat << ENTERDOMAIN
+---------------------------------------------------------------+
|    Please enter the domain name you will use for Nextcloud:   |
|    Like this: example.com, or nextcloud.example.com (1/2)     |
+---------------------------------------------------------------+
ENTERDOMAIN
echo
read domain

echo
if [[ "no" == $(ask_yes_or_no "Is this correct? $domain") ]]
    then
    echo
    echo
    cat << ENTERDOMAIN2
+---------------------------------------------------------------+
|    OK, try again. (2/2)                                       |
|    Please enter the domain name you will use for Nextcloud:   |
|    Like this: example.com, or nextcloud.example.com           |
|    It's important that it's correct, because the script is    |
|    based on what you enter.                                   |
+---------------------------------------------------------------+
ENTERDOMAIN2

    echo
    read domain
    echo
fi

# Check if 443 is open using nmap, if not notify the user
echo "Running apt update..."
apt update -q2
if [ "$(dpkg-query -W -f='${Status}' nmap 2>/dev/null | grep -c "ok installed")" == "1" ]
then
    echo "nmap is already installed..."
    clear
else
    apt install nmap -y
fi

if [ "$(nmap -sS -p 443 "$WANIP4" -PN | grep -c "open")" == "1" ]
then
    apt remove --purge nmap -y
else
    echo "Port 443 is not open on $WANIP4. We will do a second try on $domain instead."
    read -p "Press any key to test $domain... " -n1 -s
    if [[ $(nmap -sS -PN -p 443 "$domain" | grep -m 1 "open" | awk '{print $2}') = open ]]
    then
        apt remove --purge nmap -y
    else
        echo "Port 443 is not open on $domain. Please follow this guide to open ports in your router: https://www.techandme.se/open-port-80-443/"
        read -p "Press any key to exit... " -n1 -s
        apt remove --purge nmap -y
        exit 1
    fi
fi

# Fetch latest version of test-new-config.sh
if [ -f $SCRIPTS/test-new-config.sh ]
then
    rm $SCRIPTS/test-new-config.sh
    wget -q https://raw.githubusercontent.com/nextcloud/vm/master/lets-encrypt/test-new-config.sh -P $SCRIPTS
    chmod +x $SCRIPTS/test-new-config.sh
else
    wget -q https://raw.githubusercontent.com/nextcloud/vm/master/lets-encrypt/test-new-config.sh -P $SCRIPTS
    chmod +x $SCRIPTS/test-new-config.sh
fi

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
    read -p $'\n\e\[32mPress any key to continue...\e[0m\n' -n1 -s
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
    apt update -q2
    apt install letsencrypt -y -q
    apt update -q2
    apt dist-upgrade -y
fi

#Fix issue #28
ssl_conf="/etc/apache2/sites-available/"$domain.conf""

# DHPARAM
DHPARAMS="$certfiles/$domain/dhparam.pem"

# Check if "$ssl.conf" exists, and if, then delete
if [ -f "$ssl_conf" ]
then
    rm "$ssl_conf"
fi

# Generate nextcloud_ssl_domain.conf
if [ -f "$ssl_conf" ]
then
    echo "Virtual Host exists"
else
    touch "$ssl_conf"
    echo "$ssl_conf was successfully created"
    sleep 3
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

    SSLCertificateChainFile $certfiles/$domain/chain.pem
    SSLCertificateFile $certfiles/$domain/cert.pem
    SSLCertificateKeyFile $certfiles/$domain/privkey.pem
    SSLOpenSSLConfCmd DHParameters $DHPARAMS

</VirtualHost>
SSL_CREATE
fi

# Generate DHparams chifer
if [ ! -f $DHPARAMS ]
then
    openssl dhparam -out $DHPARAMS 4096
fi

##### START FIRST TRY

# Stop Apache to aviod port conflicts
a2dissite 000-default.conf
sudo service apache2 stop
# Generate certs
letsencrypt certonly \
--standalone \
--rsa-key-size 4096 \
--renew-by-default \
--agree-tos \
-d "$domain"

# Activate Apache again (Disabled during standalone)
service apache2 start
a2ensite 000-default.conf
service apache2 reload
# Check if $certfiles exists
if [ -d "$certfiles" ]
then
    # Activate new config
    bash $SCRIPTS/test-new-config.sh "$domain.conf"
    exit 0
else
    printf "\e[96m"
    printf "It seems like no certs were generated, we do three more tries."
    read -p $'\n\e\[32mPress any key to continue...\e[0m\n' -n1 -s
fi
##### START SECOND TRY
# Generate certs
letsencrypt \
--rsa-key-size 4096 \
--renew-by-default \
--agree-tos \
-d "$domain"
# Check if $certfiles exists
if [ -d "$certfiles" ]
then
    # Activate new config
    bash $SCRIPTS/test-new-config.sh "$domain.conf"
    exit 0
else
    printf "\e[96m"
    printf "It seems like no certs were generated, we do two more tries."
    read -p $'\n\e\[32mPress any key to continue...\e[0m\n' -n1 -s
fi
##### START THIRD TRY
letsencrypt certonly \
--webroot --w "$NCPATH" \
--rsa-key-size 4096 \
--renew-by-default \
--agree-tos \
-d "$domain"

# Check if $certfiles exists
if [ -d "$certfiles" ]
then
    # Activate new config
    bash $SCRIPTS/test-new-config.sh "$domain.conf"
    exit 0
else
    printf "\e[96m"
    printf "It seems like no certs were generated, we do one more try."
    read -p $'\n\e\[32mPress any key to continue...\e[0m\n' -n1 -s
fi
#### START FORTH TRY
# Generate certs
letsencrypt \
--apache
--rsa-key-size 4096 \
--renew-by-default \
--agree-tos \
-d "$domain"

# Check if $certfiles exists
if [ -d "$certfiles" ]
then
# Activate new config
    bash $SCRIPTS/test-new-config.sh "$domain.conf"
    exit 0
else
    printf "\e[96m"
    printf "Sorry, last try failed as well. :/ "
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
    read -p "Press any key to revert settings and exit... " -n1 -s

    # Cleanup
    apt remove letsencrypt -y
    apt autoremove -y
fi
clear
