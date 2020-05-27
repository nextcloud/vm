#!/bin/bash

#################################################################################################################
# DO NOT USE THIS SCRIPT WHEN UPDATING NEXTCLOUD / YOUR SERVER! RUN `sudo bash /var/scripts/update.sh` INSTEAD. #
#################################################################################################################

# shellcheck disable=2034,2059
true
# shellcheck source=lib.sh
source /var/scripts/main/lib.sh &>/dev/null || . <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh) &>/dev/null

# Get needed variables
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

# Ubuntu 16.04 is deprecated
check_distro_version

# Hold PHP if Ondrejs PPA is used
print_text_in_color "$ICyan" "Fetching latest apt packages..."
apt update -q4 & spinner_loading
if apt-cache policy | grep "ondrej" >/dev/null 2>&1
then
    print_text_in_color "$ICyan" "Ondrejs PPA is installed. Holding PHP to avoid upgrading to a newer version without migration..."
    apt-mark hold php*
fi

# Don't allow MySQL/MariaDB
if ! grep -q pgsql /var/www/nextcloud/config/config.php
then
    msg_box "MySQL/MariaDB is not supported in this script anymore. Please contact us to get support for upgrading your server: https://shop.hanssonit.se/product/premium-support-per-30-minutes/"
    exit 0
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

# Update Redis PHP extension
print_text_in_color "$ICyan" "Trying to upgrade the Redis PECL extension..."
if version 20.04 "$DISTRO" 20.04.6
then
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
else
msg_box "Your current Ubuntu version is $DISTRO but must be between 20.04 - 20.04.6 to upgrade Redis."
msg_box "Please contact us to get support for upgrading your server:
https://www.hanssonit.se/#contact
https://shop.hanssonit.se/"
fi

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
        if pecl list | grep smbclient >/dev/null 2>&1
        then
            yes no | pecl upgrade smbclient
            # Check if igbinary.so is enabled
            if ! grep -qFx extension=smbclient.so "$PHP_INI"
            then
                echo "extension=smbclient.so" >> "$PHP_INI"
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
        run_script STATIC prune_zfs_snaphots
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
fi

# Update all Nextcloud apps
if [ "${CURRENTVERSION%%.*}" -ge "15" ]
then
    occ_command maintenance:mode --off
    # Check for upgrades
    print_text_in_color "$ICyan" "Trying to automatically update all Nextcloud apps..."
    UPDATED_APPS="$(occ_command_no_check app:update --all)"
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
    msg_box "WARNING! You are about to update to a Beta/RC version of Nextcloud.\nThere's no turning back, because it's not possible to downgrade.\n\nPlease only continue if you have made a backup, or took a snapshot."
    if [[ "no" == $(ask_yes_or_no "Do you really want to do this?") ]]
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

# Upgrade Nextcloud
if ! site_200 $NCREPO
then
msg_box "$NCREPO seems to be down, or temporarily not reachable. Please try again in a few minutes."
    exit 1
fi

countdown "Backing up files and upgrading to Nextcloud $NCVERSION in 10 seconds... Press CTRL+C to abort." "10"

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
    occ_command maintenance:mode --on
    countdown "Removing old Nextcloud instance in 5 seconds..." "5"
    rm -rf $NCPATH
    print_text_in_color "$IGreen" "Extracting new package...."
    check_command tar -xjf "$HTML/$STABLEVERSION.tar.bz2" -C "$HTML"
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
    if [ "${CURRENTVERSION%%.*}" -ge "19" ]
    then
        occ_command db:add-missing-columns
        install_if_not php"$PHPVER"-bcmath
    fi
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
        check_command systemctl start postgresql.service
    fi
fi

# Recover apps that exists in the backed up apps folder
run_script STATIC recover_apps

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
if [[ "$NCVERSION" == "$CURRENTVERSION_after" ]] || [ -n "$PRERELEASE_VERSION" ]
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
