#!/bin/bash

# T&M Hansson IT AB © - 2021, https://www.hanssonit.se/

# Prefer IPv4
sed -i "s|#precedence ::ffff:0:0/96  100|precedence ::ffff:0:0/96  100|g" /etc/gai.conf

# Install curl if not existing
if [ "$(dpkg-query -W -f='${Status}' "curl" 2>/dev/null | grep -c "ok installed")" == "1" ]
then
    echo "curl OK"
else
    apt update -q4
    apt install curl -y
fi

# shellcheck disable=2034,2059
true
SCRIPT_NAME="Nextcloud Install Script"
# shellcheck source=lib.sh
source <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/official-basic-vm/lib.sh)

# Check if dpkg or apt is running
is_process_running apt
is_process_running dpkg

# Install lshw if not existing
if [ "$(dpkg-query -W -f='${Status}' "lshw" 2>/dev/null | grep -c "ok installed")" == "1" ]
then
    print_text_in_color "$IGreen" "lshw OK"
else
    apt update -q4 & spinner_loading
    apt install lshw -y
fi

# Install net-tools if not existing
if [ "$(dpkg-query -W -f='${Status}' "net-tools" 2>/dev/null | grep -c "ok installed")" == "1" ]
then
    print_text_in_color "$IGreen" "net-tools OK"
else
    apt update -q4 & spinner_loading
    apt install net-tools -y
fi

# Install whiptail if not existing
if [ "$(dpkg-query -W -f='${Status}' "whiptail" 2>/dev/null | grep -c "ok installed")" == "1" ]
then
    print_text_in_color "$IGreen" "whiptail OK"
else
    apt update -q4 & spinner_loading
    apt install whiptail -y
fi

# shellcheck disable=2034,2059
true
# shellcheck source=lib.sh
source <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/official-basic-vm/lib.sh)

# Get all needed variables from the library
first_iface

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Check if root
root_check

# Test RAM size (2GB min) + CPUs (min 1)
ram_check 2 Nextcloud
cpu_check 1 Nextcloud

# Download needed libraries before execution of the first script
mkdir -p "$SCRIPTS"
download_script GITHUB_REPO lib

# We don't want automatic updates since they might fail (we use our own script)
if is_this_installed unattended-upgrades
then
    apt-get purge unattended-upgrades -y
    apt-get autoremove -y
    rm -rf /var/log/unattended-upgrades
fi

# Check distribution and version
if ! version 20.04 "$DISTRO" 20.04.6
then
    msg_box "This script can only be run on Ubuntu 20.04 (server)."
    exit 1
fi
# Use this when Ubuntu 18.04 is deprecated from the function:
#check_distro_version
check_universe
check_multiverse

# Check if key is available
if ! site_200 "$NCREPO"
then
msg_box "Nextcloud repo is not available, exiting..."
    exit 1
fi

# Make it obvius regarding the differences
msg_box "This is the install script for the Official Nextcloud VM.

The intention with this is just to get a working Nextcloud without any extras at all, really - none.

The Official VM is just a test VM, and is not an example of how th original VM is built.
The original VM is years of development, and much richer and advanced in it's possibilites.
Though, we will use some of the basics from the original VM to be able to run Nextcloud.

In the full-version you can automatically install Nextcloud apps like e.g: OnlyOffice, Collabora, Talk (with signaling), get a valid TLS cert, and much much more.
You can check out the original full-version VM here: https://github.com/nextcloud/vm/releases."

# Fix LVM on BASE image
if grep -q "LVM" /etc/fstab
then
    if [ -n "$PROVISIONING" ] || yesno_box_yes "Do you want to make all free space available to your root partition?"
    then
    # Resize LVM (live installer is &%¤%/!
    # VM
    print_text_in_color "$ICyan" "Extending LVM, this may take a long time..."
    lvextend -l +100%FREE /dev/ubuntu-vg/ubuntu-lv

    # Run it again manually just to be sure it's done
    while :
    do
        lvdisplay | grep "Size" | awk '{print $3}'
        if ! lvextend -L +10G /dev/ubuntu-vg/ubuntu-lv >/dev/null 2>&1
        then
            if ! lvextend -L +1G /dev/ubuntu-vg/ubuntu-lv >/dev/null 2>&1
            then
                if ! lvextend -L +100M /dev/ubuntu-vg/ubuntu-lv >/dev/null 2>&1
                then
                    if ! lvextend -L +1M /dev/ubuntu-vg/ubuntu-lv >/dev/null 2>&1
                    then
                        resize2fs /dev/ubuntu-vg/ubuntu-lv
                        break
                    fi
                fi
            fi
        fi
    done
    fi
fi

# Check if it's a clean server
stop_if_installed postgresql
stop_if_installed apache2
stop_if_installed nginx
stop_if_installed php
stop_if_installed php-fpm
stop_if_installed php-common
stop_if_installed php"$PHPVER"-fpm
stop_if_installed php7.0-fpm
stop_if_installed php7.1-fpm
stop_if_installed php7.2-fpm
stop_if_installed php7.3-fpm
stop_if_installed php8.0-fpm
stop_if_installed mysql-common
stop_if_installed mariadb-server

# Create $VMLOGS dir
if [ ! -d "$VMLOGS" ]
then
    mkdir -p "$VMLOGS"
fi

# Install needed network
install_if_not netplan.io

# APT over HTTPS
install_if_not apt-transport-https

# Install build-essentials to get make
install_if_not build-essential

# Make sure sudo exists (needed in adduser.sh)
install_if_not sudo

# Make sure add-apt-repository exists (needed in lib.sh)
install_if_not software-properties-common

# Install PostgreSQL
# sudo add-apt-repository "deb http://apt.postgresql.org/pub/repos/apt/ bionic-pgdg main"
# curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
apt update -q4 & spinner_loading
apt install postgresql -y

# Create DB
cd /tmp
sudo -u postgres psql <<END
CREATE USER $NCUSER WITH PASSWORD '$PGDB_PASS';
CREATE DATABASE nextcloud_db WITH OWNER $NCUSER TEMPLATE template0 ENCODING 'UTF8';
END
print_text_in_color "$ICyan" "PostgreSQL password: $PGDB_PASS"
systemctl restart postgresql.service

# Install Apache
check_command apt-get install apache2 -y
a2enmod rewrite \
        headers \
        proxy \
        proxy_fcgi \
        setenvif \
        env \
        mime \
        dir \
        authz_core \
        alias \
        ssl

# We don't use Apache PHP (just to be sure)
a2dismod mpm_prefork

# Disable server tokens in Apache
if ! grep -q 'ServerSignature' /etc/apache2/apache2.conf
then
{
echo "# Turn off ServerTokens for both Apache and PHP"
echo "ServerSignature Off"
echo "ServerTokens Prod"
} >> /etc/apache2/apache2.conf

    check_command systemctl restart apache2.service
fi

# Install PHP "$PHPVER"
apt-get update -q4 & spinner_loading
check_command apt-get install -y \
    php"$PHPVER"-fpm \
    php"$PHPVER"-intl \
    php"$PHPVER"-ldap \
    php"$PHPVER"-imap \
    php"$PHPVER"-gd \
    php"$PHPVER"-pgsql \
    php"$PHPVER"-curl \
    php"$PHPVER"-xml \
    php"$PHPVER"-zip \
    php"$PHPVER"-mbstring \
    php"$PHPVER"-soap \
    php"$PHPVER"-json \
    php"$PHPVER"-gmp \
    php"$PHPVER"-bz2 \
    php"$PHPVER"-bcmath \
    php-pear
    # php"$PHPVER"-imagick \
    # libmagickcore-6.q16-3-extra

# Enable php-fpm
a2enconf php"$PHPVER"-fpm

# Enable HTTP/2 server wide
print_text_in_color "$ICyan" "Enabling HTTP/2 server wide..."
cat << HTTP2_ENABLE > "$HTTP2_CONF"
<IfModule http2_module>
    Protocols h2 http/1.1
</IfModule>
HTTP2_ENABLE
print_text_in_color "$IGreen" "$HTTP2_CONF was successfully created"
a2enmod http2
restart_webserver

# Set up a php-fpm pool with a unixsocket
cat << POOL_CONF > "$PHP_POOL_DIR"/nextcloud.conf
[Nextcloud]
user = www-data
group = www-data
listen = /run/php/php"$PHPVER"-fpm.nextcloud.sock
listen.owner = www-data
listen.group = www-data
pm = dynamic
; max_children is set dynamically with calculate_php_fpm()
pm.max_children = 8
pm.start_servers = 3
pm.min_spare_servers = 2
pm.max_spare_servers = 3
env[HOSTNAME] = $(hostname -f)
env[PATH] = /usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/snap/bin
env[TMP] = /tmp
env[TMPDIR] = /tmp
env[TEMP] = /tmp
security.limit_extensions = .php
php_admin_value [cgi.fix_pathinfo] = 1
; Optional
; pm.max_requests = 2000
POOL_CONF

# Disable the idling example pool.
mv "$PHP_POOL_DIR"/www.conf "$PHP_POOL_DIR"/www.conf.backup

# Enable the new php-fpm config
restart_webserver

# Calculate the values of PHP-FPM based on the amount of RAM available (it's done in the startup script as well)
calculate_php_fpm

# Install VM-tools
install_if_not open-vm-tools

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
run_script STATIC setup_secure_permissions_nextcloud

# Install Nextcloud
print_text_in_color "$ICyan" "Installing Nextcloud..."
cd "$NCPATH"
nextcloud_occ maintenance:install \
--data-dir="$NCDATA" \
--database=pgsql \
--database-name=nextcloud_db \
--database-user="$NCUSER" \
--database-pass="$PGDB_PASS" \
--admin-user="$NCUSER" \
--admin-pass="$NCPASS"
echo
print_text_in_color "$ICyan" "Nextcloud version:"
nextcloud_occ status
sleep 3
echo

# Prepare cron.php to be run every 5 minutes
crontab -u www-data -l | { cat; echo "*/5  *  *  *  * php -f $NCPATH/cron.php > /dev/null 2>&1"; } | crontab -u www-data -

# Change values in php.ini (increase max file size)
# max_execution_time
sed -i "s|max_execution_time =.*|max_execution_time = 3500|g" "$PHP_INI"
# max_input_time
sed -i "s|max_input_time =.*|max_input_time = 3600|g" "$PHP_INI"
# memory_limit
sed -i "s|memory_limit =.*|memory_limit = 512M|g" "$PHP_INI"
# post_max
sed -i "s|post_max_size =.*|post_max_size = 1100M|g" "$PHP_INI"
# upload_max
sed -i "s|upload_max_filesize =.*|upload_max_filesize = 1000M|g" "$PHP_INI"

# Set logging
nextcloud_occ config:system:set log_type --value=file
nextcloud_occ config:system:set logfile --value="$VMLOGS/nextcloud.log"
rm -f "$NCDATA/nextcloud.log"
nextcloud_occ config:system:set loglevel --value=2
install_and_enable_app admin_audit
nextcloud_occ config:app:set admin_audit logfile --value="$VMLOGS/audit.log"
nextcloud_occ config:system:set log.condition apps 0 --value admin_audit

# Set SMTP mail
nextcloud_occ config:system:set mail_smtpmode --value="smtp"

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
} >> "$PHP_INI"

# PHP-FPM optimization
# https://geekflare.com/php-fpm-optimization/
sed -i "s|;emergency_restart_threshold.*|emergency_restart_threshold = 10|g" /etc/php/"$PHPVER"/fpm/php-fpm.conf
sed -i "s|;emergency_restart_interval.*|emergency_restart_interval = 1m|g" /etc/php/"$PHPVER"/fpm/php-fpm.conf
sed -i "s|;process_control_timeout.*|process_control_timeout = 10|g" /etc/php/"$PHPVER"/fpm/php-fpm.conf

# PostgreSQL values for PHP (https://docs.nextcloud.com/server/latest/admin_manual/configuration_database/linux_database_configuration.html#postgresql-database)
{
echo ""
echo "[PostgresSQL]"
echo "pgsql.allow_persistent = On"
echo "pgsql.auto_reset_persistent = Off"
echo "pgsql.max_persistent = -1"
echo "pgsql.max_links = -1"
echo "pgsql.ignore_notice = 0"
echo "pgsql.log_notice = 0"
} >> "$PHP_FPM_DIR"/conf.d/20-pdo_pgsql.ini

# Fix https://github.com/nextcloud/vm/issues/714
print_text_in_color "$ICyan" "Optimizing Nextcloud..."
yes | nextcloud_occ db:convert-filecache-bigint
nextcloud_occ db:add-missing-indices
while [ -z "$CURRENTVERSION" ]
do
    CURRENTVERSION=$(sudo -u www-data php $NCPATH/occ status | grep "versionstring" | awk '{print $3}')
done
if [ "${CURRENTVERSION%%.*}" -ge "19" ]
then
    nextcloud_occ db:add-missing-columns
fi
if [ "${CURRENTVERSION%%.*}" -ge "20" ]
then
    nextcloud_occ db:add-missing-primary-keys
fi

# Install Figlet
install_if_not figlet

# To be able to use snakeoil certs
install_if_not ssl-cert

# Generate $HTTP_CONF
if [ ! -f $SITES_AVAILABLE/$HTTP_CONF ]
then
    touch "$SITES_AVAILABLE/$HTTP_CONF"
    cat << HTTP_CREATE > "$SITES_AVAILABLE/$HTTP_CONF"
<VirtualHost *:80>
### YOUR SERVER ADDRESS ###
#    ServerAdmin admin@example.com
#    ServerName example.com
#    ServerAlias subdomain.example.com
### SETTINGS ###
    <FilesMatch "\.php$">
        SetHandler "proxy:unix:/run/php/php$PHPVER-fpm.nextcloud.sock|fcgi://localhost"
    </FilesMatch>
    DocumentRoot $NCPATH
    <Directory $NCPATH>
    Options Indexes FollowSymLinks
    AllowOverride None
    ### include all .htaccess 
    Include $NCPATH/.htaccess
    Include $NCPATH/config/.htaccess
    Include $NCDATA/.htaccess
    ###
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
    SetEnv HOME $NCPATH
    SetEnv HTTP_HOME $NCPATH
    # Avoid "Sabre\DAV\Exception\BadRequest: expected filesize XXXX got XXXX"
    <IfModule mod_reqtimeout.c>
    RequestReadTimeout body=0
    </IfModule>
</VirtualHost>
HTTP_CREATE
    print_text_in_color "$IGreen" "$SITES_AVAILABLE/$HTTP_CONF was successfully created."
fi

# Generate $TLS_CONF
if [ ! -f $SITES_AVAILABLE/$TLS_CONF ]
then
    touch "$SITES_AVAILABLE/$TLS_CONF"
    cat << TLS_CREATE > "$SITES_AVAILABLE/$TLS_CONF"
# <VirtualHost *:80>
#     RewriteEngine On
#     RewriteRule ^(.*)$ https://%{HTTP_HOST}$1 [R=301,L]
# </VirtualHost>
<VirtualHost *:443>
    Header add Strict-Transport-Security: "max-age=15552000;includeSubdomains"
### YOUR SERVER ADDRESS ###
#    ServerAdmin admin@example.com
#    ServerName cloud.example.com
### SETTINGS ###
    <FilesMatch "\.php$">
        SetHandler "proxy:unix:/run/php/php$PHPVER-fpm.nextcloud.sock|fcgi://localhost"
    </FilesMatch>
    # Intermediate configuration
    SSLEngine               on
    SSLCompression          off
    SSLProtocol             -all +TLSv1.2 +TLSv1.3
    SSLCipherSuite          ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384 
    SSLHonorCipherOrder     off
    SSLSessionTickets       off
    ServerSignature         off
    # Logs
    LogLevel warn
    CustomLog \${APACHE_LOG_DIR}/access.log combined
    ErrorLog \${APACHE_LOG_DIR}/error.log
    DocumentRoot $NCPATH
    <Directory $NCPATH>
    Options Indexes FollowSymLinks
    AllowOverride None
    ### include all .htaccess 
    Include $NCPATH/.htaccess
    Include $NCPATH/config/.htaccess
    Include $NCDATA/.htaccess
    ###
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
    SetEnv HOME $NCPATH
    SetEnv HTTP_HOME $NCPATH
    # Avoid "Sabre\DAV\Exception\BadRequest: expected filesize XXXX got XXXX"
    <IfModule mod_reqtimeout.c>
    RequestReadTimeout body=0
    </IfModule>
### LOCATION OF CERT FILES ###
    SSLCertificateFile /etc/ssl/certs/ssl-cert-snakeoil.pem
    SSLCertificateKeyFile /etc/ssl/private/ssl-cert-snakeoil.key
</VirtualHost>
TLS_CREATE
    print_text_in_color "$IGreen" "$SITES_AVAILABLE/$TLS_CONF was successfully created."
fi

# Enable new config
a2ensite "$TLS_CONF"
a2ensite "$HTTP_CONF"
a2dissite default-ssl
restart_webserver

# Cleanup
apt autoremove -y
apt autoclean
find /root "/home/$UNIXUSER" -type f \( -name '*.sh*' -o -name '*.html*' -o -name '*.tar*' -o -name '*.zip*' \) -delete

# Set permissions final
run_script STATIC setup_secure_permissions_nextcloud
chown -R www-data:www-data "$NCPATH"

# Put IP adress in /etc/issue (shown before the login)
if [ -f /etc/issue ]
then
{
echo "\4"
echo "DEFAULT USER: ncadmin"
echo "DEFAULT PASS: nextcloud"
} >> /etc/issue
fi

# Force MOTD to show correct number of updates
if is_this_installed update-notifier-common
then
    sudo /usr/lib/update-notifier/update-motd-updates-available --force
fi


####### OFFICIAL (custom scripts) #######

# shellcheck disable=2034,2059
true
# shellcheck source=lib.sh
source <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/official-basic-vm/lib.sh)

# Get needed scripts for first bootup
download_script GITHUB_REPO nextcloud-startup-script
download_script GITHUB_REPO lib
download_script STATIC instruction
download_script STATIC change_db_pass
download_script STATIC history
download_script STATIC welcome
download_script ADDONS locales
download_script ADDONS locate_mirror
chown "$UNIXUSER":"$UNIXUSER" "$SCRIPTS"/welcome.sh
download_script NETWORK trusted
download_script MENU startup_configuration

# Make $SCRIPTS excutable
chmod +x -R "$SCRIPTS"
chown root:root -R "$SCRIPTS"

# Prepare first bootup
check_command run_script STATIC change-ncadmin-profile
check_command run_script STATIC change-root-profile

# Reboot
msg_box "Installation almost done, system will reboot when you hit OK. 
After reboot, please login to run the setup script."
reboot
