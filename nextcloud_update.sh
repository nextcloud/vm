#!/bin/bash

#################################################################################################################
# DO NOT USE THIS SCRIPT WHEN UPDATING NEXTCLOUD / YOUR SERVER! RUN `sudo bash /var/scripts/update.sh` INSTEAD. #
#################################################################################################################

# shellcheck disable=2034,2059
true
# shellcheck source=lib.sh
NCDB=1 && NC_UPDATE=1 . <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)
unset NC_UPDATE
unset NCDB

# T&M Hansson IT AB © - 2020, https://www.hanssonit.se/

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

# Check if /boot is filled more than 90% and exit the script if that's the case since we don't want to end up with a broken system
if [ -d /boot ]
then
    if [[ "$(df -h | grep /boot | awk '{print $5}' | cut -d "%" -f1)" -gt 90 ]]
    then
msg_box "It seems like your boot drive is filled more than 90%. You can't proceed to upgrade since it probably will break your system

To be able to proceed with the update you need to delete some old Linux kernels. If you need support, please visit:
https://shop.hanssonit.se/product/premium-support-per-30-minutes/"
        exit
    fi
fi

# System Upgrade
if is_this_installed mysql-common
then
    apt-mark hold mysql*
    if is_this_installed mariadb-common
    then
         apt-mark hold mariadb*
    fi
fi

# Hold PHP due to max supported version in Nextcloud
if is_this_installed php7.3-common
then
    apt-mark hold php*
fi

# Move all logs to new dir (2019-09-04)
if [ -d /var/log/ncvm/ ]
then
    rsync -Aaxz /var/log/ncvm/ $VMLOGS
    rm -Rf /var/log/ncvm/
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
if is_this_installed mysql-common
then
    apt-mark unhold mysql*
    print_text_in_color "$ICyan" "If you want to upgrade MySQL/MariaDB, please run 'sudo apt update && sudo apt dist-upgrade -y'"
    sleep 2
    if is_this_installed mariadb-common
    then
        apt-mark unhold mariadb*
        print_text_in_color "$ICyan" "If you want to upgrade MariaDB, please run 'sudo apt update && sudo apt dist-upgrade -y'"
        sleep 2
    fi
fi

# Update Netdata
if [ -d /etc/netdata ]
then
    if [ -f /usr/src/netdata.git/netdata-updater.sh ]
    then
        run_app_script netdata
    elif [ -f /usr/libexec/netdata-updater.sh ]
    then
        bash /usr/libexec/netdata-updater.sh
    fi
fi

# Update Redis PHP extension
print_text_in_color "$ICyan" "Trying to upgrade the Redis PECL extension..."
if version 18.04 "$DISTRO" 18.04.10; then
    if ! pecl list | grep redis >/dev/null 2>&1
    then
        if is_this_installed php"$PHPVER"-common
        then
            install_if_not php"$PHPVER"-dev
        elif is_this_installed php7.0-common
        then
            install_if_not php7.0-dev
        elif is_this_installed php7.1-common
        then
            install_if_not php7.1-dev
        elif is_this_installed php7.3-common
        then
            install_if_not php7.3-dev
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
        # PHP "$PHPVER" apache
        elif [ -f /etc/php/"$PHPVER"/apache2/php.ini ]
        then
            ! [[ "$(grep -R extension=redis.so /etc/php/"$PHPVER"/apache2/php.ini)" == "extension=redis.so" ]]  > /dev/null 2>&1 && echo "extension=redis.so" >> /etc/php/"$PHPVER"/apache2/php.ini
        # PHP "$PHPVER" fpm
        elif [ -f "$PHP_INI" ]
        then
            ! [[ "$(grep -R extension=redis.so "$PHP_INI")" == "extension=redis.so" ]]  > /dev/null 2>&1 && echo "extension=redis.so" >> "$PHP_INI"
        fi
        restart_webserver
    elif pecl list | grep redis >/dev/null 2>&1
    then
        if is_this_installed php"$PHPVER"-common
        then
            install_if_not php"$PHPVER"-dev
        elif is_this_installed php7.0-common
        then
            install_if_not php7.0-dev
        elif is_this_installed php7.1-common
        then
            install_if_not php7.1-dev
        elif is_this_installed php7.3-common
        then
            install_if_not php7.3-dev
        fi
        pecl channel-update pecl.php.net
        yes no | pecl upgrade redis
        service redis-server restart
        # Check if redis.so is enabled
        # PHP 7.0 apache
        if [ -f /etc/php/7.0/apache2/php.ini ]
        then
            ! [[ "$(grep -R extension=redis.so /etc/php/7.0/apache2/php.ini)" == "extension=redis.so" ]]  > /dev/null 2>&1 && echo "extension=redis.so" >> /etc/php/7.0/apache2/php.ini
        # PHP "$PHPVER" apache
        elif [ -f /etc/php/"$PHPVER"/apache2/php.ini ]
        then
            ! [[ "$(grep -R extension=redis.so /etc/php/"$PHPVER"/apache2/php.ini)" == "extension=redis.so" ]]  > /dev/null 2>&1 && echo "extension=redis.so" >> /etc/php/"$PHPVER"/apache2/php.ini
        # PHP "$PHPVER" fpm
        elif [ -f "$PHP_INI" ]
        then
            ! [[ "$(grep -R extension=redis.so "$PHP_INI")" == "extension=redis.so" ]]  > /dev/null 2>&1 && echo "extension=redis.so" >> "$PHP_INI"
        fi
        restart_webserver
    fi
else
    msg_box "Ubuntu version $DISTRO must be at least 18.04 to upgrade Redis."
fi

# Upgrade APCu and igbinary
if [ "${CURRENTVERSION%%.*}" -ge "17" ]
then
    if [ -f "$PHP_INI" ]
    then
        print_text_in_color "$ICyan" "Trying to upgrade igbinary and APCu..."
        if pecl list | grep igbinary >/dev/null 2>&1
        then
            yes no | pecl upgrade igbinary
            # Check if igbinary.so is enabled
            if ! grep -qFx extension=igbinary.so "$PHP_INI"
            then
                echo "extension=igbinary.so" >> "$PHP_INI"
            fi
        fi
        if pecl list | grep apcu >/dev/null 2>&1
        then
            yes no | pecl upgrade apcu
            # Check if apcu.so is enabled
            if ! grep -qFx extension=apcu.so "$PHP_INI"
            then
                echo "extension=apcu.so" >> "$PHP_INI"
            fi
        fi
    fi
fi

# Update adminer
if [ -d $ADMINERDIR ]
then
    print_text_in_color "$ICyan" "Updating Adminer..."
    rm -f "$ADMINERDIR"/latest.php "$ADMINERDIR"/adminer.php
    curl_to_dir "http://www.adminer.org" "latest.php" "$ADMINERDIR"
    ln -s "$ADMINERDIR"/latest.php "$ADMINERDIR"/adminer.php
fi

# Run watchtower to update all Docker images
if is_docker_running
then
    # Remove old watchtower if existing
    if does_this_docker_exist v2tec/watchtower
    then
        # Get Env values (https://github.com/koalaman/shellcheck/issues/1601)
        get_env_values() {
        # shellcheck disable=SC2016
        docker inspect -f '{{range $index, $value := .Config.Env}}{{$value}}{{println}}{{end}}' watchtower > env.list
        }
        get_env_values

        # Remove empty lines
        sed -i '/^[[:space:]]*$/d' env.list

        # Get Cmd values
        CmdDocker=$(docker inspect --format='{{.Config.Cmd}}' watchtower | cut -d "]" -f 1 | cut -d "[" -f 2;)

        # Check if env.list is empty and run the docker accordingly
        if [ -s env.list ]
        then
            docker_prune_this v2tec/watchtower
            docker run -d --restart=unless-stopped --name watchtower -v /var/run/docker.sock:/var/run/docker.sock --env-file ./env.list containrrr/watchtower "$CmdDocker"
            rm -f env.list
        else
            docker_prune_this v2tec/watchtower
            docker run -d --restart=unless-stopped --name watchtower -v /var/run/docker.sock:/var/run/docker.sock containrrr/watchtower "$CmdDocker"
        fi
    fi

    # Get the new watchtower docker
    if ! does_this_docker_exist containrrr/watchtower
    then
        docker run -d --restart=unless-stopped --name watchtower -v /var/run/docker.sock:/var/run/docker.sock containrrr/watchtower --cleanup --interval 3600
    fi
fi

# Cleanup un-used packages
apt autoremove -y
apt autoclean

# Update GRUB, just in case
update-grub

# Remove update lists
rm /var/lib/apt/lists/* -r

# Free some space (ZFS snapshots)
if is_this_installed libzfs2linux
then
    if grep -rq ncdata /etc/mtab
    then
        run_static_script prune_zfs_snaphots
    fi
fi

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
    # Make sure maintenance:mode isn't activated (it will fail if it is)
    occ_command maintenance:mode --off
    # Check for upgrades
    print_text_in_color "$ICyan" "Trying to automatically update all Nextcloud apps..."
    # occ command can not be used due to the check_command() function.
    UPDATED_APPS="$(sudo -u www-data php $NCPATH/occ app:update --all)"
fi

# Check which apps got updated
if [ -n "$UPDATED_APPS" ]
then
    print_text_in_color "$IGreen" "$UPDATED_APPS"
    notify_admin_gui \
    "You've got app updates!" \
    "$UPDATED_APPS"
else
    print_text_in_color "$IGreen" "Your apps are already up to date!"
fi

# Nextcloud 13 is required.
lowest_compatible_nc 13

if [ -f /tmp/minor.version ]
then
    NCBAD=$(cat /tmp/minor.version)
    NCVERSION=$(curl -s -m 900 $NCREPO/ | sed --silent 's/.*href="nextcloud-\([^"]\+\).zip.asc".*/\1/p' | sort --version-sort | grep "${CURRENTVERSION%%.*}" | tail -1)
    export NCVERSION
    export STABLEVERSION="nextcloud-$NCVERSION"
    rm -f /tmp/minor.version
fi

# Major versions unsupported
if [[ "${CURRENTVERSION%%.*}" -le "$NCBAD" ]]
then
msg_box "Please note that updates between multiple major versions are unsupported! Your situation is:
Current version: $CURRENTVERSION
Latest release: $NCVERSION

It is best to keep your Nextcloud server upgraded regularly, and to install all point releases
and major releases without skipping any of them, as skipping releases increases the risk of
errors. Major releases are 13, 14, 15 and 16. Point releases are intermediate releases for each
major release. For example, 14.0.52 and 15.0.2 are point releases.

You can read more about Nextcloud releases here: https://github.com/nextcloud/server/wiki/Maintenance-and-Release-Schedule

Please contact T&M Hansson IT AB to help you with upgrading between major versions.
https://shop.hanssonit.se/product/upgrade-between-major-owncloud-nextcloud-versions/"
    exit 1
fi

# Check if new version is larger than current version installed.
print_text_in_color "$ICyan" "Checking for new Nextcloud version..."
if version_gt "$NCVERSION" "$CURRENTVERSION"
then
    print_text_in_color "$ICyan" "Latest release is: $NCVERSION. Current version is: $CURRENTVERSION."
    print_text_in_color "$IGreen" "New version available, upgrade continues!"
else
    print_text_in_color "$IGreen" "You already run the latest version! ($NCVERSION)"
    exit 0
fi

# Check if PHP version is compatible with $NCVERSION
PHP_VER=71
NC_VER=16
if [ "${NCVERSION%%.*}" -ge "$NC_VER" ]
then
    if [ "$(php -v | head -n 1 | cut -d " " -f 2 | cut -c 1,3)" -lt "$PHP_VER" ]
    then
msg_box "Your PHP version isn't compatible with the new version of Nextcloud. Please upgrade your PHP stack and try again.

If you need support, please visit https://shop.hanssonit.se/product/upgrade-php-version-including-dependencies/"
        exit
    fi
fi

# Upgrade Nextcloud
if ! site_200 $NCREPO
then
msg_box "$NCREPO seems to be down, or temporarily not reachable. Please try again in a few minutes."
    exit 1
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
if is_this_installed postgresql-common
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
if is_this_installed mysql-common && ! is_this_installed postgresql-common
then
    mariadb_backup
elif is_this_installed mariadb-common && ! is_this_installed postgresql-common
then
    mariadb_backup
fi

# Check if backup exists and move to old
print_text_in_color "$ICyan" "Backing up data..."
DATE=$(date +%Y-%m-%d-%H%M%S)
if [ -d "$BACKUP" ]
then
    mkdir -p "$BACKUP"-OLD/"$DATE"
    install_if_not rsync
    rsync -Aaxz "$BACKUP"/ "$BACKUP"-OLD/"$DATE"
    rm -R "$BACKUP"
    mkdir -p "$BACKUP"
fi

# Do a backup of the ZFS mount
if is_this_installed libzfs2linux
then
    if grep -rq ncdata /etc/mtab
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
    if [[ "$(rsync -Aaxz $NCPATH/$folders $BACKUP)" -eq 0 ]]
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
    print_text_in_color "$IGreen" "All files are backed up."
    occ_command maintenance:mode --on
    countdown "Removing old Nextcloud instance in 5 seconds..." "5"
    rm -rf $NCPATH
    print_text_in_color "$IGreen" "Extracting new package...."
    tar -xjf "$HTML/$STABLEVERSION.tar.bz2" -C "$HTML"
    rm "$HTML/$STABLEVERSION.tar.bz2"
    print_text_in_color "$IGreen" "Restoring config to Nextcloud..."
    rsync -Aaxz $BACKUP/config "$NCPATH"/
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

# Update Bitwarden
if [ "$(docker ps -a >/dev/null 2>&1 && echo yes || echo no)" == "yes" ]
then
    if docker ps -a --format '{{.Names}}' | grep -Eq "bitwarden";
    then
        if is_this_installed apache2
        then
            if [ -d /root/bwdata ]
            then
                curl_to_dir "https://raw.githubusercontent.com/bitwarden/server/master/scripts" "bitwarden.sh" "/root"
                if [ -f /root/bitwarden.sh ]
                then
                    print_text_in_color "$IGreen" "Upgrading Bitwarden..."
                    sleep 2
                    bash /root/bitwarden.sh updateself
                    bash /root/bitwarden.sh update
                fi
            fi
        fi
    fi
fi

# Start Apache2
start_if_stopped apache2

# Just double check if the DB is started as well
if is_this_installed postgresql-common
then
    if ! pgrep postgres >/dev/null 2>&1
    then
        print_text_in_color "$ICyan" "Starting PostgreSQL..."
        check_command service postgresql start
    fi
fi

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

# Repair
occ_command maintenance:repair

# Create $VMLOGS dir
if [ ! -d "$VMLOGS" ]
then
    mkdir -p "$VMLOGS"
fi

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
    print_text_in_color "$ICyan" "Sending notification about the successful update to all admins..."
    notify_admin_gui \
    "Nextcloud is now updated!" \
    "Your Nextcloud is updated to $CURRENTVERSION_after with the update script in the Nextcloud VM."
    echo "NEXTCLOUD UPDATE success-$(date +"%Y%m%d")" >> "$VMLOGS"/update.log
    exit 0
else
msg_box "Latest version is: $NCVERSION. Current version is: $CURRENTVERSION_after.

||| UPGRADE FAILED! |||

Your files are still backed up at $BACKUP. No worries!
Please report this issue to $ISSUES

Maintenance mode is kept on."
    notify_admin_gui \
    "Nextcloud update failed!" \
    "Your Nextcloud update failed, please check the logs at $VMLOGS/update.log"
    occ_command status
    exit 1
fi
