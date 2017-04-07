#!/bin/bash

# Tech and Me © - 2017, https://www.techandme.se/

# Prefer IPv4
sed -i "s|#precedence ::ffff:0:0/96  100|precedence ::ffff:0:0/96  100|g" /etc/gai.conf

# shellcheck disable=2034,2059
true
# shellcheck source=lib.sh
FIRST_IFACE=1 && CHECK_CURRENT_REPO=1 . <(curl -sL https://raw.githubusercontent.com/morph027/vm/master/lib.sh)
unset FIRST_IFACE
unset CHECK_CURRENT_REPO

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Check if root
if ! is_root
then
    printf "\n${Red}Sorry, you are not root.\n${Color_Off}You must type: ${Cyan}sudo ${Color_Off}bash %s/nextcloud_install_production.sh\n" "$SCRIPTS"
    exit 1
fi

# Show current user
echo
echo "Current user with sudo permissions is: $UNIXUSER".
echo "This script will set up everything with that user."
echo "If the field after ':' is blank you are probably running as a pure root user."
echo "It's possible to install with root, but there will be minor errors."
echo
echo "Please create a user with sudo permissions if you want an optimal installation."
wget -q "$STATIC"/adduser.sh
bash adduser.sh
rm -f adduser.sh

# Check Ubuntu version
echo "Checking server OS and version..."
if [ "$OS" != 1 ]
then
    echo "Ubuntu Server is required to run this script."
    echo "Please install that distro and try again."
    exit 1
fi


if ! version 16.04 "$DISTRO" 16.04.4; then
    echo "Ubuntu version $DISTRO must be between 16.04 - 16.04.4"
    exit
fi

# Check if key is available
if ! wget -q -T 10 -t 2 "$NCREPO" > /dev/null
then
    echo "Nextcloud repo is not available, exiting..."
    exit 1
fi

# Check if it's a clean server
echo "Checking if it's a clean server..."
if [ "$(dpkg-query -W -f='${Status}' mysql-common 2>/dev/null | grep -c "ok installed")" == "1" ]
then
    echo "MySQL is installed, it must be a clean server."
    exit 1
fi

if [ "$(dpkg-query -W -f='${Status}' apache2 2>/dev/null | grep -c "ok installed")" == "1" ]
then
    echo "Apache2 is installed, it must be a clean server."
    exit 1
fi

if [ "$(dpkg-query -W -f='${Status}' php 2>/dev/null | grep -c "ok installed")" == "1" ]
then
    echo "PHP is installed, it must be a clean server."
    exit 1
fi

# Create $SCRIPTS dir
if [ ! -d "$SCRIPTS" ]
then
    mkdir -p "$SCRIPTS"
fi

# Change DNS
if ! [ -x "$(command -v resolvconf)" ]
then
    apt install resolvconf -y -q
    dpkg-reconfigure resolvconf
fi

echo "nameserver 8.8.8.8" > /etc/resolvconf/resolv.conf.d/base
echo "nameserver 8.8.4.4" >> /etc/resolvconf/resolv.conf.d/base

# Check network
if ! [ -x "$(command -v nslookup)" ]
then
    apt install dnsutils -y -q
fi
if ! [ -x "$(command -v ifup)" ]
then
    apt install ifupdown -y -q
fi
sudo ifdown "$IFACE" && sudo ifup "$IFACE"
if ! nslookup google.com
then
    echo "Network NOT OK. You must have a working Network connection to run this script."
    exit 1
fi

# Set locales
apt install language-pack-en-base -y
sudo locale-gen "sv_SE.UTF-8" && sudo dpkg-reconfigure --frontend=noninteractive locales

# Check where the best mirrors are and update
echo
printf "Your current server repository is:  ${Cyan}%s${Color_Off}\n" "$REPO"
if [[ "no" == $(ask_yes_or_no "Do you want to try to find a better mirror?") ]]
then
    echo "Keeping $REPO as mirror..."
    sleep 1
else
   echo "Locating the best mirrors..."
   apt update -q4 & spinner_loading
   apt install python-pip -y
   pip install \
       --upgrade pip \
       apt-select
    apt-select -m up-to-date -t 5 -c
    sudo cp /etc/apt/sources.list /etc/apt/sources.list.backup && \
    if [ -f sources.list ]
    then
        sudo mv sources.list /etc/apt/
    fi
fi
clear

# Set keyboard layout
echo "Current keyboard layout is $(localectl status | grep "Layout" | awk '{print $3}')"
if [[ "no" == $(ask_yes_or_no "Do you want to change keyboard layout?") ]]
then
    echo "Not changing keyboard layout..."
    sleep 1
    clear
else
    dpkg-reconfigure keyboard-configuration
    clear
fi

# Update system
apt update -q4 & spinner_loading

# Write MySQL pass to file and keep it safe
echo "$MYSQL_PASS" > $PW_FILE
chmod 600 $PW_FILE
chown root:root $PW_FILE

# Install MYSQL 5.7
apt install software-properties-common -y
echo "mysql-server-5.7 mysql-server/root_password password $MYSQL_PASS" | debconf-set-selections
echo "mysql-server-5.7 mysql-server/root_password_again password $MYSQL_PASS" | debconf-set-selections
check_command apt install mysql-server-5.7 -y

# mysql_secure_installation
apt -y install expect
SECURE_MYSQL=$(expect -c "
set timeout 10
spawn mysql_secure_installation
expect \"Enter current password for root:\"
send \"$MYSQL_PASS\r\"
expect \"Would you like to setup VALIDATE PASSWORD plugin?\"
send \"n\r\"
expect \"Change the password for root ?\"
send \"n\r\"
expect \"Remove anonymous users?\"
send \"y\r\"
expect \"Disallow root login remotely?\"
send \"y\r\"
expect \"Remove test database and access to it?\"
send \"y\r\"
expect \"Reload privilege tables now?\"
send \"y\r\"
expect eof
")
echo "$SECURE_MYSQL"
apt -y purge expect

# Install Apache
check_command apt install apache2 -y
a2enmod rewrite \
        headers \
        env \
        dir \
        mime \
        ssl \
        setenvif

# Install PHP 7.0
apt update -q4 & spinner_loading
check_command apt install -y \
    libapache2-mod-php7.0 \
    php7.0-common \
    php7.0-mysql \
    php7.0-intl \
    php7.0-mcrypt \
    php7.0-ldap \
    php7.0-imap \
    php7.0-cli \
    php7.0-gd \
    php7.0-pgsql \
    php7.0-json \
    php7.0-sqlite3 \
    php7.0-curl \
    php7.0-xml \
    php7.0-zip \
    php7.0-mbstring \
    php-smbclient

# Enable SMB client
# echo '# This enables php-smbclient' >> /etc/php/7.0/apache2/php.ini
# echo 'extension="smbclient.so"' >> /etc/php/7.0/apache2/php.ini

# Install Unzip
apt install unzip -y

# Install VM-tools
apt install open-vm-tools -y

# Download and validate Nextcloud package
wget -q "$NCREPO/$STABLEVERSION.zip" -P "$HTML"
mkdir -p "$GPGDIR"
wget -q "$NCREPO/$STABLEVERSION.zip.asc" -P "$GPGDIR"
chmod -R 600 "$GPGDIR"
gpg --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys "$OpenPGP_fingerprint"
check_command gpg --verify "$GPGDIR/$STABLEVERSION.zip.asc" "$HTML/$STABLEVERSION.zip"

# Cleanup
rm -r $GPGDIR

# Extract package
unzip -q "$HTML/$STABLEVERSION.zip" -d "$HTML"
rm "$HTML/$STABLEVERSION.zip"

# Secure permissions
download_static_script setup_secure_permissions_nextcloud
bash $SECURE & spinner_loading

# Install Nextcloud
cd "$NCPATH"
check_command sudo -u www-data php occ maintenance:install \
    --data-dir "$NCDATA" \
    --database "mysql" \
    --database-name "nextcloud_db" \
    --database-user "root" \
    --database-pass "$MYSQL_PASS" \
    --admin-user "$NCUSER" \
    --admin-pass "$NCPASS"
echo
echo "Nextcloud version:"
sudo -u www-data php "$NCPATH"/occ status
sleep 3
echo

# Prepare cron.php to be run every 15 minutes
check_command crontab -u www-data -l | { cat; echo "*/15  *  *  *  * php -f $NCPATH/cron.php > /dev/null 2>&1"; } | crontab -u www-data -

# Change values in php.ini (increase max file size)
# max_execution_time
sed -i "s|max_execution_time = 30|max_execution_time = 3500|g" /etc/php/7.0/apache2/php.ini
# max_input_time
sed -i "s|max_input_time = 60|max_input_time = 3600|g" /etc/php/7.0/apache2/php.ini
# memory_limit
sed -i "s|memory_limit = 128M|memory_limit = 512M|g" /etc/php/7.0/apache2/php.ini
# post_max
sed -i "s|post_max_size = 8M|post_max_size = 1100M|g" /etc/php/7.0/apache2/php.ini
# upload_max
sed -i "s|upload_max_filesize = 2M|upload_max_filesize = 1000M|g" /etc/php/7.0/apache2/php.ini

# Increase max filesize (expects that changes are made in /etc/php/7.0/apache2/php.ini)
# Here is a guide: https://www.techandme.se/increase-max-file-size/
VALUE="# php_value upload_max_filesize 511M"
if ! grep -Fxq "$VALUE" "$NCPATH"/.htaccess
then
        sed -i 's/  php_value upload_max_filesize 511M/# php_value upload_max_filesize 511M/g' "$NCPATH"/.htaccess
        sed -i 's/  php_value post_max_size 511M/# php_value post_max_size 511M/g' "$NCPATH"/.htaccess
        sed -i 's/  php_value memory_limit 512M/# php_value memory_limit 512M/g' "$NCPATH"/.htaccess
fi

# Install Figlet
apt install figlet -y

# Generate $HTTP_CONF
if [ ! -f $HTTP_CONF ]
then
    touch "$HTTP_CONF"
    cat << HTTP_CREATE > "$HTTP_CONF"
<VirtualHost *:80>

### YOUR SERVER ADDRESS ###
#    ServerAdmin admin@example.com
#    ServerName example.com
#    ServerAlias subdomain.example.com

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

    <Directory "$NCDATA">
    # just in case if .htaccess gets disabled
    Require all denied
    </Directory>

    SetEnv HOME $NCPATH
    SetEnv HTTP_HOME $NCPATH

</VirtualHost>
HTTP_CREATE
    echo "$HTTP_CONF was successfully created"
fi

# Generate $SSL_CONF
if [ ! -f $SSL_CONF ]
then
    touch "$SSL_CONF"
    cat << SSL_CREATE > "$SSL_CONF"
<VirtualHost *:443>
    Header add Strict-Transport-Security: "max-age=15768000;includeSubdomains"
    SSLEngine on

### YOUR SERVER ADDRESS ###
#    ServerAdmin admin@example.com
#    ServerName example.com
#    ServerAlias subdomain.example.com

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

    <Directory "$NCDATA">
    # just in case if .htaccess gets disabled
    Require all denied
    </Directory>

    SetEnv HOME $NCPATH
    SetEnv HTTP_HOME $NCPATH

### LOCATION OF CERT FILES ###
    SSLCertificateFile /etc/ssl/certs/ssl-cert-snakeoil.pem
    SSLCertificateKeyFile /etc/ssl/private/ssl-cert-snakeoil.key
</VirtualHost>
SSL_CREATE
    echo "$SSL_CONF was successfully created"
fi

# Enable new config
a2ensite nextcloud_ssl_domain_self_signed.conf
a2ensite nextcloud_http_domain_self_signed.conf
a2dissite default-ssl
service apache2 restart

## Set config values
# Experimental apps
sudo -u www-data php "$NCPATH"/occ config:system:set appstore.experimental.enabled --value="true"
# Default mail server as an example (make this user configurable?)
sudo -u www-data php "$NCPATH"/occ config:system:set mail_smtpmode --value="smtp"
sudo -u www-data php "$NCPATH"/occ config:system:set mail_smtpauth --value="1"
sudo -u www-data php "$NCPATH"/occ config:system:set mail_smtpport --value="465"
sudo -u www-data php "$NCPATH"/occ config:system:set mail_smtphost --value="smtp.gmail.com"
sudo -u www-data php "$NCPATH"/occ config:system:set mail_smtpauthtype --value="LOGIN"
sudo -u www-data php "$NCPATH"/occ config:system:set mail_from_address --value="www.techandme.se"
sudo -u www-data php "$NCPATH"/occ config:system:set mail_domain --value="gmail.com"
sudo -u www-data php "$NCPATH"/occ config:system:set mail_smtpsecure --value="ssl"
sudo -u www-data php "$NCPATH"/occ config:system:set mail_smtpname --value="www.techandme.se@gmail.com"
sudo -u www-data php "$NCPATH"/occ config:system:set mail_smtppassword --value="vinr vhpa jvbh hovy"

# Install Libreoffice Writer to be able to read MS documents.
sudo apt install --no-install-recommends libreoffice-writer -y
sudo -u www-data php "$NCPATH"/occ config:system:set preview_libreoffice_path --value="/usr/bin/libreoffice"

whiptail --title "Which apps/programs do you want to install?" --checklist --separate-output "" 10 40 3 \
"Calendar" "              " on \
"Contacts" "              " on \
"Webmin" "              " on 2>results

while read -r -u 9 choice
do
    case "$choice" in
        Calendar)
            run_app_script calendar
        ;;
        Contacts)
            run_app_script contacts
        ;;
        Webmin)
            run_app_script webmin
        ;;
        *)
        ;;
    esac
done 9< results
rm -f results

# Get needed scripts for first bootup
if [ ! -f "$SCRIPTS"/nextcloud-startup-script.sh ]
then
check_command wget -q "$GITHUB_REPO"/nextcloud-startup-script.sh -P "$SCRIPTS"
fi
download_static_script instruction
download_static_script history

# Make $SCRIPTS excutable
chmod +x -R "$SCRIPTS"
chown root:root -R "$SCRIPTS"

# Prepare first bootup
check_command run_static_script change-ncadmin-profile
check_command run_static_script change-root-profile

# Install Redis
run_static_script redis-server-ubuntu16

# Upgrade
apt update -q4 & spinner_loading
apt dist-upgrade -y

# Remove LXD (always shows up as failed during boot)
apt purge lxd -y

# Cleanup
CLEARBOOT=$(dpkg -l linux-* | awk '/^ii/{ print $2}' | grep -v -e ''"$(uname -r | cut -f1,2 -d"-")"'' | grep -e '[0-9]' | xargs sudo apt -y purge)
echo "$CLEARBOOT"
apt autoremove -y
apt autoclean
find /root "/home/$UNIXUSER" -type f \( -name '*.sh*' -o -name '*.html*' -o -name '*.tar*' -o -name '*.zip*' \) -delete

# Install virtual kernels
apt install linux-tools-virtual-hwe-16.04 linux-cloud-tools-virtual-hwe-16.04  -y
apt install linux-image-virtual-hwe-16.04 -y
apt install linux-virtual-hwe-16.04 -y

# Set secure permissions final (./data/.htaccess has wrong permissions otherwise)
bash $SECURE & spinner_loading

# Reboot
echo "Installation done, system will now reboot..."
reboot

exit 0
