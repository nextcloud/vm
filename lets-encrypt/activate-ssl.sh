#!/bin/bash

# Tech and Me ©2017 - www.techandme.se

NCPATH=/var/www/nextcloud
ADDRESS=$(hostname -I | cut -d ' ' -f 1)
dir_before_letsencrypt=/etc
letsencryptpath=$dir_before_letsencrypt/letsencrypt
certfiles=$letsencryptpath/live
SCRIPTS=/var/scripts

# Check if root
if [ "$(whoami)" != "root" ]
then
    echo
    echo -e "\e[31mSorry, you are not root.\n\e[0mYou need to type: \e[36msudo \e[0mbash /var/scripts/activate-ssl.sh"
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
|       IP address: $ADDRESS - do this in your router.      |
|       Here is a guide: https://goo.gl/Uyuf65                  |
|                                                               |
|       This script is located in /var/scripts and you          |
|       can run this script after you got a domain.             |
|                                                               |
|       Please don't run this script if you don't have          |
|       a domain yet. You can get one for a fair price here:    |
|       https://www.citysites.eu/                               |
|                                                               |
+---------------------------------------------------------------+

STARTMSG

function ask_yes_or_no() {
    read -p "$1 ([y]es or [N]o): "
    case $(echo $REPLY | tr '[A-Z]' '[a-z]') in
    y|yes) echo "yes" ;;
    *)     echo "no" ;;
esac
}
if [[ "no" == $(ask_yes_or_no "Are you sure you want to continue?") ]]
then
    echo
    echo "OK, but if you want to run this script later, just type: sudo bash /var/scripts/activate-ssl.sh"
    echo -e "\e[32m"
    read -p "Press any key to continue... " -n1 -s
    echo -e "\e[0m"
exit
fi

function ask_yes_or_no() {
    read -p "$1 ([y]es or [N]o): "
    case $(echo $REPLY | tr '[A-Z]' '[a-z]') in
        y|yes) echo "yes" ;;
        *)     echo "no" ;;
    esac
}
if [[ "no" == $(ask_yes_or_no "Have you forwarded port 443 in your router?") ]]
then
    echo
    echo "OK, but if you want to run this script later, just type: sudo bash /var/scripts/activate-ssl.sh"
    echo -e "\e[32m"
    read -p "Press any key to continue... " -n1 -s
    echo -e "\e[0m"
    exit
fi

function ask_yes_or_no() {
    read -p "$1 ([y]es or [N]o): "
    case $(echo $REPLY | tr '[A-Z]' '[a-z]') in
        y|yes) echo "yes" ;;
        *)     echo "no" ;;
    esac
}
if [[ "yes" == $(ask_yes_or_no "Do you have a domian that you will use?") ]]
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

# Install git
    git --version 2>&1 >/dev/null
    GIT_IS_AVAILABLE=$?
if [ $GIT_IS_AVAILABLE -eq 0 ]
then
    sleep 1
else
    apt update -q2
    apt install git -y -q
fi

# Fetch latest version of test-new-config.sh
SCRIPTS=/var/scripts

if [ -f $SCRIPTS/test-new-config.sh ]
then
    rm $SCRIPTS/test-new-config.sh
    wget https://raw.githubusercontent.com/nextcloud/vm/master/lets-encrypt/test-new-config.sh -P $SCRIPTS
    chmod +x $SCRIPTS/test-new-config.sh
else
    wget https://raw.githubusercontent.com/nextcloud/vm/master/lets-encrypt/test-new-config.sh -P $SCRIPTS
    chmod +x $SCRIPTS/test-new-config.sh
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

function ask_yes_or_no() {
    read -p "$1 ([y]es or [N]o): "
    case $(echo $REPLY | tr '[A-Z]' '[a-z]') in
        y|yes) echo "yes" ;;
        *)     echo "no" ;;
    esac
}
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

#Fix issue #28
ssl_conf="/etc/apache2/sites-available/$domain.conf"

# Check if $ssl_conf exists, and if, then delete
if [ -f $ssl_conf ]
then
    rm $ssl_conf
fi

# Change ServerName in apache.conf
sed -i "s|ServerName nextcloud|ServerName $domain|g" /etc/apache2/apache2.conf
sudo hostnamectl set-hostname $domain
service apache2 restart

# Generate nextcloud_ssl_domain.conf
if [ -f $ssl_conf ]
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

    Alias /nextcloud "$NCPATH/"

    <IfModule mod_dav.c>
    Dav off
    </IfModule>

    SetEnv HOME $NCPATH
    SetEnv HTTP_HOME $NCPATH


### LOCATION OF CERT FILES ###

    SSLCertificateChainFile $certfiles/$domain/chain.pem
    SSLCertificateFile $certfiles/$domain/cert.pem
    SSLCertificateKeyFile $certfiles/$domain/privkey.pem

</VirtualHost>
SSL_CREATE
fi

##### START FIRST TRY

# Stop Apache to aviod port conflicts
a2dissite 000-default.conf
sudo service apache2 stop
# Check if $letsencryptpath exist, and if, then delete.
if [ -d "$letsencryptpath" ]
then
    rm -R $letsencryptpath
fi
# Generate certs
cd $dir_before_letsencrypt
git clone https://github.com/letsencrypt/letsencrypt
cd $letsencryptpath
./letsencrypt-auto certonly --standalone -d $domain
# Use for testing
#./letsencrypt-auto --apache --server https://acme-staging.api.letsencrypt.org/directory -d EXAMPLE.COM
# Activate Apache again (Disabled during standalone)
service apache2 start
a2ensite 000-default.conf
service apache2 reload
# Check if $certfiles exists
if [ -d "$certfiles" ]
then
    # Activate new config
    bash /var/scripts/test-new-config.sh $domain.conf
    exit 0
else
    echo -e "\e[96m"
    echo -e "It seems like no certs were generated, we do three more tries."
    echo -e "\e[32m"
    read -p "Press any key to continue... " -n1 -s
    echo -e "\e[0m"
fi
##### START SECOND TRY

# Check if $letsencryptpath exist, and if, then delete.
if [ -d "$letsencryptpath" ]
then
    rm -R $letsencryptpath
fi
# Generate certs
cd $dir_before_letsencrypt
git clone https://github.com/letsencrypt/letsencrypt
cd $letsencryptpath
./letsencrypt-auto -d $domain
# Check if $certfiles exists
if [ -d "$certfiles" ]
then
    # Activate new config
    bash /var/scripts/test-new-config.sh $domain.conf
    exit 0
else
    echo -e "\e[96m"
    echo -e "It seems like no certs were generated, we do two more tries."
    echo -e "\e[32m"
    read -p "Press any key to continue... " -n1 -s
    echo -e "\e[0m"
fi
##### START THIRD TRY

# Check if $letsencryptpath exist, and if, then delete.
if [ -d "$letsencryptpath" ]
then
    rm -R $letsencryptpath
fi
# Generate certs
cd $dir_before_letsencrypt
git clone https://github.com/letsencrypt/letsencrypt
cd $letsencryptpath
./letsencrypt-auto certonly --agree-tos --webroot -w $NCPATH -d $domain
# Check if $certfiles exists
if [ -d "$certfiles" ]
then
    # Activate new config
    bash /var/scripts/test-new-config.sh $domain.conf
    exit 0
else
    echo -e "\e[96m"
    echo -e "It seems like no certs were generated, we do one more try."
    echo -e "\e[32m"
    read -p "Press any key to continue... " -n1 -s
    echo -e "\e[0m"
fi
#### START FORTH TRY

# Check if $letsencryptpath exist, and if, then delete.
if [ -d "$letsencryptpath" ]
then
    rm -R $letsencryptpath
fi
# Generate certs
cd $dir_before_letsencrypt
git clone https://github.com/letsencrypt/letsencrypt
cd $letsencryptpath
./letsencrypt-auto --agree-tos --apache -d $domain
# Check if $certfiles exists
if [ -d "$certfiles" ]
then
# Activate new config
    bash /var/scripts/test-new-config.sh $domain.conf
    exit 0
else
    echo -e "\e[96m"
    echo -e "Sorry, last try failed as well. :/ "
    echo -e "\e[0m"
    cat << ENDMSG
+------------------------------------------------------------------------+
| The script is located in /var/scripts/activate-ssl.sh                  |
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
    echo -e "\e[32m"
    read -p "Press any key to revert settings and exit... " -n1 -s
    echo -e "\e[0m"

# Cleanup
    rm -R $letsencryptpath
    rm $SCRIPTS/test-new-config.sh
    rm $ssl_conf
    rm -R /root/.local/share/letsencrypt
# Change ServerName in apache.conf and hostname
    sed -i "s|ServerName $domain|ServerName nextcloud|g" /etc/apache2/apache2.conf
    sudo hostnamectl set-hostname nextcloud
    service apache2 restart
fi
clear
