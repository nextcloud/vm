#!/bin/bash

# T&M Hansson IT AB © - 2023, https://www.hanssonit.se/
# GNU General Public License v3.0
# https://github.com/nextcloud/vm/blob/master/LICENSE

# Prefer IPv4 for apt
echo 'Acquire::ForceIPv4 "true";' >> /etc/apt/apt.conf.d/99force-ipv4

# Fix fancy progress bar for apt-get
# https://askubuntu.com/a/754653
if [ -d /etc/apt/apt.conf.d ]
then
    if ! [ -f /etc/apt/apt.conf.d/99progressbar ]
    then
        echo 'Dpkg::Progress-Fancy "1";' > /etc/apt/apt.conf.d/99progressbar
        echo 'APT::Color "1";' >> /etc/apt/apt.conf.d/99progressbar
        chmod 644 /etc/apt/apt.conf.d/99progressbar
    fi
fi

# Install curl if not existing
if [ "$(dpkg-query -W -f='${Status}' "curl" 2>/dev/null | grep -c "ok installed")" = "1" ]
then
    echo "curl OK"
else
    apt-get update -q4
    apt-get install curl -y
fi

# Install whiptail if not existing
if [ "$(dpkg-query -W -f='${Status}' "whiptail" 2>/dev/null | grep -c "ok installed")" = "1" ]
then
    echo "whiptail OK"
else
    apt-get install whiptail -y
fi

true
SCRIPT_NAME="Nextcloud Install Script"
SCRIPT_EXPLAINER="This script is installing all requirements that are needed for Nextcloud to run.
It's the first of two parts that are necessary to finish your customized Nextcloud installation."
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

# Check if dpkg or apt is running
is_process_running apt
is_process_running dpkg

# Check distribution and version
if ! version 22.04 "$DISTRO" 22.04.10
then
    msg_box "This script can only be run on Ubuntu 22.04 (server)."
    exit 1
fi

# Automatically restart services
# Restart mode: (l)ist only, (i)nteractive or (a)utomatically.
sed -i "s|#\$nrconf{restart} = .*|\$nrconf{restart} = 'a';|g" /etc/needrestart/needrestart.conf

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
elif [ "$1" = "--not-latest" ]
then
    NOT_LATEST=1
    print_text_in_color "$ICyan" "Running in not-latest mode..."
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

# Create a placeholder volume before modifying anything
if [ -z "$PROVISIONING" ]
then
    if ! does_snapshot_exist "NcVM-installation" && yesno_box_no "Do you want to use LVM snapshots to be able to restore your root partition during upgrades and such?
Please note: this feature will not be used by this script but by other scripts later on.
For now we will only create a placeholder volume that will be used to let some space for snapshot volumes.
Be aware that you will not be able to use the built-in backup solution if you choose 'No'!
Enabling this will also force an automatic reboot after running the update script!"
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

# Install needed dependencies
install_if_not lshw
install_if_not net-tools
install_if_not whiptail
install_if_not apt-utils
install_if_not keyboard-configuration

# Nice to have dependencies
install_if_not bash-completion
install_if_not htop
install_if_not iputils-ping

# Download needed libraries before execution of the first script
mkdir -p "$SCRIPTS"
download_script GITHUB_REPO lib
download_script STATIC fetch_lib

# Set locales
run_script ADDONS locales

# Create new current user
download_script STATIC adduser
bash "$SCRIPTS"/adduser.sh "nextcloud_install_production.sh"
rm -f "$SCRIPTS"/adduser.sh

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
stop_if_installed php8.1-fpm
stop_if_installed php8.2-fpm
stop_if_installed mysql-common
stop_if_installed mariadb-server

# We don't want automatic updates since they might fail (we use our own script)
if is_this_installed unattended-upgrades
then
    apt-get purge unattended-upgrades -y
    apt-get autoremove -y
    rm -rf /var/log/unattended-upgrades
fi

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

# APT over HTTPS
install_if_not apt-transport-https

# Install build-essentials to get make
install_if_not build-essential

# Install a decent text editor
install_if_not nano

# Install package for crontab
install_if_not cron

# Make sure sudo exists (needed in adduser.sh)
install_if_not sudo

# Make sure add-apt-repository exists (needed in lib.sh)
install_if_not software-properties-common

# Set dual or single drive setup
if [ -n "$PROVISIONING" ]
then
    choice="2 Disks Auto"
else
    msg_box "This server is designed to run with two disks, one for OS and one for DATA. \
This will get you the best performance since the second disk is using ZFS which is a superior filesystem.

Though not recommended, you can still choose to only run on one disk, \
if for example it's your only option on the hypervisor you're running.

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
        # Create daily zfs prune script
        run_script DISK create-daily-zfs-prune

    ;;
    "2 Disks Manual")
        run_script DISK format-chosen
        # Change to zfs-mount-generator
        run_script DISK change-to-zfs-mount-generator
        # Create daily zfs prune script
        run_script DISK create-daily-zfs-prune
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
"Local" "($GATEWAY) - DNS on gateway" \
"Expert" "If you really know what you're doing!" 3>&1 1>&2 2>&3)
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
            systemctl restart systemd-resolved.service
            if network_ok
            then
                break
            else
                msg_box "Could not validate the local DNS server. Pick an Internet DNS server and try again."
                continue
            fi
        ;;
        "Expert")
            OWNDNS=$(input_box_flow "Please choose your own DNS server(s) with a space in between, e.g: $GATEWAY 9.9.9.9 (NS1 NS2)")
            sed -i "s|^#\?DNS=.*$|DNS=$OWNDNS|g" /etc/systemd/resolved.conf
            systemctl restart systemd-resolved.service
            if network_ok
            then
                break
                unset OWNDNS 
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
apt-get update -q4 & spinner_loading
install_if_not postgresql

# Create DB
cd /tmp
sudo -u postgres psql <<END
CREATE USER $PGDB_USER WITH PASSWORD '$PGDB_PASS';
CREATE DATABASE nextcloud_db WITH OWNER $PGDB_USER TEMPLATE template0 ENCODING 'UTF8';
END
print_text_in_color "$ICyan" "PostgreSQL password: $PGDB_PASS"
systemctl restart postgresql.service

# Install Apache
check_command install_if_not apache2
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
        mpm_event \
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
install_if_not php"$PHPVER"-fpm
install_if_not php"$PHPVER"-intl
install_if_not php"$PHPVER"-ldap
install_if_not php"$PHPVER"-imap
install_if_not php"$PHPVER"-gd
install_if_not php"$PHPVER"-pgsql
install_if_not php"$PHPVER"-curl
install_if_not php"$PHPVER"-xml
install_if_not php"$PHPVER"-zip
install_if_not php"$PHPVER"-mbstring
install_if_not php"$PHPVER"-soap
install_if_not php"$PHPVER"-gmp
install_if_not php"$PHPVER"-bz2
install_if_not php"$PHPVER"-bcmath
install_if_not php-pear

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
if [ "$SYSVENDOR" == "VMware, Inc." ];
then
    install_if_not open-vm-tools
elif [[ "$SYSVENDOR" == "QEMU" || "$SYSVENDOR" == "Red Hat" ]];
then
    install_if_not qemu-guest-agent
    systemctl enable qemu-guest-agent
    systemctl start qemu-guest-agent
fi

# Get not-latest Nextcloud version
if [ -n "$NOT_LATEST" ]
then
    while [ -z "$NCVERSION" ]
    do
        print_text_in_color "$ICyan" "Fetching the not-latest Nextcloud version..."
        NCVERSION=$(curl -s -m 900 "$NCREPO"/ | sed --silent 's/.*href="nextcloud-\([^"]\+\).zip.asc".*/\1/p' \
| sort --version-sort | grep -v "\.0$\|\.1$\|\.2$" | tail -1)
        STABLEVERSION="nextcloud-$NCVERSION"
        print_text_in_color "$IGreen" "$NCVERSION"
    done
fi

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
bash "$SECURE" & spinner_loading

# Ask to set a custom username
if yesno_box_no "Nextcloud is about to be installed.\nDo you want to change the standard GUI user '$GUIUSER' to something else?"
then
    while :
    do
        GUIUSER=$(input_box_flow "Please type in the name of the Web Admin in Nextcloud.
\nThe only allowed characters for the username are:
'a-z', 'A-Z', '0-9', and '_.@-'")
        if [[ "$GUIUSER" == *" "* ]]
        then
            msg_box "Please don't use spaces."
        # - has to be escaped otherwise it won't work.
        # Inspired by: https://unix.stackexchange.com/a/498731/433213
        elif [ "${GUIUSER//[A-Za-z0-9_.\-@]}" ]
        then
            msg_box "Allowed characters for the username are:\na-z', 'A-Z', '0-9', and '_.@-'\n\nPlease try again."
        else
            break
        fi
    done
    while :
    do
        GUIPASS=$(input_box_flow "Please type in the new password for the new Web Admin ($GUIUSER) in Nextcloud.")
        if [[ "$GUIPASS" == *" "* ]]
        then
            msg_box "Please don't use spaces."
        fi
        if [ "${GUIPASS//[A-Za-z0-9_.\-@]}" ]
        then
            msg_box "Allowed characters for the password are:\na-z', 'A-Z', '0-9', and '_.@-'\n\nPlease try again."
        else
        msg_box "The new Web Admin in Nextcloud is now: $GUIUSER\nThe password is set to: $GUIPASS
This is used when you login to Nextcloud itself, i.e. on the web."
            break
        fi
    done

fi

# Install Nextcloud
print_text_in_color "$ICyan" "Installing Nextcloud, it might take a while..."
cd "$NCPATH"
# Don't use nextcloud_occ here as it takes alooong time.
# https://github.com/nextcloud/vm/issues/2542#issuecomment-1700406020
check_command sudo -u www-data php "$NCPATH"/occ maintenance:install \
--data-dir="$NCDATA" \
--database=pgsql \
--database-name=nextcloud_db \
--database-user="$PGDB_USER" \
--database-pass="$PGDB_PASS" \
--admin-user="$GUIUSER" \
--admin-pass="$GUIPASS"
print_text_in_color "$ICyan" "Nextcloud version:"
nextcloud_occ status
sleep 3

# Install PECL dependencies
install_if_not php"$PHPVER"-dev

# Install Redis (distributed cache)
run_script ADDONS redis-server-ubuntu

# Install smbclient
# php"$PHPVER"-smbclient does not yet work in PHP 7.4
install_if_not libsmbclient-dev
yes no | pecl install smbclient
if [ ! -f "$PHP_MODS_DIR"/smbclient.ini ]
then
    touch "$PHP_MODS_DIR"/smbclient.ini
fi
if ! grep -qFx extension=smbclient.so "$PHP_MODS_DIR"/smbclient.ini
then
    echo "# PECL smbclient" > "$PHP_MODS_DIR"/smbclient.ini
    echo "extension=smbclient.so" >> "$PHP_MODS_DIR"/smbclient.ini
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
echo "session.serialize_handler=igbinary"
echo "igbinary.compact_strings=On"
} >> "$PHP_INI"
    if [ ! -f "$PHP_MODS_DIR"/igbinary.ini ]
    then
        touch "$PHP_MODS_DIR"/igbinary.ini
    fi
    if ! grep -qFx extension=igbinary.so "$PHP_MODS_DIR"/igbinary.ini
    then
        echo "# PECL igbinary" > "$PHP_MODS_DIR"/igbinary.ini
        echo "extension=igbinary.so" >> "$PHP_MODS_DIR"/igbinary.ini
        check_command phpenmod -v ALL igbinary
    fi
restart_webserver
fi

# Prepare cron.php to be run every 5 minutes
crontab -u www-data -l | { cat; echo "*/5  *  *  *  * php -f $NCPATH/cron.php > /dev/null 2>&1"; } | crontab -u www-data -

# Run the updatenotification on a schedule
nextcloud_occ config:system:set upgrade.disable-web --type=bool --value=true
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

# Forget login/session after 30 minutes
nextcloud_occ config:system:set remember_login_cookie_lifetime --value="1800"

# Set logrotate (max 10 MB)
nextcloud_occ config:system:set log_rotate_size --value="10485760"

# Set trashbin retention obligation (save it in trashbin for 60 days or delete when space is needed)
nextcloud_occ config:system:set trashbin_retention_obligation --value="auto, 60"

# Set versions retention obligation (save versions for 180 days or delete when space is needed)
nextcloud_occ config:system:set versions_retention_obligation --value="auto, 180"

# Set activity retention obligation (save activity feed for 120 days, defaults to 365 days otherwise)
nextcloud_occ config:system:set activity_expire_days --value="120"

# Remove simple signup
nextcloud_occ config:system:set simpleSignUpLink.shown --type=bool --value=false

# Set chunk_size for files app to 100MB (defaults to 10MB)
nextcloud_occ config:app:set files max_chunk_size --value="104857600"

# Set product name
if home_sme_server
then
    PRODUCTNAME="Nextcloud HanssonIT Server"
else
    PRODUCTNAME="Nextcloud HanssonIT VM"
fi
if is_app_installed theming
then
    if [ "$(nextcloud_occ config:app:get theming productName)" != "$PRODUCTNAME" ]
    then
        nextcloud_occ config:app:set theming productName --value "$PRODUCTNAME"
    fi
fi

# Enable OPCache for PHP
# https://docs.nextcloud.com/server/14/admin_manual/configuration_server/server_tuning.html#enable-php-opcache
phpenmod opcache
{
echo "# OPcache settings for Nextcloud"
echo "opcache.enable=1"
echo "opcache.enable_cli=1"
echo "opcache.interned_strings_buffer=$opcache_interned_strings_buffer_value"
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
    CURRENTVERSION=$(sudo -u www-data php "$NCPATH"/occ status | grep "versionstring" | awk '{print $3}')
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
if [ ! -f "$SITES_AVAILABLE"/"$HTTP_CONF" ]
then
    touch "$SITES_AVAILABLE/$HTTP_CONF"
    cat << HTTP_CREATE > "$SITES_AVAILABLE/$HTTP_CONF"
<VirtualHost *:80>

### YOUR SERVER ADDRESS ###
#    ServerAdmin admin@example.com
#    ServerName cloud.example.com

### SETTINGS ###
    <FilesMatch "\.php$">
        SetHandler "proxy:unix:/run/php/php$PHPVER-fpm.nextcloud.sock|fcgi://localhost"
    </FilesMatch>

    # Logs
    LogLevel warn
    CustomLog \${APACHE_LOG_DIR}/access.log combined
    ErrorLog \${APACHE_LOG_DIR}/error.log

    # Document root folder
    DocumentRoot $NCPATH

    # The Nextcloud folder
    <Directory $NCPATH>
    Options Indexes FollowSymLinks
    AllowOverride None
    Require all granted
    Satisfy Any
    # This is to include all the Nextcloud rules due to that we use PHP-FPM and .htaccess aren't read
    Include $NCPATH/.htaccess
    </Directory>

    # Deny access to your data directory
    <Directory $NCDATA>
    Require all denied
    </Directory>

    # Deny access to the Nextcloud config folder
    <Directory $NCPATH/config/>
    Require all denied
    </Directory>

    <IfModule mod_dav.c>
    Dav off
    </IfModule>

    # The following lines prevent .htaccess and .htpasswd files from being viewed by Web clients.
    <Files ".ht*">
    Require all denied
    </Files>

    SetEnv HOME $NCPATH
    SetEnv HTTP_HOME $NCPATH
    
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
</VirtualHost>
HTTP_CREATE
    print_text_in_color "$IGreen" "$SITES_AVAILABLE/$HTTP_CONF was successfully created."
fi

# Fix zero file sizes
# See https://github.com/nextcloud/server/issues/3056
if version 22.04 "$DISTRO" 26.04.10
then
    SETENVPROXY="SetEnv proxy-sendcl 1"
fi

# Generate $TLS_CONF
if [ ! -f "$SITES_AVAILABLE"/"$TLS_CONF" ]
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

    # Document root folder
    DocumentRoot $NCPATH

    # The Nextcloud folder
    <Directory $NCPATH>
    Options Indexes FollowSymLinks
    AllowOverride None
    Require all granted
    Satisfy Any
    # This is to include all the Nextcloud rules due to that we use PHP-FPM and .htaccess aren't read
    Include $NCPATH/.htaccess
    </Directory>

    # Deny access to your data directory
    <Directory $NCDATA>
    Require all denied
    </Directory>

    # Deny access to the Nextcloud config folder
    <Directory $NCPATH/config/>
    Require all denied
    </Directory>

    <IfModule mod_dav.c>
    Dav off
    </IfModule>

    # The following lines prevent .htaccess and .htpasswd files from being viewed by Web clients.
    <Files ".ht*">
    Require all denied
    </Files>

    SetEnv HOME $NCPATH
    SetEnv HTTP_HOME $NCPATH
    
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
    
    # Avoid zero byte files (only works in Ubuntu 22.04 -->>)
    $SETENVPROXY

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
"PDFViewer" "" ON \
"Extract" "" ON \
"Text" "" ON \
"Mail" "" ON \
"Deck" "" ON \
"Collectives" "" ON \
"Suspicios Login detetion" "" ON \
"IssueTemplate" "" OFF \
"Group-Folders" "" OFF 3>&1 1>&2 2>&3)
fi

case "$choice" in
    *"Calendar"*)
        install_and_enable_app calendar
    ;;&
    *"Contacts"*)
        install_and_enable_app contacts
    ;;&
    *"IssueTemplate"*)
        # install_and_enable_app issuetemplate
        rm -rf "$NCPATH"apps/issuetemplate
        nextcloud_occ app:install --force --keep-disabled issuetemplate
        sed -i "s|20|${CURRENTVERSION%%.*}|g" "$NCPATH"/apps/issuetemplate/appinfo/info.xml
        nextcloud_occ_no_check app:enable issuetemplate
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
    *"Collectives"*)
        install_and_enable_app collectives
        install_if_not php"$PHPVER"-sqlite3
    ;;&
    *"Suspicios Login detetion"*)
        install_and_enable_app suspicios_login
    ;;&
    *"Group-Folders"*)
        install_and_enable_app groupfolders
    ;;&
    *)
    ;;
esac

# Cleanup
apt-get autoremove -y
apt-get autoclean
find /root "/home/$UNIXUSER" -type f \( -name '*.sh*' -o -name '*.html*' -o -name '*.tar*' -o -name '*.zip*' \) -delete

# Install virtual kernels for Hyper-V, (and extra for UTF8 kernel module + Collabora and OnlyOffice)
# Kernel 5.4
if ! home_sme_server
then
    if [ "$SYSVENDOR" == "Microsoft Corporation" ]
    then
        # Hyper-V
        install_if_not linux-virtual
        install_if_not linux-image-virtual
        install_if_not linux-tools-virtual
        install_if_not linux-cloud-tools-virtual
        install_if_not linux-azure
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

# Fix GRUB defaults
if grep -q 'GRUB_CMDLINE_LINUX_DEFAULT="maybe-ubiquity"' /etc/default/grub
then
    sed -i "s|GRUB_CMDLINE_LINUX_DEFAULT=.*|GRUB_CMDLINE_LINUX_DEFAULT=|g" /etc/default/grub
fi

# Set secure permissions final (./data/.htaccess has wrong permissions otherwise)
bash "$SECURE" & spinner_loading

# Put IP address in /etc/issue (shown before the login)
if [ -f /etc/issue ]
then
   printf '%s\n' "\4" >> /etc/issue
fi

# Fix Realtek on PN51
if asuspn51
then
    if ! version 22.04 "$DISTRO" 22.04.10
    then
        # Upgrade Realtek drivers
        print_text_in_color "$ICyan" "Upgrading Realtek firmware..."
        curl_to_dir https://raw.githubusercontent.com/nextcloud/vm/master/network/asusnuc pn51.sh "$SCRIPTS"
        bash "$SCRIPTS"/pn51.sh
    fi
fi

# Update if it's the Home/SME Server
if home_sme_server
then
    # Upgrade system
    print_text_in_color "$ICyan" "System will now upgrade..."
    run_script STATIC update
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

print_text_in_color "$ICyan" "Getting scripts from GitHub to be able to run the first setup..."

# Get needed scripts for first bootup
download_script GITHUB_REPO nextcloud-startup-script
download_script STATIC instruction
download_script STATIC history
download_script NETWORK static_ip
# Moved from the startup script 2021-01-04
download_script LETS_ENC activate-tls
download_script STATIC update
download_script STATIC setup_secure_permissions_nextcloud
download_script STATIC change_db_pass
download_script STATIC nextcloud
download_script MENU menu
download_script MENU server_configuration
download_script MENU nextcloud_configuration
download_script MENU additional_apps
download_script MENU desec_menu

# Make $SCRIPTS excutable
chmod +x -R "$SCRIPTS"
chown root:root -R "$SCRIPTS"

# Prepare first bootup
check_command run_script STATIC change-ncadmin-profile
check_command run_script STATIC change-root-profile

# Disable hibernation
print_text_in_color "$ICyan" "Disable hibernation..."
systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target

# Reboot
if [ -z "$PROVISIONING" ]
then
    msg_box "Installation almost done, system will reboot when you hit OK.

After reboot, please login to run the setup script."
fi
reboot
