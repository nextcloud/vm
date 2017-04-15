#!/bin/bash
# shellcheck disable=2034,2059
true
# shellcheck source=lib.sh
NC_UPDATE=1 . <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)
unset NC_UPDATE

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
if ! is_root
then
    echo "Must be root to run script, in Ubuntu type: sudo -i"
    exit 1
fi

# System Upgrade
apt update -q4 & spinner_loading
export DEBIAN_FRONTEND=noninteractive ; apt dist-upgrade -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"

# Update Redis PHP extention
if type pecl > /dev/null 2>&1
then
    if [ "$(dpkg-query -W -f='${Status}' php7.0-dev 2>/dev/null | grep -c "ok installed")" == "0" ]
    then
        echo "Preparing to upgrade Redis Pecl extenstion..."
        apt install php7.0-dev -y
    fi
    echo "Trying to upgrade the Redis Pecl extenstion..."
    pecl upgrade redis
fi

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

# Upgrade Nextcloud
echo "Checking latest released version on the Nextcloud download server and if it's possible to download..."
wget -q -T 10 -t 2 "$NCREPO/$STABLEVERSION.tar.bz2" -O /dev/null & spinner_loading
if [ $? -eq 0 ]; then
    printf "${Green}SUCCESS!${Color_Off}\n"
    rm -f "$STABLEVERSION.tar.bz2"
else
    echo
    printf "${IRed}Nextcloud %s doesn't exist.${Color_Off}\n" "$NCVERSION"
    echo "Please check available versions here: $NCREPO"
    echo
    exit 1
fi

# Major versions unsupported
if [ "${CURRENTVERSION%%.*}" == "$NCBAD" ]
then
    echo
    echo "Please note that updates between multiple major versions are unsupported! Your situation is:"
    echo "Current version: $CURRENTVERSION"
    echo "Latest release: $NCVERSION"
    echo
    echo "It is best to keep your Nextcloud server upgraded regularly, and to install all point releases"
    echo "and major releases without skipping any of them, as skipping releases increases the risk of"
    echo "errors. Major releases are 9, 10, 11 and 12. Point releases are intermediate releases for each"
    echo "major release. For example, 9.0.52 and 10.0.2 are point releases."
    echo
    echo "Please contact Tech and Me to help you with upgrading between major versions."
    echo "https://shop.techandme.se/index.php/product-category/support/"
    echo
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
echo "Backing up files and upgrading to Nextcloud $NCVERSION in 10 seconds..."
echo "Press CTRL+C to abort."
sleep 10

# Backup data
echo "Backing up data..."
DATE=$(date +%Y-%m-%d-%H%M%S)
if [ -d $BACKUP ]
then
    mkdir -p "/var/NCBACKUP_OLD/$DATE"
    mv $BACKUP/* "/var/NCBACKUP_OLD/$DATE"
    rm -R $BACKUP
    mkdir -p $BACKUP
fi

for folders in config themes apps
do
    rsync -Aax "$NCPATH/$folders" "$BACKUP"
    if [ $? -eq 0 ]
    then
        BACKUP_OK=1
    else
        unset BACKUP_OK
    fi
done

if [ -z $BACKUP_OK ]
then
    echo "Backup was not OK. Please check $BACKUP and see if the folders are backed up properly"
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
    echo "Aborting,something went wrong with the download"
    exit 1
fi

if [ -d $BACKUP/config/ ]
then
    echo "$BACKUP/config/ exists"
else
    echo "Something went wrong with backing up your old nextcloud instance, please check in $BACKUP if config/ folder exist."
    exit 1
fi

if [ -d $BACKUP/apps/ ]
then
    echo "$BACKUP/apps/ exists"
else
    echo "Something went wrong with backing up your old nextcloud instance, please check in $BACKUP if apps/ folder exist."
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
    sudo -u www-data php "$NCPATH"/occ upgrade
else
    echo "Something went wrong with backing up your old nextcloud instance, please check in $BACKUP if the folders exist."
    exit 1
fi

# Enable Apps
if [ -d "$SNAPDIR" ]
then
    run_app_script spreedme
fi

# Recover apps that exists in the backed up apps folder
run_static_script recover_apps

# Change owner of $BACKUP folder to root
chown -R root:root "$BACKUP"

# Increase max filesize (expects that changes are made in /etc/php5/apache2/php.ini)
# Here is a guide: https://www.techandme.se/increase-max-file-size/
VALUE="# php_value upload_max_filesize 511M"
if grep -Fxq "$VALUE" "$NCPATH"/.htaccess
then
    echo "Value correct"
else
    sed -i 's/  php_value upload_max_filesize 511M/# php_value upload_max_filesize 511M/g' "$NCPATH"/.htaccess
    sed -i 's/  php_value post_max_size 513M/# php_value post_max_size 511M/g' "$NCPATH"/.htaccess
    sed -i 's/  php_value memory_limit 512M/# php_value memory_limit 512M/g' "$NCPATH"/.htaccess
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
sudo -u www-data php "$NCPATH"/occ config:system:set htaccess.RewriteBase --value="/"
sudo -u www-data php "$NCPATH"/occ maintenance:update:htaccess
bash "$SECURE"

# Repair
sudo -u www-data php "$NCPATH"/occ maintenance:repair

CURRENTVERSION_after=$(sudo -u www-data php "$NCPATH"/occ status | grep "versionstring" | awk '{print $3}')
if [[ "$NCVERSION" == "$CURRENTVERSION_after" ]]
then
    echo
    echo "Latest version is: $NCVERSION. Current version is: $CURRENTVERSION_after."
    echo "UPGRADE SUCCESS!"
    echo "NEXTCLOUD UPDATE success-$(date +"%Y%m%d")" >> /var/log/cronjobs_success.log
    sudo -u www-data php "$NCPATH"/occ status
    sudo -u www-data php "$NCPATH"/occ maintenance:mode --off
    echo
    echo "Thank you for using Tech and Me's updater!"
    ## Un-hash this if you want the system to reboot
    # reboot
    exit 0
else
    echo
    echo "Latest version is: $NCVERSION. Current version is: $CURRENTVERSION_after."
    sudo -u www-data php "$NCPATH"/occ status
    echo "UPGRADE FAILED!"
    echo "Your files are still backed up at $BACKUP. No worries!"
    echo "Please report this issue to https://github.com/nextcloud/vm/issues"
    exit 1
fi
