#!/bin/bash
# shellcheck disable=2034,2059
true
# shellcheck source=lib.sh
NCDB=1 && NC_UPDATE=1 . <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)
unset NC_UPDATE
unset NCDB

# T&M Hansson IT AB © - 2018, https://www.hanssonit.se/

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/snap/bin

# Put your theme name here:
THEME_NAME=""

# Must be root
root_check

# Check if dpkg or apt is running
is_process_running apt
is_process_running dpkg

# System Upgrade
if which mysql > /dev/null
then
    apt-mark hold mariadb*
fi

# Hold docker-ce since it breaks devicemapper
if which docker > /dev/null
then
    apt-mark hold docker-ce
fi

apt update -q4 & spinner_loading
export DEBIAN_FRONTEND=noninteractive ; apt dist-upgrade -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"
if which mysql > /dev/null
then
    apt-mark unhold mariadb*
echo
echo "If you want to upgrade MariaDB, please run 'sudo apt update && sudo apt dist-upgrade -y'"
sleep 2
fi

# Update Netdata
if [ -d /etc/netdata ]
then
    if [ -f /usr/src/netdata.git/netdata-updater.sh ]
    then
        bash /usr/src/netdata.git/netdata-updater.sh
    fi
fi

# Update Redis PHP extension
echo "Trying to upgrade the Redis PECL extenstion..."
if ! pecl list | grep redis >/dev/null 2>&1
then
    if dpkg -l | grep php7.2 > /dev/null 2>&1
    then
        install_if_not php7.2-dev
    else
        install_if_not php7.0-dev
    fi
    apt purge php-redis -y
    apt autoremove -y
    pecl channel-update pecl.php.net
    yes no | pecl install redis
    service redis-server restart
    restart_webserver
elif pecl list | grep redis >/dev/null 2>&1
then
    if dpkg -l | grep php7.2 > /dev/null 2>&1
    then
        install_if_not php7.2-dev
    else
        install_if_not php7.0-dev
    fi
    pecl channel-update pecl.php.net
    yes no | pecl upgrade redis
    service redis-server restart
    restart_webserver
fi

# Update adminer
if [ -d $ADMINERDIR ]
then
    echo "Updating Adminer..."
    rm -f "$ADMINERDIR"/latest.php "$ADMINERDIR"/adminer.php
    wget -q "http://www.adminer.org/latest.php" -O "$ADMINERDIR"/latest.php
    ln -s "$ADMINERDIR"/latest.php "$ADMINERDIR"/adminer.php
fi

# Update docker images
# This updates ALL Docker images:
if [ "$(docker ps -a >/dev/null 2>&1 && echo yes || echo no)" == "yes" ]
then
    docker images --format "{{.Repository}}:{{.Tag}}" | grep :latest | xargs -L1 docker pull
fi

## OLD WAY ##
#if [ "$(docker image inspect onlyoffice/documentserver >/dev/null 2>&1 && echo yes || echo no)" == "yes" ]
#then
#    echo "Updating Docker container for OnlyOffice..."
#    docker pull onlyoffice/documentserver
#fi
#
#if [ "$(docker image inspect collabora/code >/dev/null 2>&1 && echo yes || echo no)" == "yes" ]
#then
#    echo "Updating Docker container for Collabora..."
#    docker pull collabora/code
#fi

# Cleanup un-used packages
apt autoremove -y
apt autoclean

# Update GRUB, just in case
update-grub

# Remove update lists
rm /var/lib/apt/lists/* -r

# Nextcloud 13 is required.
lowest_compatible_nc 13

# Fix bug in nextcloud.sh
if grep "https://6.ifcfg.me" $SCRIPTS/nextcloud.sh
then
   sed -i "s|https://6.ifcfg.me|https://ipv6bot.whatismyipaddress.com|g" $SCRIPTS/nextcloud.sh
fi

# Set secure permissions
if [ ! -f "$SECURE" ]
then
    mkdir -p "$SCRIPTS"
    download_static_script setup_secure_permissions_nextcloud
    chmod +x "$SECURE"
elif grep "postgresql" "$SECURE"
then
    mkdir -p "$SCRIPTS"
    rm "$SCRIPTS"/setup_secure_permissions_nextcloud.*
    download_static_script setup_secure_permissions_nextcloud
    chmod +x "$SECURE"
fi

# Major versions unsupported
if [ "${CURRENTVERSION%%.*}" == "$NCBAD" ]
then
msg_box "Please note that updates between multiple major versions are unsupported! Your situation is:
Current version: $CURRENTVERSION
Latest release: $NCVERSION

It is best to keep your Nextcloud server upgraded regularly, and to install all point releases
and major releases without skipping any of them, as skipping releases increases the risk of
errors. Major releases are 9, 10, 11 and 12. Point releases are intermediate releases for each
major release. For example, 9.0.52 and 10.0.2 are point releases.

Please contact T\&M Hansson IT AB to help you with upgrading between major versions.
https://shop.hanssonit.se/product-category/support/"
    exit 1
fi

# Check if new version is larger than current version installed.
if version_gt "$NCVERSION" "$CURRENTVERSION"
then
    echo "Latest release is: $NCVERSION. Current version is: $CURRENTVERSION."
    printf "${Green}New version available! Upgrade continues...${Color_Off}\n"
else
    echo "Latest version is: $NCVERSION. Current version is: $CURRENTVERSION."
    echo "No need to upgrade, this script will exit..."
    exit 0
fi

# Upgrade Nextcloud
echo "Checking latest released version on the Nextcloud download server and if it's possible to download..."
if ! wget -q --show-progress -T 10 -t 2 "$NCREPO/$STABLEVERSION.tar.bz2"
then
msg_box "Nextcloud does not exist. You were looking for: $NCVERSION
Please check available versions here: $NCREPO"
    exit 1
else
    rm -f "$STABLEVERSION.tar.bz2"
fi

countdown "Backing up files and upgrading to Nextcloud $NCVERSION in 10 seconds... Press CTRL+C to abort." "10"

# Stop Apache2
check_command service apache2 stop

# Create backup dir (/mnt/NCBACKUP/)
if [ ! -d "$BACKUP" ]
then
    BACKUP=/var/NCBACKUP
    mkdir -p $BACKUP
fi

# Backup PostgreSQL
if which psql > /dev/null
then
    cd /tmp
    if sudo -u postgres psql -c "SELECT 1 AS result FROM pg_database WHERE datname='$NCCONFIGDB'" | grep "1 row" > /dev/null
    then
        echo "Doing pgdump of $NCCONFIGDB..."
        check_command sudo -u postgres pg_dump "$NCCONFIGDB"  > "$BACKUP"/nextclouddb.sql
    else
        echo "Doing pgdump of all databases..."
        check_command sudo -u postgres pg_dumpall > "$BACKUP"/alldatabases.sql
    fi
fi

# If MariaDB then:
mariadb_backup() {
MYCNF=/root/.my.cnf
MARIADBMYCNFPASS=$(grep "password" $MYCNF | sed -n "/password/s/^password='\(.*\)'$/\1/p")
NCCONFIGDB=$(grep "dbname" $NCPATH/config/config.php | awk '{print $3}' | sed "s/[',]//g")
NCCONFIGDBPASS=$(grep "dbpassword" $NCPATH/config/config.php | awk '{print $3}' | sed "s/[',]//g")
# Path to specific files
# Make sure old instaces can upgrade as well
if [ ! -f "$MYCNF" ] && [ -f /var/mysql_password.txt ]
then
    regressionpw=$(cat /var/mysql_password.txt)
cat << LOGIN > "$MYCNF"
[client]
password='$regressionpw'
LOGIN
    chmod 0600 $MYCNF
    chown root:root $MYCNF
    msg_box "Please restart the upgrade process, we fixed the password file $MYCNF."
    exit 1    
elif [ -z "$MARIADBMYCNFPASS" ] && [ -f /var/mysql_password.txt ]
then
    regressionpw=$(cat /var/mysql_password.txt)
    {
    echo "[client]"
    echo "password='$regressionpw'"
    } >> "$MYCNF"
    msg_box "Please restart the upgrade process, we fixed the password file $MYCNF."
    exit 1    
fi

# Backup MariaDB
if mysql -u root -p"$MARIADBMYCNFPASS" -e "SHOW DATABASES LIKE '$NCCONFIGDB'" > /dev/null
then
    echo "Doing mysqldump of $NCCONFIGDB..."
    check_command mysqldump -u root -p"$MARIADBMYCNFPASS" -d "$NCCONFIGDB" > "$BACKUP"/nextclouddb.sql
else
    echo "Doing mysqldump of all databases..."
    check_command mysqldump -u root -p"$MARIADBMYCNFPASS" -d --all-databases > "$BACKUP"/alldatabases.sql
fi
}

# Do the actual backup
if which mysql > /dev/null
then
    mariadb_backup
fi

# Check if backup exists and move to old
echo "Backing up data..."
DATE=$(date +%Y-%m-%d-%H%M%S)
if [ -d $BACKUP ]
then
    mkdir -p "$BACKUP-OLD/$DATE"
    mv $BACKUP/* "$BACKUP-OLD/$DATE"
    rm -R $BACKUP
    mkdir -p $BACKUP
fi

# Do a backup of the ZFS mount
if dpkg -l | grep libzfs2linux
then
    if grep -r ncdata /etc/mtab
    then
        check_multiverse
        install_if_not zfs-auto-snapshot
        sed -i "s|date --utc|date|g" /usr/sbin/zfs-auto-snapshot
        check_command zfs-auto-snapshot -r ncdata
    fi
fi  
   
# Backup data
for folders in config themes apps
do
    if [[ "$(rsync -Aax $NCPATH/$folders $BACKUP)" -eq 0 ]]
    then
        BACKUP_OK=1
    else
        unset BACKUP_OK
    fi
done

if [ -z $BACKUP_OK ]
then
    msg_box "Backup was not OK. Please check $BACKUP and see if the folders are backed up properly"
    exit 1
else
    printf "${Green}\nBackup OK!${Color_Off}\n"
fi

# Download and validate Nextcloud package
check_command download_verify_nextcloud_stable

if [ -f "$HTML/$STABLEVERSION.tar.bz2" ]
then
    echo "$HTML/$STABLEVERSION.tar.bz2 exists"
else
    msg_box "Aborting, something went wrong with the download"
    exit 1
fi

if [ -d $BACKUP/config/ ]
then
    echo "$BACKUP/config/ exists"
else
msg_box "Something went wrong with backing up your old nextcloud instance
Please check in $BACKUP if config/ folder exist."
    exit 1
fi

if [ -d $BACKUP/apps/ ]
then
    echo "$BACKUP/apps/ exists"
else
msg_box "Something went wrong with backing up your old nextcloud instance
Please check in $BACKUP if apps/ folder exist."
    exit 1
fi

if [ -d $BACKUP/themes/ ]
then
    echo "$BACKUP/themes/ exists"
    echo 
    printf "${Green}All files are backed up.${Color_Off}\n"
    occ_command maintenance:mode --on
    countdown "Removing old Nextcloud instance in 5 seconds..." "5"
    rm -rf $NCPATH
    tar -xjf "$HTML/$STABLEVERSION.tar.bz2" -C "$HTML"
    rm "$HTML/$STABLEVERSION.tar.bz2"
    cp -R $BACKUP/themes "$NCPATH"/
    cp -R $BACKUP/config "$NCPATH"/
    bash $SECURE & spinner_loading
    occ_command maintenance:mode --off
    occ_command upgrade
    # Optimize
    echo "Optimizing Nextcloud..."
    yes | occ_command db:convert-filecache-bigint
    occ_command db:add-missing-indices
else
msg_box "Something went wrong with backing up your old nextcloud instance
Please check in $BACKUP if the folders exist."
    exit 1
fi

# Start Apache2
check_command service apache2 start

# Recover apps that exists in the backed up apps folder
run_static_script recover_apps

# Enable Apps
if [ -d "$SNAPDIR" ]
then
    run_app_script spreedme
fi

# Add header for Nextcloud 14
if [ -f /etc/apache2/sites-available/"$(hostname -f)".conf ]
then
    if ! grep -q 'Header always set Referrer-Policy "strict-origin"' /etc/apache2/sites-available/"$(hostname -f)".conf
    then
        sed -i '/Header add Strict-Transport-Security/a    Header always set Referrer-Policy "strict-origin"' /etc/apache2/sites-available/"$(hostname -f)".conf
        restart_webserver
    fi
fi

# Change owner of $BACKUP folder to root
chown -R root:root "$BACKUP"

# Set max upload in Nextcloud .htaccess
configure_max_upload

# Disable support app
if [ -d $NC_APPS_PATH/support ]
then
    occ_command app:disable support
    rm -rf $NC_APPS_PATH/support
fi

# Set $THEME_NAME
VALUE2="$THEME_NAME"
if ! grep -Fxq "$VALUE2" "$NCPATH/config/config.php"
then
    sed -i "s|'theme' => '',|'theme' => '$THEME_NAME',|g" "$NCPATH"/config/config.php
    echo "Theme set"
fi

# Pretty URLs
echo "Setting RewriteBase to \"/\" in config.php..."
chown -R www-data:www-data "$NCPATH"
occ_command config:system:set htaccess.RewriteBase --value="/"
occ_command maintenance:update:htaccess
bash "$SECURE"

# Update .user.ini in case stuff was added to .htaccess
if [ "$NCPATH/.htaccess" -nt "$NCPATH/.user.ini" ]
then
    cp -fv "$NCPATH/.htaccess" "$NCPATH/.user.ini"
    sed -i 's/  php_value upload_max_filesize.*/# php_value upload_max_filesize 511M/g' "$NCPATH"/.user.ini
    sed -i 's/  php_value post_max_size.*/# php_value post_max_size 511M/g' "$NCPATH"/.user.ini
    sed -i 's/  php_value memory_limit.*/# php_value memory_limit 512M/g' "$NCPATH"/.user.ini
    restart_webserver
fi

# Repair
occ_command maintenance:repair

CURRENTVERSION_after=$(occ_command status | grep "versionstring" | awk '{print $3}')
if [[ "$NCVERSION" == "$CURRENTVERSION_after" ]]
then
msg_box "Latest version is: $NCVERSION. Current version is: $CURRENTVERSION_after.

||| UPGRADE SUCCESS! |||

If you notice that some apps are disabled it's due to that they are not compatible with the new Nextcloud version.
To recover your old apps, please check $BACKUP/apps and copy them to $NCPATH/apps manually.

Thank you for using T&M Hansson IT's updater!"
    occ_command status
    occ_command maintenance:mode --off
    echo "NEXTCLOUD UPDATE success-$(date +"%Y%m%d")" >> /var/log/cronjobs_success.log
    ## Un-hash this if you want the system to reboot
    # reboot
    exit 0
else
msg_box "Latest version is: $NCVERSION. Current version is: $CURRENTVERSION_after.

||| UPGRADE FAILED! |||

Your files are still backed up at $BACKUP. No worries!
Please report this issue to $ISSUES

Maintenance mode is kept on."
occ_command status
    exit 1
fi
