#!/bin/bash

#################################################################################################################
# DO NOT USE THIS SCRIPT WHEN UPDATING NEXTCLOUD / YOUR SERVER! RUN `sudo bash /var/scripts/update.sh` INSTEAD. #
#################################################################################################################

true
SCRIPT_NAME="Nextcloud Update Script"
# shellcheck source=lib.sh
source <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)

# Get all needed variables from the library
ncdb
nc_update

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

if does_snapshot_exist "NcVM-snapshot-pending"
then
    msg_box "It seems like the last update was not successful.
Cannot proceed because you would loose the last snapshot."
    exit 1
fi

# Create a snapshot before doing anything else
check_free_space
if ! [ -f "$SCRIPTS/nextcloud-startup-script.sh" ] && (does_snapshot_exist "NcVM-startup" \
|| does_snapshot_exist "NcVM-snapshot" || [ "$FREE_SPACE" -ge 50 ] )
then
    SNAPSHOT_EXISTS=1
    if is_docker_running
    then
        check_command systemctl stop docker
    fi
    nextcloud_occ maintenance:mode --on
    if does_snapshot_exist "NcVM-startup"
    then
        check_command lvremove /dev/ubuntu-vg/NcVM-startup -y
    elif does_snapshot_exist "NcVM-snapshot"
    then
        if ! lvremove /dev/ubuntu-vg/NcVM-snapshot -y
        then
            nextcloud_occ maintenance:mode --off
            start_if_stopped docker
            notify_admin_gui "Update failed!" \
"Could not remove NcVM-snapshot - Please reboot your server! $(date +%T)"
            msg_box "It seems like the old snapshot could not get removed.
This should work again after a reboot of your server."
            exit 1
        fi
    fi
    if ! lvcreate --size 5G --snapshot --name "NcVM-snapshot" /dev/ubuntu-vg/ubuntu-lv
    then
        nextcloud_occ maintenance:mode --off
        start_if_stopped docker
        notify_admin_gui "Update failed!" \
"Could not create NcVM-snapshot - Please reboot your server! $(date +%T)"
        msg_box "The creation of a snapshot failed.
If you just merged and old one, please reboot your server once more. 
It should work afterwards again."
        exit 1
    fi
    nextcloud_occ maintenance:mode --off
    start_if_stopped docker
fi

# Check if /boot is filled more than 90% and exit the script if that's 
# the case since we don't want to end up with a broken system
if [ -d /boot ]
then
    if [[ "$(df -h | grep -m 1 /boot | awk '{print $5}' | cut -d "%" -f1)" -gt 90 ]]
    then
        msg_box "It seems like your boot drive is filled more than 90%. \
You can't proceed to upgrade since it probably will break your system

To be able to proceed with the update you need to delete some old Linux kernels. If you need support, please visit:
https://shop.hanssonit.se/product/premium-support-per-30-minutes/"
        exit
    fi
fi

# Ubuntu 16.04 is deprecated
check_distro_version

# Hold PHP if Ondrejs PPA is used
print_text_in_color "$ICyan" "Fetching latest packages with apt..."
apt update -q4 & spinner_loading
if apt-cache policy | grep "ondrej" >/dev/null 2>&1
then
    print_text_in_color "$ICyan" "Ondrejs PPA is installed. \
Holding PHP to avoid upgrading to a newer version without migration..."
    apt-mark hold php*
fi

# Don't allow MySQL/MariaDB
if ! grep -q pgsql /var/www/nextcloud/config/config.php
then
    msg_box "MySQL/MariaDB is not supported in this script anymore. Please contact us to get support \
for upgrading your server: https://shop.hanssonit.se/product/premium-support-per-30-minutes/"
    exit 0
fi

# Move all logs to new dir (2019-09-04)
if [ -d /var/log/ncvm/ ]
then
    rsync -Aaxz /var/log/ncvm/ $VMLOGS
    rm -Rf /var/log/ncvm/
fi

# Remove the local lib.sh since it's causing issues with new functions (2020-06-01)
if [ -f $SCRIPTS/lib.sh ]
then
    rm -f $SCRIPTS/lib.sh
fi

# Update updatenotification.sh
if [ -f $SCRIPTS/updatenotification.sh ]
then
    download_script STATIC updatenotification
    chmod +x $SCRIPTS/updatenotification.sh
fi

# Make sure everyone gets access to menu.sh
download_script MENU menu

# Make sure fetch_lib.sh is available
download_script STATIC fetch_lib

# Update docker-ce to overlay2 since devicemapper is deprecated
if [ -f /etc/systemd/system/docker.service ]
then
    if grep -q "devicemapper" /etc/systemd/system/docker.service
    then
        print_text_in_color "$ICyan" "Changing to Overlay2 for Docker CE..."
        print_text_in_color "$ICyan" "Please report any issues to $ISSUES."
        run_script STATIC docker_overlay2
    elif grep -q "aufs" /etc/default/docker
    then
        apt-mark hold docker-ce
        run_script STATIC docker_overlay2
    fi
fi

export DEBIAN_FRONTEND=noninteractive ; apt dist-upgrade -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"

# Update Netdata
if [ -d /etc/netdata ]
then
    print_text_in_color "$ICyan" "Updating Netdata..."
    NETDATA_UPDATER_PATH="$(find /usr -name 'netdata-updater.sh')"
    if [ -n "$NETDATA_UPDATER_PATH" ]
    then
        install_if_not cmake # Needed for Netdata in newer versions
        bash "$NETDATA_UPDATER_PATH"
    fi
fi

# Update Redis PHP extension (18.04 --> 20.04 since 16.04 already is deprecated in the top of this script)
print_text_in_color "$ICyan" "Trying to upgrade the Redis PECL extension..."

# Check current PHP version
check_php

# Do the upgrade
if pecl list | grep redis >/dev/null 2>&1
then
    if is_this_installed php"$PHPVER"-common
    then
        install_if_not php"$PHPVER"-dev
    fi
    pecl channel-update pecl.php.net
    yes no | pecl upgrade redis
    systemctl restart redis-server.service
fi

# Double check if redis.so is enabled
if ! grep -qFx extension=redis.so "$PHP_INI"
then
    echo "extension=redis.so" >> "$PHP_INI"
fi
restart_webserver

# Upgrade APCu and igbinary
if [ "${CURRENTVERSION%%.*}" -ge "17" ]
then
    if [ -f "$PHP_INI" ]
    then
        print_text_in_color "$ICyan" "Trying to upgrade igbinary, smbclient, and APCu..."
        if pecl list | grep igbinary >/dev/null 2>&1
        then
            yes no | pecl upgrade igbinary
            # Check if igbinary.so is enabled
            if ! grep -qFx extension=igbinary.so "$PHP_INI"
            then
                echo "extension=igbinary.so" >> "$PHP_INI"
            fi
        fi
        if pecl list | grep -q smbclient
        then
            yes no | pecl upgrade smbclient
            # Check if smbclient is enabled and create the file if not
            if [ ! -f $PHP_MODS_DIR/smbclient.ini ]
            then
               touch $PHP_MODS_DIR/smbclient.ini
            fi
            # Enable new smbclient
            if ! grep -qFx extension=smbclient.so $PHP_MODS_DIR/smbclient.ini
            then
                echo "# PECL smbclient" > $PHP_MODS_DIR/smbclient.ini
                echo "extension=smbclient.so" >> $PHP_MODS_DIR/smbclient.ini
                check_command phpenmod -v ALL smbclient
            fi
            # Remove old smbclient
            if grep -qFx extension=smbclient.so "$PHP_INI"
            then
                sed -i "s|extension=smbclient.so||g" "$PHP_INI"
            fi
        fi
        if pecl list | grep -q apcu
        then
            yes no | pecl upgrade apcu
            # Check if apcu.so is enabled
            if ! grep -qFx extension=apcu.so "$PHP_INI"
            then
                echo "extension=apcu.so" >> "$PHP_INI"
            fi
        fi
        if pecl list | grep -q inotify
        then 
            yes no | pecl upgrade inotify
            # Check if inotify.so is enabled
            if ! grep -qFx extension=inotify.so "$PHP_INI"
            then
                echo "extension=inotify.so" >> "$PHP_INI"
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

# Get newest dat files for geoblock.sh
if grep -q "^#Geoip-block" /etc/apache2/apache2.conf
then
    get_newest_dat_files
    check_command systemctl restart apache2
fi

# Update docker containers and remove Watchtower if Bitwarden is preseent due to compatibility issue
# If Watchtower is installed, but Bitwarden is missing, then let watchtower do its thing
# If Watchtower is installed together with Bitwarden, then remove Watchtower and run updates 
# individually dependning on which docker containers that exist.
if is_docker_running
then
    # To fix https://github.com/nextcloud/vm/issues/1459 we need to remove Watchtower 
    # to avoid updating Bitwarden again, and only update the specified docker images above
    if docker ps -a --format '{{.Names}}' | grep -Eq "bitwarden";
    then
        if [ -d /root/bwdata ] || [ -d "$BITWARDEN_HOME"/bwdata ]
        then
            if does_this_docker_exist 'containrrr/watchtower'
            then
                docker stop watchtower
            elif does_this_docker_exist 'v2tec/watchtower'
            then
                docker stop watchtower
            fi
            docker container prune -f
            docker image prune -a -f
            docker volume prune -f
            notify_admin_gui "Watchtower removed" "Due to compability issues with Bitwarden and Watchtower, \
we have removed Watchtower from this server. Updates will now happen for each container seperatly instead."
        fi
    fi
    # Update selected images
    # Bitwarden RS
    docker_update_specific 'bitwardenrs/server' "Bitwarden RS"
    # Collabora CODE
    docker_update_specific 'collabora/code' 'Collabora'
    # OnlyOffice
    docker_update_specific 'onlyoffice/documentserver' 'OnlyOffice'
    # Full Text Search
    docker_update_specific 'ark74/nc_fts' 'Full Text Search'
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
        run_script DISK prune_zfs_snaphots
    fi
fi

# Fix bug in nextcloud.sh
CURRUSR="$(getent group sudo | cut -d: -f4 | cut -d, -f1)"
if grep -q "6.ifcfg.me" $SCRIPTS/nextcloud.sh &>/dev/null
then
   rm -f "$SCRIPTS/nextcloud.sh"
   download_script STATIC nextcloud
   chown "$CURRUSR":"$CURRUSR" "$SCRIPTS/nextcloud.sh"
   chmod +x "$SCRIPTS/nextcloud.sh"
elif [ -f $SCRIPTS/techandme.sh ]
then
   rm -f "$SCRIPTS/techandme.sh"
   download_script STATIC nextcloud
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
    download_script STATIC setup_secure_permissions_nextcloud
    chmod +x "$SECURE"
else
    rm "$SECURE"
    download_script STATIC setup_secure_permissions_nextcloud
    chmod +x "$SECURE"
fi

# Update all Nextcloud apps
if [ "${CURRENTVERSION%%.*}" -ge "15" ]
then
    nextcloud_occ maintenance:mode --off
    # Check for upgrades
    print_text_in_color "$ICyan" "Trying to automatically update all Nextcloud apps..."
    UPDATED_APPS="$(nextcloud_occ_no_check app:update --all)"
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
elif [ -f /tmp/prerelease.version ]
then
    PRERELEASE_VERSION=yes
    msg_box "WARNING! You are about to update to a Beta/RC version of Nextcloud.\nThere's no turning back, \
because it's not possible to downgrade.\n\nPlease only continue if you have made a backup, or took a snapshot."
    if ! yesno_box_no "Do you really want to do this?"
    then
        rm -f /tmp/prerelease.version
        unset PRERELEASE_VERSION
    else
        if grep -q beta /tmp/prerelease.version
        then
            NCREPO="https://download.nextcloud.com/server/prereleases"
            NCVERSION=$(curl -s -m 900 $NCREPO/ | sed --silent 's/.*href="nextcloud-\([^"]\+\).zip.asc".*/\1/p' | sort --version-sort | tail -1)
            STABLEVERSION="nextcloud-$NCVERSION"
            rm -f /tmp/prerelease.version
        elif grep -q RC /tmp/prerelease.version
        then
            NCREPO="https://download.nextcloud.com/server/prereleases"
            NCVERSION=$(cat /tmp/prerelease.version)
            STABLEVERSION="nextcloud-$NCVERSION"
            rm -f /tmp/prerelease.version
        fi
    fi
fi

# Major versions unsupported
if [[ "${CURRENTVERSION%%.*}" -le "$NCBAD" ]]
then
    msg_box "Please note that updates between multiple major versions are unsupported! Your situation is:
Current version: $CURRENTVERSION
Latest release: $NCVERSION

It is best to keep your Nextcloud server upgraded regularly, and to install all point releases
and major releases without skipping any of them, as skipping releases increases the risk of
errors. Major releases are 16, 17, 18 and 19. Point releases are intermediate releases for each
major release. For example, 18.0.5 and 19.0.2 are point releases.

You can read more about Nextcloud releases here: https://github.com/nextcloud/server/wiki/Maintenance-and-Release-Schedule

Please contact T&M Hansson IT AB to help you with upgrading between major versions.
https://shop.hanssonit.se/product/upgrade-between-major-owncloud-nextcloud-versions/"
    exit 1
fi

# Check if new version is larger than current version installed. Skip version check if you want to upgrade to a prerelease.
if [ -z "$PRERELEASE_VERSION" ]
then
    print_text_in_color "$ICyan" "Checking for new Nextcloud version..."
    if version_gt "$NCVERSION" "$CURRENTVERSION"
    then
        print_text_in_color "$ICyan" "Latest release is: $NCVERSION. Current version is: $CURRENTVERSION."
        print_text_in_color "$IGreen" "New version available, upgrade continues!"
    else
        print_text_in_color "$IGreen" "You already run the latest version! ($CURRENTVERSION)"
        exit 0
    fi
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

# Check if PHP version is compatible with $NCVERSION
PHP_VER=72
NC_VER=20
if [ "${NCVERSION%%.*}" -ge "$NC_VER" ]
then
    if [ "$(php -v | head -n 1 | cut -d " " -f 2 | cut -c 1,3)" -lt "$PHP_VER" ]
    then
        msg_box "Your PHP version isn't compatible with the new version of Nextcloud. Please upgrade your PHP stack and try again.

If you need support, please visit https://shop.hanssonit.se/product/upgrade-php-version-including-dependencies/"
        exit
    fi
fi

# Check if PHP version is compatible with $NCVERSION
PHP_VER=73
NC_VER=21
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

# Backup app status
# Fixing https://github.com/nextcloud/server/issues/4538
print_text_in_color "$ICyan" "Getting and backing up the status of apps for later, this might take a while..."
NC_APPS="$(nextcloud_occ app:list | awk '{print$2}' | tr -d ':' | sed '/^$/d')"
if [ -z "$NC_APPS" ]
then
    print_text_in_color "$IRed" "No apps detected, aborting export of app status... Please report this issue to $ISSUES"
    APPSTORAGE="no-export-done"
else
    declare -Ag APPSTORAGE
    for app in $NC_APPS
    do
        APPSTORAGE[$app]=$(nextcloud_occ_no_check config:app:get "$app" enabled)
    done
fi

# Stop Apache2
check_command systemctl stop apache2.service

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
if is_this_installed zfs-auto-snapshot
then
    if grep -rq ncdata /etc/mtab
    then
        check_multiverse
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
    send_mail \
    "Nextcloud update started!" \
    "Please don't shutdown or reboot your server during the update! $(date +%T)"
    nextcloud_occ maintenance:mode --on
    countdown "Removing old Nextcloud instance in 5 seconds..." "5"
    if [ -n "$SNAPSHOT_EXISTS" ]
    then
        check_command lvrename /dev/ubuntu-vg/NcVM-snapshot /dev/ubuntu-vg/NcVM-snapshot-pending
    fi
    rm -rf $NCPATH
    print_text_in_color "$IGreen" "Extracting new package...."
    check_command tar -xjf "$HTML/$STABLEVERSION.tar.bz2" -C "$HTML"
    rm "$HTML/$STABLEVERSION.tar.bz2"
    print_text_in_color "$IGreen" "Restoring config to Nextcloud..."
    rsync -Aaxz $BACKUP/config "$NCPATH"/
    bash $SECURE & spinner_loading
    nextcloud_occ maintenance:mode --off
    nextcloud_occ upgrade
    # Optimize
    print_text_in_color "$ICyan" "Optimizing Nextcloud..."
    yes | nextcloud_occ db:convert-filecache-bigint
    nextcloud_occ db:add-missing-indices
    CURRENTVERSION=$(sudo -u www-data php $NCPATH/occ status | grep "versionstring" | awk '{print $3}')
    if [ "${CURRENTVERSION%%.*}" -ge "19" ]
    then
        check_php
        nextcloud_occ db:add-missing-columns
        install_if_not php"$PHPVER"-bcmath
    fi
else
    msg_box "Something went wrong with backing up your old nextcloud instance
Please check in $BACKUP if the folders exist."
    exit 1
fi

# Update Bitwarden
if is_docker_running
then
    if docker ps -a --format '{{.Names}}' | grep -Eq "bitwarden";
    then
        if is_this_installed apache2
        then
            if [ -d /root/bwdata ]
            then
                curl_to_dir "https://raw.githubusercontent.com/bitwarden/server/master/scripts" "bitwarden.sh" "/root"
                chmod +x /root/bitwarden.sh
                if [ -f /root/bitwarden.sh ]
                then
                    print_text_in_color "$IGreen" "Upgrading Bitwarden..."
                    sleep 2
                    yes no | bash /root/bitwarden.sh updateself
                    yes no | bash /root/bitwarden.sh update
                fi
            elif [ -d "$BITWARDEN_HOME"/bwdata ]
            then
                curl_to_dir "https://raw.githubusercontent.com/bitwarden/server/master/scripts" "bitwarden.sh" "$BITWARDEN_HOME"
                chown "$BITWARDEN_USER":"$BITWARDEN_USER" "$BITWARDEN_HOME"/bitwarden.sh
                chmod +x "$BITWARDEN_HOME"/bitwarden.sh
                if [ -f "$BITWARDEN_HOME"/bitwarden.sh ]
                then
                    print_text_in_color "$IGreen" "Upgrading Bitwarden..."
                    sleep 2
                    yes no | sudo -u "$BITWARDEN_USER" bash "$BITWARDEN_HOME"/bitwarden.sh updateself
                    yes no | sudo -u "$BITWARDEN_USER" bash "$BITWARDEN_HOME"/bitwarden.sh update
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
        systemctl start postgresql.service
    fi
fi

# Recover apps that exists in the backed up apps folder
run_script STATIC recover_apps

# Restore app status
# Fixing https://github.com/nextcloud/server/issues/4538
if [ "${APPSTORAGE[0]}" != "no-export-done" ]
then
    print_text_in_color "$ICyan" "Restoring the status of apps. This can take a while..."
    for app in "${!APPSTORAGE[@]}"
    do
        if [ -n "${APPSTORAGE[$app]}" ]
        then
            if echo "${APPSTORAGE[$app]}" | grep -q "^\[\".*\"\]$"
            then
                if is_app_enabled "$app"
                then
                    nextcloud_occ_no_check config:app:set "$app" enabled --value="${APPSTORAGE[$app]}"
                fi
            fi
        fi
    done
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
nextcloud_occ config:system:set htaccess.RewriteBase --value="/"
nextcloud_occ maintenance:update:htaccess
bash "$SECURE"

# Repair
nextcloud_occ maintenance:repair

# Create $VMLOGS dir
if [ ! -d "$VMLOGS" ]
then
    mkdir -p "$VMLOGS"
fi

CURRENTVERSION_after=$(nextcloud_occ status | grep "versionstring" | awk '{print $3}')
if [[ "$NCVERSION" == "$CURRENTVERSION_after" ]] || [ -n "$PRERELEASE_VERSION" ]
then
    msg_box "Latest version is: $NCVERSION. Current version is: $CURRENTVERSION_after.

||| UPGRADE SUCCESS! |||

If you notice that some apps are disabled it's due to that they are not compatible with the new Nextcloud version.
To recover your old apps, please check $BACKUP/apps and copy them to $NCPATH/apps manually.

Thank you for using T&M Hansson IT's updater!"
    nextcloud_occ status
    nextcloud_occ maintenance:mode --off
    print_text_in_color "$ICyan" "Sending notification about the successful update to all admins..."
    notify_admin_gui \
    "Nextcloud is now updated!" \
    "Your Nextcloud is updated to $CURRENTVERSION_after with the update script in the Nextcloud VM."
    echo "NEXTCLOUD UPDATE success-$(date +"%Y%m%d")" >> "$VMLOGS"/update.log
    if [ -n "$SNAPSHOT_EXISTS" ]
    then
        check_command lvrename /dev/ubuntu-vg/NcVM-snapshot-pending /dev/ubuntu-vg/NcVM-snapshot
    fi
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
    nextcloud_occ status
    exit 1
fi
