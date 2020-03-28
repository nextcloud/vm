#!/bin/bash

# T&M Hansson IT AB © - 2020, https://www.hanssonit.se/

# Variables:
SCRIPTS=/var/scripts

# Download and validate Nextcloud VM
if [ ! -d "$SCRIPTS"/apps ] && [ ! -d "$SCRIPTS"/main ] && [ ! -d "$SCRIPTS"/lets-encrypt ] && [ ! -d "$SCRIPTS"/static ]
then
    # Check if root
    if [[ "$EUID" -ne 0 ]]
    then
        echo "You have to run this script as root! Exiting..."
        exit 1
    fi

    # Test internet connection
    if ! ping -c1 -W1 github.com &>/dev/null
    then
        echo "Couldn't reach github.com. Exiting..."
        exit 1
    fi

    # Todo: Verify the release package and integrity with the gpg key

    # Todo: Download the release package (.tar) file

    # Todo: Verify the state of the downloaded package with a checksum?

    # Todo: Extract everything to "$SCRIPTS"
    mkdir -p "$SCRIPTS"

    # This section is for testing purposes only; should get removed if everything above is ready.
    git clone -b testing --single-branch https://github.com/nextcloud/vm.git "$SCRIPTS"
    # Remove all unnecessary files
    rm -r "$SCRIPTS"/.git
    rm "$SCRIPTS"/LICENSE
    rm "$SCRIPTS"/issue_template.md
    rm "$SCRIPTS"/.travis.yml
    rm "$SCRIPTS"/README.md
    rm "$SCRIPTS"/nextcloud_vm.sh

    # Move all main files to "$SCRIPTS"/main (apart from install-production and startup-script)
    mkdir -p "$SCRIPTS"/main
    mv "$SCRIPTS"/lib.sh "$SCRIPTS"/main 
    mv "$SCRIPTS"/nextcloud_update.sh "$SCRIPTS"/main

    # Set ownership and permission
    chown -R root:root "$SCRIPTS"
    chmod -R +x "$SCRIPTS"

    # Run the nextcloud_install_production script in a new process
    exec "$SCRIPTS"/nextcloud_install_production.sh
fi

# -----------------------------------------------------------------------------------------------------------------------------------

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

# Use local lib file if existant
if [ -f /var/scripts/main/lib.sh ]
then
# shellcheck disable=2034,2059
true
# shellcheck source=lib.sh
source /var/scripts/main/lib.sh
else
# shellcheck disable=2034,2059
true
# shellcheck source=lib.sh
. <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/testing/lib.sh)
fi

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

# Use local lib file if existant
if [ -f /var/scripts/main/lib.sh ]
then
# shellcheck disable=2034,2059
true
# shellcheck source=lib.sh
FIRST_IFACE=1 && CHECK_CURRENT_REPO=1 source /var/scripts/main/lib.sh
unset FIRST_IFACE
unset CHECK_CURRENT_REPO
else
# shellcheck disable=2034,2059
true
# shellcheck source=lib.sh
FIRST_IFACE=1 && CHECK_CURRENT_REPO=1 . <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/testing/lib.sh)
unset FIRST_IFACE
unset CHECK_CURRENT_REPO
fi

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Check if root
root_check

# Set keyboard layout
if [ "$KEYBOARD_LAYOUT" != "se" ]
then
    print_text_in_color "$ICyan" "Current keyboard layout is $KEYBOARD_LAYOUT"
    if [[ "no" == $(ask_yes_or_no "Do you want to change keyboard layout?") ]]
    then
        print_text_in_color "$ICyan" "Not changing keyboard layout..."
        sleep 1
    else
        dpkg-reconfigure keyboard-configuration
        msg_box "The server will now be rebooted to apply the new keyboard settings. Please run this script again once rebooted."
        reboot
    fi
fi

# Set locales
KEYBOARD_LAYOUT=$(localectl status | grep "Layout" | awk '{print $3}')
install_if_not language-pack-en-base
if [ "$KEYBOARD_LAYOUT" = "se" ]
then
    sudo locale-gen "sv_SE.UTF-8" && sudo dpkg-reconfigure --frontend=noninteractive locales
elif [ "$KEYBOARD_LAYOUT" = "de" ]
then
    sudo locale-gen "de_DE.UTF-8" && sudo dpkg-reconfigure --frontend=noninteractive locales
else
    sudo locale-gen "en_US.UTF-8" && sudo dpkg-reconfigure --frontend=noninteractive locales
fi

# Test RAM size (2GB min) + CPUs (min 1)
ram_check 2 Nextcloud
cpu_check 1 Nextcloud

# Create new current user
download_static_script adduser
bash $SCRIPTS/adduser.sh "nextcloud_install_production.sh"
rm -f $SCRIPTS/adduser.sh

# Check distribution and version
check_distro_version
check_universe
check_multiverse

# Check if key is available
if ! site_200 "$NCREPO"
then
msg_box "Nextcloud repo is not available, exiting..."
    exit 1
fi

# Check if it's a clean server
stop_if_installed postgresql
stop_if_installed apache2
stop_if_installed nginx
stop_if_installed php
stop_if_installed php-fpm
stop_if_installed php"$PHPVER"-fpm
stop_if_installed php7.0-fpm
stop_if_installed php7.1-fpm
stop_if_installed php7.2-fpm
stop_if_installed php7.3-fpm
stop_if_installed mysql-common
stop_if_installed mariadb-server

# Create $SCRIPTS dir
if [ ! -d "$SCRIPTS" ]
then
    mkdir -p "$SCRIPTS"
fi

# Create $VMLOGS dir
if [ ! -d "$VMLOGS" ]
then
    mkdir -p "$VMLOGS"
fi

# Install needed network
install_if_not netplan.io
install_if_not network-manager

# Install build-essentials to get make
install_if_not build-essential

# Just check if the function works and run disk setup
if home_sme_server
then
    run_static_script format-sda-nuc-server
else
# Set dual or single drive setup
msg_box "This VM is designed to run with two disks, one for OS and one for DATA. This will get you the best performance since the second disk is using ZFS which is a superior filesystem.
You could still choose to only run on one disk though, which is not recommended, but maybe your only option depending on which hypervisor you are running.

You will now get the option to decide which disk you want to use for DATA, or run the automatic script that will choose the available disk automatically."

choice=$(whiptail --title "Choose disk format" --radiolist "How would you like to configure your disks?\nSelect by pressing the spacebar and ENTER" "$WT_HEIGHT" "$WT_WIDTH" 4 \
"2 Disks Auto" "(Automatically configured)" ON \
"2 Disks Manual" "(Choose by yourself)" OFF \
"1 Disk" "(Only use one disk /mnt/ncdata - NO ZFS!)" OFF 3>&1 1>&2 2>&3)

case "$choice" in
    "2 Disks Auto")
        run_static_script format-sdb
    ;;
    "2 Disks Manual")
        run_static_script format-chosen
    ;;
    "1 Disk")
        print_text_in_color "$IRed" "1 Disk setup chosen."
        sleep 2
    ;;
    *)
    ;;
esac
fi

# Set DNS resolver
# https://medium.com/@ahmadb/fixing-dns-issues-in-ubuntu-18-04-lts-bd4f9ca56620
choice=$(whiptail --title "Set DNS Resolver" --radiolist "Which DNS provider should this Nextcloud box use?\nSelect by pressing the spacebar and ENTER" "$WT_HEIGHT" "$WT_WIDTH" 4 \
"Quad9" "(https://www.quad9.net/)" ON \
"Cloudflare" "(https://www.cloudflare.com/dns/)" OFF \
"Local" "($GATEWAY + 149.112.112.112)" OFF 3>&1 1>&2 2>&3)

case "$choice" in
    "Quad9")
        sed -i "s|#DNS=.*|DNS=9.9.9.9 2620:fe::fe|g" /etc/systemd/resolved.conf
        sed -i "s|#FallbackDNS=.*|FallbackDNS=149.112.112.112 2620:fe::9|g" /etc/systemd/resolved.conf
    ;;
    "Cloudflare")
        sed -i "s|#DNS=.*|DNS=1.1.1.1 2606:4700:4700::1111|g" /etc/systemd/resolved.conf
        sed -i "s|#FallbackDNS=.*|FallbackDNS=1.0.0.1 2606:4700:4700::1001|g" /etc/systemd/resolved.conf
    ;;
    "Local")
        sed -i "s|#DNS=.*|DNS=$GATEWAY|g" /etc/systemd/resolved.conf
        sed -i "s|#FallbackDNS=.*|FallbackDNS=149.112.112.112 2620:fe::9|g" /etc/systemd/resolved.conf
    ;;
    *)
    ;;
esac
check_command systemctl restart network-manager.service
network_ok

# Check where the best mirrors are and update
echo
printf "Your current server repository is:  ${ICyan}%s${Color_Off}\n" "$REPO"
if [[ "no" == $(ask_yes_or_no "Do you want to try to find a better mirror?") ]]
then
    print_text_in_color "$ICyan" "Keeping $REPO as mirror..."
    sleep 1
else
   print_text_in_color "$ICyan" "Locating the best mirrors..."
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

# Install PostgreSQL
# sudo add-apt-repository "deb http://apt.postgresql.org/pub/repos/apt/ bionic-pgdg main"
# curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
apt update -q4 & spinner_loading
apt install postgresql-10 -y

# Create DB
cd /tmp
sudo -u postgres psql <<END
CREATE USER $NCUSER WITH PASSWORD '$PGDB_PASS';
CREATE DATABASE nextcloud_db WITH OWNER $NCUSER TEMPLATE template0 ENCODING 'UTF8';
END
print_text_in_color "$ICyan" "PostgreSQL password: $PGDB_PASS"
service postgresql restart

# Install Apache
check_command apt install apache2 -y
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
apt update -q4 & spinner_loading
check_command apt install -y \
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
    php"$PHPVER"-smbclient \
    php"$PHPVER"-json \
    php"$PHPVER"-gmp \
    php"$PHPVER"-bz2 \
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
    H2Direct on
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

# Enable SMB client # already loaded with php-smbclient
# echo '# This enables php-smbclient' >> /etc/php/"$PHPVER"/apache2/php.ini
# echo 'extension="smbclient.so"' >> /etc/php/"$PHPVER"/apache2/php.ini

# Install VM-tools
install_if_not open-vm-tools

# Install jQuery, needed for notify_admin_gui
install_if_not jq

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
print_text_in_color "$ICyan" "Installing Nextcloud..."
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
print_text_in_color "$ICyan" "Nextcloud version:"
occ_command status
sleep 3
echo

# Prepare cron.php to be run every 15 minutes
crontab -u www-data -l | { cat; echo "*/5  *  *  *  * php -f $NCPATH/cron.php > /dev/null 2>&1"; } | crontab -u www-data -

# Run the updatenotification on a schelude
occ_command config:system:set upgrade.disable-web --value="true"
print_text_in_color "$ICyan" "Configuring update notifications specific for this server..."
download_static_script updatenotification
check_command chmod +x "$SCRIPTS"/updatenotification.sh
crontab -u root -l | { cat; echo "59 $AUT_UPDATES_TIME * * * $SCRIPTS/updatenotification.sh > /dev/null 2>&1"; } | crontab -u root -

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

# Set loggging
occ_command config:system:set log_type --value=file
occ_command config:system:set logfile --value="$VMLOGS/nextcloud.log"
rm -f "$NCDATA/nextcloud.log"
occ_command config:system:set loglevel --value=2
occ_command config:app:set admin_audit logfile --value="$VMLOGS/audit.log"
install_and_enable_app admin_audit

# Set SMTP mail
occ_command config:system:set mail_smtpmode --value="smtp"

# Forget login/session after 30 minutes
occ_command config:system:set remember_login_cookie_lifetime --value="1800"

# Set logrotate (max 10 MB)
occ_command config:system:set log_rotate_size --value="10485760"

# Set trashbin retention obligation (save it in trahbin for 6 months or delete when space is needed)
occ_command config:system:set trashbin_retention_obligation --value="auto, 180"

# Set versions retention obligation (save versions for 12 months or delete when space is needed)
occ_command config:system:set versions_retention_obligation --value="auto, 365"

# Remove simple signup
occ_command config:system:set simpleSignUpLink.shown --value="false" 

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

# Install Redis (distrubuted cache)
run_static_script redis-server-ubuntu

# Enable igbinary for PHP
# https://github.com/igbinary/igbinary
if is_this_installed "php$PHPVER"-dev
then
    if ! yes no | pecl install -Z igbinary
    then
        msg_box "igbinary PHP module installation failed"
        exit
    else
        print_text_in_color "$IGreen" "igbinary PHP module installation OK!"
    fi
{
echo "# igbinary for PHP"
echo "extension=igbinary.so"
echo "session.serialize_handler=igbinary"
echo "igbinary.compact_strings=On"
} >> "$PHP_INI"
restart_webserver
fi

# APCu (local cache)
if is_this_installed "php$PHPVER"-dev
then
    if ! yes no | pecl install -Z apcu
    then
        msg_box "APCu PHP module installation failed"
        exit
    else
        print_text_in_color "$IGreen" "APCu PHP module installation OK!"
    fi
{
echo "# APCu settings for Nextcloud"
echo "extension=apcu.so"
echo "apc.enabled=1"
echo "apc.max_file_size=5M"
echo "apc.shm_segments=1"
echo "apc.shm_size=128M"
echo "apc.entries_hint=4096"
echo "apc.ttl=3600"
echo "apc.gc_ttl=7200"
echo "apc.mmap_file_mask=NULL"
echo "apc.slam_defense=1"
echo "apc.enable_cli=1"
echo "apc.use_request_time=1"
echo "apc.serializer=igbinary"
echo "apc.coredump_unmap=0"
echo "apc.preload_path"
} >> "$PHP_INI"
restart_webserver
fi

# Fix https://github.com/nextcloud/vm/issues/714
print_text_in_color "$ICyan" "Optimizing Nextcloud..."
yes | occ_command db:convert-filecache-bigint
occ_command db:add-missing-indices

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
    cat << SSL_CREATE > "$SITES_AVAILABLE/$TLS_CONF"
<VirtualHost *:443>
    Header add Strict-Transport-Security: "max-age=15768000;includeSubdomains"
    SSLEngine on

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
SSL_CREATE
    print_text_in_color "$IGreen" "$SITES_AVAILABLE/$TLS_CONF was successfully created."
fi

# Enable new config
a2ensite "$TLS_CONF"
a2ensite "$HTTP_CONF"
a2dissite default-ssl
restart_webserver

choice=$(whiptail --title "Install apps or software" --checklist "Automatically configure and install selected apps or software\nDeselect by pressing the spacebar" "$WT_HEIGHT" "$WT_WIDTH" 4 \
"Calendar" "" ON \
"Contacts" "" ON \
"IssueTemplate" "" ON \
"PDFViewer" "" ON \
"Extract" "" ON \
"Text" "" ON \
"Mail" "" ON \
"Deck" "" ON \
"Social" "" ON \
"Group-Folders" "" ON \
"Webmin" "" ON 3>&1 1>&2 2>&3)

case "$choice" in
    *"Calendar"*)
        install_and_enable_app calendar
    ;;&
    *"Contacts"*)
        install_and_enable_app contacts
    ;;&
    *"IssueTemplate"*)
        install_and_enable_app issuetemplate
    ;;&
    *"PDFViewer"*)
        install_and_enable_app files_pdfviewer
    ;;&
    *"Extract"*)
        if install_and_enable_app extract
        then
            install_if_not unrar
            install_if_not p7zip
            install_if_not p7zip-full
        fi
    ;;&
    *"Text"*)
        install_and_enable_app text
    ;;&
    *"Mail"*)
        install_and_enable_app mail
    ;;&
    *"Deck"*)
        install_and_enable_app deck
    ;;&
    *"Social"*)
        install_and_enable_app social
    ;;&
    *"Group-Folders"*)
        install_and_enable_app groupfolders
    ;;&
    *"Webmin"*)
        run_app_script webmin
    ;;&
    *)
    ;;
esac

# Get needed scripts for first bootup
if [ -f "${SCRIPTS}"/nextcloud-startup-script.sh ]
then
    sleep 1
else
    check_command curl_to_dir "$GITHUB_REPO" nextcloud-startup-script.sh "$SCRIPTS"
fi
if [ -f "${SCRIPTS}"/main/lib.sh ]
then
    sleep 1
else
    check_command curl_to_dir "$GITHUB_REPO" lib.sh "$SCRIPTS"
fi
download_static_script instruction
download_static_script history
download_static_script static_ip

if home_sme_server
then
    # Change nextcloud-startup-script.sh
    check_command sed -i "s|VM|Home/SME Server|g" $SCRIPTS/nextcloud-startup-script.sh
fi

# Make $SCRIPTS excutable
chmod +x -R "$SCRIPTS"
chown root:root -R "$SCRIPTS"

# Prepare first bootup
check_command run_static_script change-ncadmin-profile
check_command run_static_script change-root-profile

# Upgrade
apt update -q4 & spinner_loading
apt dist-upgrade -y

# Remove LXD (always shows up as failed during boot)
apt purge lxd -y

# Cleanup
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

# Add aliases
if [ -f /root/.bash_aliases ]
then
    if ! grep -q "nextcloud" /root/.bash_aliases
    then
{
echo "alias nextcloud_occ='sudo -u www-data php /var/www/nextcloud/occ'"
echo "alias run_update_nextcloud='bash /var/scripts/update.sh'"
} >> /root/.bash_aliases
    fi
elif [ ! -f /root/.bash_aliases ]
then
{
echo "alias nextcloud_occ='sudo -u www-data php /var/www/nextcloud/occ'"
echo "alias run_update_nextcloud='bash /var/scripts/update.sh'"
} > /root/.bash_aliases
fi

# Set secure permissions final (./data/.htaccess has wrong permissions otherwise)
bash $SECURE & spinner_loading

# Put IP adress in /etc/issue (shown before the login)
if [ -f /etc/issue ]
then
    echo "\4" >> /etc/issue
fi

# Force MOTD to show correct number of updates
if is_this_installed update-notifier-common
then
    sudo /usr/lib/update-notifier/update-motd-updates-available --force
fi

if [ -f "$SCRIPTS"/nextcloud_install_production.sh ]
then
    rm "$SCRIPTS"/nextcloud_install_production.sh
fi

# Reboot
print_text_in_color "$IGreen" "Installation done, system will now reboot..."
reboot
