#!/bin/bash

# Tech and Me © - 2018, https://www.techandme.se/

# Prefer IPv4
sed -i "s|#precedence ::ffff:0:0/96  100|precedence ::ffff:0:0/96  100|g" /etc/gai.conf

# shellcheck disable=2034,2059
true
# shellcheck source=lib.sh
. <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/php-fpm/lib.sh)

# Check if dpkg or apt is running
is_process_running apt
is_process_running dpkg

# Install curl if not existing
if [ "$(dpkg-query -W -f='${Status}' "curl" 2>/dev/null | grep -c "ok installed")" == "1" ]
then
    echo "curl OK"
else
    apt update -q4 & spinner_loading
    apt install curl -y
fi

# Install lshw if not existing
if [ "$(dpkg-query -W -f='${Status}' "lshw" 2>/dev/null | grep -c "ok installed")" == "1" ]
then
    echo "lshw OK"
else
    apt update -q4 & spinner_loading
    apt install lshw -y
fi

# Install net-tools if not existing
if [ "$(dpkg-query -W -f='${Status}' "net-tools" 2>/dev/null | grep -c "ok installed")" == "1" ]
then
    echo "net-tools OK"
else
    apt update -q4 & spinner_loading
    apt install net-tools -y
fi

# shellcheck disable=2034,2059
true
# shellcheck source=lib.sh
FIRST_IFACE=1 && CHECK_CURRENT_REPO=1 . <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/php-fpm/lib.sh)
unset FIRST_IFACE
unset CHECK_CURRENT_REPO

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Check if root
root_check

# Set locales
install_if_not language-pack-en-base
sudo locale-gen "sv_SE.UTF-8" && sudo dpkg-reconfigure --frontend=noninteractive locales

# Test RAM size (2GB min) + CPUs (min 1)
ram_check 2 Nextcloud
cpu_check 1 Nextcloud

# Create new current user
download_static_script adduser
bash $SCRIPTS/adduser.sh "nextcloud_install_production.sh"
rm $SCRIPTS/adduser.sh

# Check distrobution and version
check_distro_version

# Check if key is available
if ! wget -q -T 10 -t 2 "$NCREPO" > /dev/null
then
msg_box "Nextcloud repo is not available, exiting..."
    exit 1
fi

# Check if it's a clean server
is_this_installed postgresql
is_this_installed apache2
is_this_installed php
is_this_installed php-fpm
is_this_installed php7.2-fpm
is_this_installed php7.1-fpm
is_this_installed php7.0-fpm
is_this_installed mysql-common
is_this_installed mariadb-server

# Create $SCRIPTS dir
if [ ! -d "$SCRIPTS" ]
then
    mkdir -p "$SCRIPTS"
fi

# Install needed network
install_if_not netplan.io
install_if_not network-manager

# Check network
network_ok

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

# Install PostgreSQL
# sudo add-apt-repository "deb http://apt.postgresql.org/pub/repos/apt/ bionic-pgdg main"
# wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
apt update -q4 & spinner_loading
apt install postgresql-10 -y

# Create DB
cd /tmp
sudo -u postgres psql <<END
CREATE USER $NCUSER WITH PASSWORD '$PGDB_PASS';
CREATE DATABASE nextcloud_db WITH OWNER $NCUSER TEMPLATE template0 ENCODING 'UTF8';
END
service postgresql restart

# Install Apache
check_command apt install apache2 -y 
a2enmod rewrite \
        headers \
        env \
        dir \
        mime \
        ssl \
        setenvif \
        proxy_fcgi
        
# Install PHP 7.2
apt update -q4 & spinner_loading
check_command apt install -y \
    php7.2-fpm \
    php7.2-intl \
    php7.2-ldap \
    php7.2-imap \
    php7.2-gd \
    php7.2-pgsql \
    php7.2-curl \
    php7.2-xml \
    php7.2-zip \
    php7.2-mbstring \
    php7.2-soap \
    php7.2-smbclient \
    php7.2-imagick \
    php7.2-json \
    php7.2-gmp \
    php7.2-bz2 \
    php-pear \
    libmagickcore-6.q16-3-extra
    
# Set up a php-fpm pool with a unixsocket
cat << POOL_CONF > "$PHP_POOL_DIR/nextcloud.conf"
[NextCloud]
user = www-data
group = www-data
listen = /run/php/php7.2-fpm.nextcloud.sock
listen.owner = www-data
listen.group = www-data
pm = dynamic
pm.max_children = 40
pm.start_servers = 8
pm.min_spare_servers = 4
pm.max_spare_servers = 8
pm.max_requests = 500
env[HOSTNAME] = $(hostname -f)
env[PATH] = /usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/snap/bin
env[TMP] = /tmp
env[TMPDIR] = /tmp
env[TEMP] = /tmp
security.limit_extensions = .php
php_admin_value [cgi.fix_pathinfo] = 1
POOL_CONF

# Disable the idling example pool.
mv $PHP_POOL_DIR/www.conf $PHP_POOL_DIR/www.conf.backup
    
# Enable php-fpm
a2enconf php7.2-fpm

# Restart Webserver
restart_webserver
    
# Use TCP-socket (UNIX socket is faster, and TCP gives more overhead)
# sed -i "s|listen = /run/php/php7.2-fpm.sock|listen = 127.0.0.1:9000|g" $PHP_WWW_CONF

# Enable SMB client # already loaded with php-smbclient
# echo '# This enables php-smbclient' >> /etc/php/7.2/apache2/php.ini
# echo 'extension="smbclient.so"' >> /etc/php/7.2/apache2/php.ini

# Install VM-tools
install_if_not open-vm-tools

# Format /dev/sdb to host the ncdata
run_static_script format-sdb

# Download and validate Nextcloud package
check_command download_verify_nextcloud_stable

if [ ! -f "$HTML/$STABLEVERSION.tar.bz2" ]
then
msg_box "Aborting,something went wrong with the download of $STABLEVERSION.tar.bz2"
    exit 1
fi

# Extract package
tar -xjf "$HTML/$STABLEVERSION.tar.bz2" -C "$HTML" & spinner_loading
rm "$HTML/$STABLEVERSION.tar.bz2"

# Secure permissions
download_static_script setup_secure_permissions_nextcloud
bash $SECURE & spinner_loading

# Install Nextcloud
cd "$NCPATH"
occ_command maintenance:install \
--data-dir="$NCDATA" \
--database=pgsql \
--database-name=nextcloud_db \
--database-user="$NCUSER" \
--database-pass="$PGDB_PASS" \
--admin-user="$NCUSER" \
--admin-pass="$NCPASS"
echo
echo "Nextcloud version:"
occ_command status
sleep 3
echo

# Prepare cron.php to be run every 15 minutes
crontab -u www-data -l | { cat; echo "*/15  *  *  *  * php -f $NCPATH/cron.php > /dev/null 2>&1"; } | crontab -u www-data -

# Change values in php.ini (increase max file size)
# max_execution_time
sed -i "s|max_execution_time =.*|max_execution_time = 3500|g" $PHP_INI
# max_input_time
sed -i "s|max_input_time =.*|max_input_time = 3600|g" $PHP_INI
# memory_limit
sed -i "s|memory_limit =.*|memory_limit = 512M|g" $PHP_INI
# post_max
sed -i "s|post_max_size =.*|post_max_size = 1100M|g" $PHP_INI
# upload_max
sed -i "s|upload_max_filesize =.*|upload_max_filesize = 1000M|g" $PHP_INI

# Set max upload in Nextcloud .htaccess
configure_max_upload

# Set SMTP mail
occ_command config:system:set mail_smtpmode --value="smtp"

# Set logrotate
occ_command config:system:set log_rotate_size --value="10485760"

# Enable OPCache for PHP 
# https://docs.nextcloud.com/server/14/admin_manual/configuration_server/server_tuning.html#enable-php-opcache
phpenmod opcache
{
echo "# OPcache settings for Nextcloud"
echo "opcache.enable=1"
echo "opcache.enable_cli=1"
echo "opcache.interned_strings_buffer=8"
echo "opcache.max_accelerated_files=10000"
echo "opcache.memory_consumption=256"
echo "opcache.save_comments=1"
echo "opcache.revalidate_freq=1"
echo "opcache.validate_timestamps=1"
} >> $PHP_INI

# Install issuetemplate
install_and_enable_app issuetemplate

# Install CanIUpdate?
install_and_enable_app caniupdate

# Install Figlet
install_if_not figlet

# To be able to use snakeoil certs
install_if_not ssl-cert

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
    <FilesMatch \\.php$>
        SetHandler "proxy:unix:/run/php/php7.2-fpm.nextcloud.sock|fcgi://localhost"
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
    <FilesMatch \\.php$>
        SetHandler "proxy:unix:/run/php/php7.2-fpm.nextcloud.sock|fcgi://localhost"
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

# Enable HTTP/2 server wide, if user decides to
msg_box "Your official package repository does not provide an Apache2 package with HTTP/2 module included.
If you like to enable HTTP/2 nevertheless, we can upgrade your Apache2 from Ondrejs PPA:
https://launchpad.net/~ondrej/+archive/ubuntu/apache2

Enabling HTTP/2 can bring a performance advantage, but may also have some compatibility issues.
So please think twice before enabling it"

if [[ "yes" == $(ask_yes_or_no "Do you want to enable HTTP/2 system wide?") ]]
then
    # Adding PPA
    add-apt-repository ppa:ondrej/apache2 -y
    apt update -q4 & spinner_loading
    apt upgrade apache2 -y
    
    # Enable HTTP/2 module & protocol
    cat << HTTP2_ENABLE > "$HTTP2_CONF"
<IfModule http2_module>
    Protocols h2 h2c http/1.1
    H2Direct on
</IfModule>
HTTP2_ENABLE
    echo "$HTTP2_CONF was successfully created"
    a2enmod http2
fi

# Restart Apache2 to enable new config
restart_webserver

whiptail --title "Install apps or software" --checklist --separate-output "Automatically configure and install selected apps or software\nDeselect by pressing the spacebar" "$WT_HEIGHT" "$WT_WIDTH" 4 \
"Calendar" "              " on \
"Contacts" "              " on \
"Webmin" "              " on 2>results

while read -r -u 9 choice
do
    case "$choice" in
        Calendar)
            install_and_enable_app calendar
        ;;
        Contacts)
            install_and_enable_app contacts
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
run_static_script redis-server-ubuntu

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

# Install virtual kernels for Hyper-V, and extra for UTF8 kernel module + Collabora and OnlyOffice
# Kernel 4.15
apt install -y --install-recommends \
linux-virtual \
linux-tools-virtual \
linux-cloud-tools-virtual \
linux-image-virtual \
linux-image-extra-virtual

# Set secure permissions final (./data/.htaccess has wrong permissions otherwise)
bash $SECURE & spinner_loading

# Force MOTD to show correct number of updates
sudo /usr/lib/update-notifier/update-motd-updates-available --force

# Reboot
echo "Installation done, system will now reboot..."
reboot
