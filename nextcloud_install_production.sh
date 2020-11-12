#!/bin/bash

# T&M Hansson IT AB © - 2020, https://www.hanssonit.se/

# Prefer IPv4 for apt
echo 'Acquire::ForceIPv4 "true";' >> /etc/apt/apt.conf.d/99force-ipv4

# Install curl if not existing
if [ "$(dpkg-query -W -f='${Status}' "curl" 2>/dev/null | grep -c "ok installed")" == "1" ]
then
    echo "curl OK"
else
    apt update -q4
    apt install curl -y
fi

true
SCRIPT_NAME="Nextcloud Install Script"
SCRIPT_EXPLAINER="This script is installing all requierments that are needed for Nextcloud to run.
It's the first of two parts that are necessary to finish your customized Nextcloud installation."
# shellcheck source=lib.sh
source <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)

# Check for flags
if [ "$1" = "" ]
then
    print_text_in_color "$ICyan" "Running in normal mode..."
    sleep 1
elif [ "$1" = "--provisioning" ] || [ "$1" = "-p" ]
then
    print_text_in_color "$ICyan" "Running in provisioning mode..."
    export PROVISIONING=1
    sleep 1
else
    msg_box "Failed to get the correct flag. Did you enter it correctly?"
    exit 1
fi

# Show explainer
if [ -z "$PROVISIONING" ]
then
    msg_box "$SCRIPT_EXPLAINER"
fi

# Check if dpkg or apt is running
is_process_running apt
is_process_running dpkg

# Test if snapshot already exists
if does_snapshot_exist "NcVM-installation"
then
    msg_box "Unable to continue because a logical volume already exists.

To run this script again, please remove the volume by running:
'sudo lvremove /dev/ubuntu-vg/NcVM-installation'"
    exit 1
fi

# Create a placeholder volume before modifying anything
if [ -z "$PROVISIONING" ]
then
    if yesno_box_no "Do you want to use LVM snapshots to be able to restore your root partition during upgrades and such?
Please note: this feature will not be used by this script but by other scripts later on.
For now we will only create a placeholder volume that will be used to let some space for snapshot volumes."
    then
        check_free_space
        if [ "$FREE_SPACE" -ge 50 ]
        then
            print_text_in_color "$ICyan" "Creating volume..."
            sleep 1
            # Create a placeholder snapshot
            check_command lvcreate --size 5G --name "NcVM-installation" ubuntu-vg
        else
            print_text_in_color "$IRed" "Could not create volume because of insufficient space..."
            sleep 2
        fi
    fi
fi

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

true
# shellcheck source=lib.sh
source <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)

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
download_script STATIC fetch_lib

# Set locales
run_script ADDONS locales

# Offer to use archive.ubuntu.com
if [ -z "$PROVISIONING" ]
then
    msg_box "Your current download repository is $REPO"
fi
if [ -n "$PROVISIONING" ] || yesno_box_yes "Do you want use http://archive.ubuntu.com as repository for this server?"
then
    sed -i "s|http://.*archive.ubuntu.com|http://archive.ubuntu.com|g" /etc/apt/sources.list
fi

# Create new current user
download_script STATIC adduser
bash $SCRIPTS/adduser.sh "nextcloud_install_production.sh"
rm -f $SCRIPTS/adduser.sh

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

# Test Home/SME function
if home_sme_server
then
    msg_box "This is the Home/SME server, function works!"
else
    print_text_in_color "$ICyan" "Home/SME Server not detected. No worries, just testing the function."
    sleep 3
fi

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

# Install build-essentials to get make
install_if_not build-essential

# Set dual or single drive setup
if [ -n "$PROVISIONING" ]
then
    choice="2 Disks Auto"
else
    msg_box "This server is designed to run with two disks, one for OS and one for DATA. \
This will get you the best performance since the second disk is using ZFS which is a superior filesystem.
You could still choose to only run on one disk though, which is not recommended, \
but maybe your only option depending on which hypervisor you are running.

You will now get the option to decide which disk you want to use for DATA, \
or run the automatic script that will choose the available disk automatically."

    choice=$(whiptail --title "$TITLE - Choose disk format" --nocancel --menu \
"How would you like to configure your disks?
$MENU_GUIDE" "$WT_HEIGHT" "$WT_WIDTH" 4 \
"2 Disks Auto" "(Automatically configured)" \
"2 Disks Manual" "(Choose by yourself)" \
"1 Disk" "(Only use one disk /mnt/ncdata - NO ZFS!)" 3>&1 1>&2 2>&3)
fi

case "$choice" in
    "2 Disks Auto")
        run_script DISK format-sdb
        # Change to zfs-mount-generator
        run_script DISK change-to-zfs-mount-generator

    ;;
    "2 Disks Manual")
        run_script DISK format-chosen
        # Change to zfs-mount-generator
        run_script DISK change-to-zfs-mount-generator
    ;;
    "1 Disk")
        print_text_in_color "$IRed" "1 Disk setup chosen."
        sleep 2
    ;;
    *)
    ;;
esac

# Set DNS resolver
# https://unix.stackexchange.com/questions/442598/how-to-configure-systemd-resolved-and-systemd-networkd-to-use-local-dns-server-f    
while :
do
    if [ -n "$PROVISIONING" ]
    then
        choice="Quad9"
    else
        choice=$(whiptail --title "$TITLE - Set DNS Resolver" --menu \
"Which DNS provider should this Nextcloud box use?
$MENU_GUIDE" "$WT_HEIGHT" "$WT_WIDTH" 4 \
"Quad9" "(https://www.quad9.net/)" \
"Cloudflare" "(https://www.cloudflare.com/dns/)" \
"Local" "($GATEWAY) - DNS on gateway" 3>&1 1>&2 2>&3)
    fi

    case "$choice" in
        "Quad9")
            sed -i "s|^#\?DNS=.*$|DNS=9.9.9.9 149.112.112.112 2620:fe::fe 2620:fe::9|g" /etc/systemd/resolved.conf
        ;;
        "Cloudflare")
            sed -i "s|^#\?DNS=.*$|DNS=1.1.1.1 1.0.0.1 2606:4700:4700::1111 2606:4700:4700::1001|g" /etc/systemd/resolved.conf
        ;;
        "Local")
            sed -i "s|^#\?DNS=.*$|DNS=$GATEWAY|g" /etc/systemd/resolved.conf
            if network_ok
            then
                break
            else
                msg_box "Could not validate the local DNS server. Pick an Internet DNS server and try again."
                continue
            fi
        ;;
        *)
        ;;
    esac
    if test_connection
    then
        break
    else
        msg_box "Could not validate the DNS server. Please try again."
    fi
done

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
download_script STATIC setup_secure_permissions_nextcloud
bash $SECURE & spinner_loading

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

# Prepare cron.php to be run every 15 minutes
crontab -u www-data -l | { cat; echo "*/5  *  *  *  * php -f $NCPATH/cron.php > /dev/null 2>&1"; } | crontab -u www-data -

# Run the updatenotification on a schelude
nextcloud_occ config:system:set upgrade.disable-web --value="true"
nextcloud_occ config:app:set updatenotification notify_groups --value="[]"
print_text_in_color "$ICyan" "Configuring update notifications specific for this server..."
download_script STATIC updatenotification
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
nextcloud_occ config:system:set log_type --value=file
nextcloud_occ config:system:set logfile --value="$VMLOGS/nextcloud.log"
rm -f "$NCDATA/nextcloud.log"
nextcloud_occ config:system:set loglevel --value=2
install_and_enable_app admin_audit
nextcloud_occ config:app:set admin_audit logfile --value="$VMLOGS/audit.log"
nextcloud_occ config:system:set log.condition apps 0 --value admin_audit

# Set SMTP mail
nextcloud_occ config:system:set mail_smtpmode --value="smtp"

# Forget login/session after 30 minutes
nextcloud_occ config:system:set remember_login_cookie_lifetime --value="1800"

# Set logrotate (max 10 MB)
nextcloud_occ config:system:set log_rotate_size --value="10485760"

# Set trashbin retention obligation (save it in trahbin for 6 months or delete when space is needed)
nextcloud_occ config:system:set trashbin_retention_obligation --value="auto, 180"

# Set versions retention obligation (save versions for 12 months or delete when space is needed)
nextcloud_occ config:system:set versions_retention_obligation --value="auto, 365"

# Remove simple signup
nextcloud_occ config:system:set simpleSignUpLink.shown --type=bool --value=false

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
run_script ADDONS redis-server-ubuntu

# Install smbclient
# php"$PHPVER"-smbclient does not yet work in PHP 7.4
install_if_not libsmbclient-dev
yes no | pecl install smbclient
if [ ! -f $PHP_MODS_DIR/smbclient.ini ]
then
    touch $PHP_MODS_DIR/smbclient.ini
fi
if ! grep -qFx extension=smbclient.so $PHP_MODS_DIR/smbclient.ini
then
    echo "# PECL smbclient" > $PHP_MODS_DIR/smbclient.ini
    echo "extension=smbclient.so" >> $PHP_MODS_DIR/smbclient.ini
    check_command phpenmod -v ALL smbclient
fi

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
    cat << TLS_CREATE > "$SITES_AVAILABLE/$TLS_CONF"
# <VirtualHost *:80>
#     RewriteEngine On
#     RewriteRule ^(.*)$ https://%{HTTP_HOST}$1 [R=301,L]
# </VirtualHost>

<VirtualHost *:443>
    Header add Strict-Transport-Security: "max-age=15768000;includeSubdomains"

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
    CustomLog ${APACHE_LOG_DIR}/access.log combined
    ErrorLog ${APACHE_LOG_DIR}/error.log

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
TLS_CREATE
    print_text_in_color "$IGreen" "$SITES_AVAILABLE/$TLS_CONF was successfully created."
fi

# Enable new config
a2ensite "$TLS_CONF"
a2ensite "$HTTP_CONF"
a2dissite default-ssl
restart_webserver

if [ -n "$PROVISIONING" ]
then
    choice="Calendar Contacts IssueTemplate PDFViewer Extract Text Mail Deck Group-Folders"
else
    choice=$(whiptail --title "$TITLE - Install apps or software" --checklist \
"Automatically configure and install selected apps or software
$CHECKLIST_GUIDE" "$WT_HEIGHT" "$WT_WIDTH" 4 \
"Calendar" "" ON \
"Contacts" "" ON \
"IssueTemplate" "" ON \
"PDFViewer" "" ON \
"Extract" "" ON \
"Text" "" ON \
"Mail" "" ON \
"Deck" "" ON \
"Group-Folders" "" ON 3>&1 1>&2 2>&3)
fi

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
    *"Group-Folders"*)
        install_and_enable_app groupfolders
    ;;&
    *)
    ;;
esac

# Cleanup
apt autoremove -y
apt autoclean
find /root "/home/$UNIXUSER" -type f \( -name '*.sh*' -o -name '*.html*' -o -name '*.tar*' -o -name '*.zip*' \) -delete

# Install virtual kernels for Hyper-V, (and extra for UTF8 kernel module + Collabora and OnlyOffice)
# Kernel 5.4
if ! home_sme_server
then
    if [ "$SYSVENDOR" == "Microsoft Corporation" ]
    then
        # Hyper-V
        apt install -y --install-recommends \
        linux-virtual \
        linux-image-virtual \
        linux-tools-virtual \
        linux-cloud-tools-virtual
        # linux-image-extra-virtual only needed for AUFS driver with Docker
    fi
fi

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

# It has to be this order:
# Download scripts
# chmod +x
# Set permissions for ncadmin in the change scripts

# Get needed scripts for first bootup
download_script GITHUB_REPO nextcloud-startup-script
download_script STATIC instruction
download_script STATIC history
download_script NETWORK static_ip

# Make $SCRIPTS excutable
chmod +x -R "$SCRIPTS"
chown root:root -R "$SCRIPTS"

# Prepare first bootup
check_command run_script STATIC change-ncadmin-profile
check_command run_script STATIC change-root-profile

if home_sme_server
then
    # Change nextcloud-startup-script.sh
    check_command sed -i "s|VM|Home/SME Server|g" $SCRIPTS/nextcloud-startup-script.sh
fi

# Disable hibernation
print_text_in_color "$ICyan" "Disable hibernation..."
systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target

# Reboot
if [ -z "$PROVISIONING" ]
then
    msg_box "Installation almost done, system will reboot when you hit OK. 

Please log in again once rebooted to run the setup script."
fi
reboot
