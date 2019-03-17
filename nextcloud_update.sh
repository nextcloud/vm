#!/bin/bash
# shellcheck disable=2034,2059
true
# shellcheck source=lib.sh
NCDB=1 && NC_UPDATE=1 . <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)
unset NC_UPDATE
unset NCDB

# T&M Hansson IT AB © - 2019, https://www.hanssonit.se/

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/snap/bin

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

# Update docker-ce to overlay2 since devicemapper is deprecated
if [ -f /etc/systemd/system/docker.service ]
then
    if grep -q "devicemapper" /etc/systemd/system/docker.service
    then
        print_text_in_color "$ICyan" "Changing to Overlay2 for Docker CE..."
        print_text_in_color "$ICyan" "Please report any issues to $ISSUES."
        run_static_script docker_overlay2
    elif grep -q "aufs" /etc/default/docker
    then
        apt-mark hold docker-ce
        run_static_script docker_overlay2
    fi
fi

apt update -q4 & spinner_loading
export DEBIAN_FRONTEND=noninteractive ; apt dist-upgrade -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"
if which mysql > /dev/null
then
    apt-mark unhold mariadb*
echo
print_text_in_color "$ICyan" "If you want to upgrade MariaDB, please run 'sudo apt update && sudo apt dist-upgrade -y'"
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
print_text_in_color "$ICyan" "Trying to upgrade the Redis PECL extension..."
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
    # Check if redis.so is enabled
    # PHP 7.0 apache
    if [ -f /etc/php/7.0/apache2/php.ini ]
    then
        ! [[ "$(grep -R extension=redis.so /etc/php/7.0/apache2/php.ini)" == "extension=redis.so" ]]  > /dev/null 2>&1 && echo "extension=redis.so" >> /etc/php/7.0/apache2/php.ini
    # PHP 7.2 apache
    elif [ -f /etc/php/7.2/apache2/php.ini ]
    then
        ! [[ "$(grep -R extension=redis.so /etc/php/7.2/apache2/php.ini)" == "extension=redis.so" ]]  > /dev/null 2>&1 && echo "extension=redis.so" >> /etc/php/7.2/apache2/php.ini
    # PHP 7.2 fpm
    elif [ -f "$PHP_INI" ]
    then
        ! [[ "$(grep -R extension=redis.so "$PHP_INI")" == "extension=redis.so" ]]  > /dev/null 2>&1 && echo "extension=redis.so" >> "$PHP_INI"
    fi
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
    # Check if redis.so is enabled
    # PHP 7.0 apache
    if [ -f /etc/php/7.0/apache2/php.ini ]
    then
        ! [[ "$(grep -R extension=redis.so /etc/php/7.0/apache2/php.ini)" == "extension=redis.so" ]]  > /dev/null 2>&1 && echo "extension=redis.so" >> /etc/php/7.0/apache2/php.ini
    # PHP 7.2 apache
    elif [ -f /etc/php/7.2/apache2/php.ini ]
    then
        ! [[ "$(grep -R extension=redis.so /etc/php/7.2/apache2/php.ini)" == "extension=redis.so" ]]  > /dev/null 2>&1 && echo "extension=redis.so" >> /etc/php/7.2/apache2/php.ini
    # PHP 7.2 fpm
    elif [ -f "$PHP_INI" ]
    then
        ! [[ "$(grep -R extension=redis.so "$PHP_INI")" == "extension=redis.so" ]]  > /dev/null 2>&1 && echo "extension=redis.so" >> "$PHP_INI"
    fi
    restart_webserver
fi

# Update adminer
if [ -d $ADMINERDIR ]
then
    print_text_in_color "$ICyan" "Updating Adminer..."
    rm -f "$ADMINERDIR"/latest.php "$ADMINERDIR"/adminer.php
    wget -q "http://www.adminer.org/latest.php" -O "$ADMINERDIR"/latest.php
    ln -s "$ADMINERDIR"/latest.php "$ADMINERDIR"/adminer.php
fi

# Update ALL Docker images automatically with watchtower:
if [ "$(docker ps -a >/dev/null 2>&1 && echo yes || echo no)" == "yes" ]
then
    cont_name=watchtower
    if ! docker ps -a --format '{{.Names}}' | grep -Eq "^${cont_name}\$";
    then
        docker run -d --restart=unless-stopped --name watchtower -v /var/run/docker.sock:/var/run/docker.sock v2tec/watchtower --cleanup --interval 3600
    fi
fi

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
CURRUSR="$(getent group sudo | cut -d: -f4 | cut -d, -f1)"
if grep -q "6.ifcfg.me" $SCRIPTS/nextcloud.sh &>/dev/null
then
   rm -f "$SCRIPTS/nextcloud.sh"
   download_static_script nextcloud
   chown "$CURRUSR":"$CURRUSR" "$SCRIPTS/nextcloud.sh"
   chmod +x "$SCRIPTS/nextcloud.sh"
elif [ -f $SCRIPTS/techandme.sh ]
then
   rm -f "$SCRIPTS/techandme.sh"
   download_static_script nextcloud
   chown "$CURRUSR":"$CURRUSR" "$SCRIPTS/nextcloud.sh"
   chmod +x "$SCRIPTS/nextcloud.sh"
   if [ -f /home/"$CURRUSR"/.bash_profile ]
   then
       sed -i "s|techandme|nextcloud|g" /home/"$CURRUSR"/.bash_profile
   elif [ -f /home/"$CURRUSR"/.profile ]
   then
       sed -i "s|techandme|nextcloud|g" /home/"$CURRUSR"/.profile
   fi
fi

# Set secure permissions
if [ ! -f "$SECURE" ]
then
    mkdir -p "$SCRIPTS"
    download_static_script setup_secure_permissions_nextcloud
    chmod +x "$SECURE"
fi

# Update all Nextcloud apps
if [ "${CURRENTVERSION%%.*}" -ge "15" ]
then
    occ_command app:update --all
fi

# Change simple signup
if grep -r "free account" "$NCPATH"/core/templates/layout.public.php
then
    sed -i "s|https://nextcloud.com/signup/|https://www.hanssonit.se/nextcloud-vm/|g" "$NCPATH"/core/templates/layout.public.php
    sed -i "s|Get your own free account|Get your own free Nextcloud VM|g" "$NCPATH"/core/templates/layout.public.php
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
    print_text_in_color "$ICyan" "Latest release is: $NCVERSION. Current version is: $CURRENTVERSION."
	print_text_in_color "$IGreen" "New version available! Upgrade continues..."
else
    print_text_in_color "$ICyan" "Latest version is: $NCVERSION. Current version is: $CURRENTVERSION."
	print_text_in_color "$ICyan" "No need to upgrade, this script will exit..."
    exit 0
fi

# Upgrade Nextcloud
print_text_in_color "$ICyan" "Checking latest released version on the Nextcloud download server and if it's possible to download..."
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
        print_text_in_color "$ICyan" "Doing pgdump of $NCCONFIGDB..."
        check_command sudo -u postgres pg_dump "$NCCONFIGDB"  > "$BACKUP"/nextclouddb.sql
    else
        print_text_in_color "$ICyan" "Doing pgdump of all databases..."
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
    print_text_in_color "$ICyan" "Doing mysqldump of $NCCONFIGDB..."
    check_command mysqldump -u root -p"$MARIADBMYCNFPASS" -d "$NCCONFIGDB" > "$BACKUP"/nextclouddb.sql
else
    print_text_in_color "$ICyan" "Doing mysqldump of all databases..."
    check_command mysqldump -u root -p"$MARIADBMYCNFPASS" -d --all-databases > "$BACKUP"/alldatabases.sql
fi
}

# Do the actual backup
if which mysql > /dev/null
then
    mariadb_backup
fi

# Check if backup exists and move to old
print_text_in_color "$ICyan" "Backing up data..."
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
for folders in config apps
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
    printf "${IGreen}\nBackup OK!${Color_Off}\n"
fi

# Download and validate Nextcloud package
check_command download_verify_nextcloud_stable

if [ -f "$HTML/$STABLEVERSION.tar.bz2" ]
then
    print_text_in_color "$ICyan" "$HTML/$STABLEVERSION.tar.bz2 exists"
else
    msg_box "Aborting, something went wrong with the download"
    exit 1
fi

if [ -d $BACKUP/config/ ]
then
    print_text_in_color "$ICyan" "$BACKUP/config/ exists"
else
msg_box "Something went wrong with backing up your old nextcloud instance
Please check in $BACKUP if config/ folder exist."
    exit 1
fi

if [ -d $BACKUP/apps/ ]
then
    print_text_in_color "$ICyan" "$BACKUP/apps/ exists"
    echo 
    printf "${IGreen}All files are backed up.${Color_Off}\n"
    occ_command maintenance:mode --on
    countdown "Removing old Nextcloud instance in 5 seconds..." "5"
    rm -rf $NCPATH
    tar -xjf "$HTML/$STABLEVERSION.tar.bz2" -C "$HTML"
    rm "$HTML/$STABLEVERSION.tar.bz2"
    cp -R $BACKUP/config "$NCPATH"/
    bash $SECURE & spinner_loading
    occ_command maintenance:mode --off
    occ_command upgrade
    # Optimize
    print_text_in_color "$ICyan" "Optimizing Nextcloud..."
    yes | occ_command db:convert-filecache-bigint
    occ_command db:add-missing-indices
else
msg_box "Something went wrong with backing up your old nextcloud instance
Please check in $BACKUP if the folders exist."
    exit 1
fi

# Start Apache2
start_if_stopped apache2

# Recover apps that exists in the backed up apps folder
run_static_script recover_apps

# Enable Apps
if [ -d "$SNAPDIR" ]
then
    run_app_script spreedme
fi

# Remove header for Nextcloud 14 (already in .htaccess)
if [ -f /etc/apache2/sites-available/"$(hostname -f)".conf ]
then
    if grep -q 'Header always set Referrer-Policy' /etc/apache2/sites-available/"$(hostname -f)".conf
    then
        sed -i '/Header always set Referrer-Policy/d' /etc/apache2/sites-available/"$(hostname -f)".conf
        restart_webserver
    fi
fi

# Change owner of $BACKUP folder to root
chown -R root:root "$BACKUP"

# Pretty URLs
print_text_in_color "$ICyan" "Setting RewriteBase to \"/\" in config.php..."
chown -R www-data:www-data "$NCPATH"
occ_command config:system:set htaccess.RewriteBase --value="/"
occ_command maintenance:update:htaccess
bash "$SECURE"

# Set max upload in Nextcloud .htaccess
configure_max_upload

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
