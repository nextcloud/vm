#!/bin/bash
# shellcheck disable=2034,2059
true
# shellcheck source=lib.sh
NCDB=1 && MYCNFPW=1 && NC_UPDATE=1 . <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)
unset NC_UPDATE
unset MYCNFPW
unset NCDB

# Tech and Me © - 2017, https://www.techandme.se/

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
is_process_running dpkg
is_process_running apt

# System Upgrade
sudo apt-mark hold mariadb*
apt update -q4 & spinner_loading
export DEBIAN_FRONTEND=noninteractive ; apt dist-upgrade -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"
sudo apt-mark unhold mariadb*

# Update Redis PHP extention
if type pecl > /dev/null 2>&1
then
    install_if_not php7.0-dev
    echo "Trying to upgrade the Redis Pecl extenstion..."
    pecl upgrade redis
    service apache2 restart
fi

# Update docker images
# This updates ALL Docker images:
if [ "$(docker ps -a >/dev/null 2>&1 && echo yes || echo no)" == "yes" ]
then
docker images | grep -v REPOSITORY | awk '{print $1}' | xargs -L1 docker pull
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

# Set secure permissions
if [ ! -f "$SECURE" ]
then
    mkdir -p "$SCRIPTS"
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

Please contact Tech and Me to help you with upgrading between major versions.
https://shop.techandme.se/index.php/product-category/support/"
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

if [ -z "$MARIADBMYCNFPASS" ]
then
msg_box "Something went wrong with copying your mysql password to $MYCNF.

We wrote a guide on how to fix this. You can find the guide here:
https://www.techandme.se/reset-mysql-5-7-root-password/"
    exit 1
else
    rm -f /var/mysql_password.txt
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

echo "Backing up files and upgrading to Nextcloud $NCVERSION in 10 seconds..."
echo "Press CTRL+C to abort."
sleep 10

# Check if backup exists and move to old
echo "Backing up data..."
DATE=$(date +%Y-%m-%d-%H%M%S)
if [ -d $BACKUP ]
then
    mkdir -p "/var/NCBACKUP_OLD/$DATE"
    mv $BACKUP/* "/var/NCBACKUP_OLD/$DATE"
    rm -R $BACKUP
    mkdir -p $BACKUP
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

# Backup MARIADB
if mysql -u root -p"$MARIADBMYCNFPASS" -e "SHOW DATABASES LIKE '$NCCONFIGDB'" > /dev/null
then
    echo "Doing mysqldump of $NCCONFIGDB..."
    check_command mysqldump -u root -p"$MARIADBMYCNFPASS" -d "$NCCONFIGDB" > "$BACKUP"/nextclouddb.sql
else
    echo "Doing mysqldump of all databases..."
    check_command mysqldump -u root -p"$MARIADBMYCNFPASS" -d --all-databases > "$BACKUP"/alldatabases.sql
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
    sudo -u www-data php "$NCPATH"/occ maintenance:mode --on
    echo "Removing old Nextcloud instance in 5 seconds..." && sleep 5
    rm -rf $NCPATH
    tar -xjf "$HTML/$STABLEVERSION.tar.bz2" -C "$HTML"
    rm "$HTML/$STABLEVERSION.tar.bz2"
    cp -R $BACKUP/themes "$NCPATH"/
    cp -R $BACKUP/config "$NCPATH"/
    bash $SECURE & spinner_loading
    sudo -u www-data php "$NCPATH"/occ maintenance:mode --off
    sudo -u www-data php "$NCPATH"/occ upgrade --no-app-disable
else
msg_box "Something went wrong with backing up your old nextcloud instance
Please check in $BACKUP if the folders exist."
    exit 1
fi

# Recover apps that exists in the backed up apps folder
# run_static_script recover_apps

# Enable Apps
if [ -d "$SNAPDIR" ]
then
    run_app_script spreedme
fi

# Change owner of $BACKUP folder to root
chown -R root:root "$BACKUP"

# Set max upload in Nextcloud .htaccess
configure_max_upload

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
sudo -u www-data php "$NCPATH"/occ config:system:set htaccess.RewriteBase --value="/"
sudo -u www-data php "$NCPATH"/occ maintenance:update:htaccess
bash "$SECURE"

# Repair
sudo -u www-data php "$NCPATH"/occ maintenance:repair

CURRENTVERSION_after=$(sudo -u www-data php "$NCPATH"/occ status | grep "versionstring" | awk '{print $3}')
if [[ "$NCVERSION" == "$CURRENTVERSION_after" ]]
then
msg_box "Latest version is: $NCVERSION. Current version is: $CURRENTVERSION_after.

||| UPGRADE SUCCESS! |||

If you notice that some apps are disabled it's due to that they are not compatible with the new Nextcloud version.
To recover your old apps, please check $BACKUP/apps and copy them to $NCPATH/apps manually.

Thank you for using Tech and Me's updater!"
    sudo -u www-data php "$NCPATH"/occ status
    sudo -u www-data php "$NCPATH"/occ maintenance:mode --off
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
sudo -u www-data php "$NCPATH"/occ status
    exit 1
fi
