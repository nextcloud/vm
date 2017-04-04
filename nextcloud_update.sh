#!/bin/bash
#
## Tech and Me ## - ©2017, https://www.techandme.se/
#
# Tested on Ubuntu Server 14.04 & 16.04.
#

PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/snap/bin

# Put your theme name here:
THEME_NAME=""

# Directories
HTML=/var/www
NCPATH=$HTML/nextcloud
SCRIPTS=/var/scripts
BACKUP=/var/NCBACKUP
SNAPDIR=/var/snap/spreedme
#Static Values
STATIC="https://raw.githubusercontent.com/nextcloud/vm/master/static"
NCREPO="https://download.nextcloud.com/server/releases"
SECURE="$SCRIPTS/setup_secure_permissions_nextcloud.sh"
# Versions
CURRENTVERSION=$(sudo -u www-data php $NCPATH/occ status | grep "versionstring" | awk '{print $3}')
NCVERSION=$(curl -s -m 900 $NCREPO/ | tac | grep unknown.gif | sed 's/.*"nextcloud-\([^"]*\).zip.sha512".*/\1/;q')
NCMAJOR="${NCVERSION%%.*}"
NCBAD=$((NCMAJOR-2))

# Must be root
[[ $EUID -ne 0 ]] && { echo "Must be root to run script, in Ubuntu type: sudo -i"; exit 1; }

# System Upgrade
apt update
export DEBIAN_FRONTEND=noninteractive ; apt dist-upgrade -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"
rm /var/lib/apt/lists/* -R

# Set secure permissions
FILE="$SECURE"
if [ ! -f $FILE ]
then
    mkdir -p $SCRIPTS
    wget -q $STATIC/setup_secure_permissions_nextcloud.sh -P $SCRIPTS
    chmod +x $SECURE
fi

# Upgrade Nextcloud
echo "Checking latest released version on the Nextcloud download server and if it's possible to download..."
wget -q -T 10 -t 2 "$NCREPO/nextcloud-$NCVERSION.tar.bz2" -O /dev/null
if [ $? -eq 0 ]; then
    printf "\e[32mSUCCESS!\e[0m\n"
    rm -f "nextcloud-$NCVERSION.tar.bz2"
else
    echo
    printf "\e[91mNextcloud %s doesn't exist.\e[0m\n" "$NCVERSION"
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
    echo "Upgraded version: $NCVERSION"
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
function version_gt() { local v1 v2 IFS=.; read -ra v1 <<< "$1"; read -ra v2 <<< "$2"; printf -v v1 %03d "${v1[@]}"; printf -v v2 %03d "${v2[@]}"; [[ $v1 > $v2 ]]; }
if version_gt "$NCVERSION" "$CURRENTVERSION"
then
    echo "Latest version is: $NCVERSION. Current version is: $CURRENTVERSION."
    printf "\e[32mNew version available! Upgrade continues...\e[0m\n"
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

for PATH in config themes apps
do
    rsync -Aax "$NCPATH/$PATH" "$BACKUP"
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
    printf "\e[32m\nBackup OK!\e[0m\n"
fi

echo "Downloading $NCREPO/nextcloud-$NCVERSION.tar.bz2..."
wget -q -T 10 -t 2 "$NCREPO/nextcloud-$NCVERSION.tar.bz2" -P "$HTML"

if [ -f "$HTML/nextcloud-$NCVERSION.tar.bz2" ]
then
    echo "$HTML/nextcloud-$NCVERSION.tar.bz2 exists"
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
    printf "\e[32mAll files are backed up.\e[0m\n"
    sudo -u www-data php $NCPATH/occ maintenance:mode --on
    echo "Removing old Nextcloud instance in 5 seconds..." && sleep 5
    rm -rf $NCPATH
    tar -xjf "$HTML/nextcloud-$NCVERSION.tar.bz2" -C "$HTML"
    rm "$HTML/nextcloud-$NCVERSION.tar.bz2"
    cp -R $BACKUP/themes $NCPATH/
    cp -R $BACKUP/config $NCPATH/
    bash $SECURE
    sudo -u www-data php $NCPATH/occ maintenance:mode --off
    sudo -u www-data php $NCPATH/occ upgrade
else
    echo "Something went wrong with backing up your old nextcloud instance, please check in $BACKUP if the folders exist."
    exit 1
fi

# Enable Apps
if [ -d $SNAPDIR ]
then
    wget $STATIC/spreedme.sh -P $SCRIPTS
    bash $SCRIPTS/spreedme.sh
    rm $SCRIPTS/spreedme.*
    sudo -u www-data php $NCPATH/occ app:enable spreedme
fi

# Recover apps that exists in the backed up apps folder
wget -q $STATIC/recover_apps.py -P $SCRIPTS
chmod +x $SCRIPTS/recover_apps.py
python $SCRIPTS/recover_apps.py
rm $SCRIPTS/recover_apps.py

# Change owner of $BACKUP folder to root
chown -R root:root $BACKUP

# Increase max filesize (expects that changes are made in /etc/php5/apache2/php.ini)
# Here is a guide: https://www.techandme.se/increase-max-file-size/
VALUE="# php_value upload_max_filesize 511M"
if grep -Fxq "$VALUE" $NCPATH/.htaccess
then
    echo "Value correct"
else
    sed -i 's/  php_value upload_max_filesize 511M/# php_value upload_max_filesize 511M/g' $NCPATH/.htaccess
    sed -i 's/  php_value post_max_size 513M/# php_value post_max_size 511M/g' $NCPATH/.htaccess
    sed -i 's/  php_value memory_limit 512M/# php_value memory_limit 512M/g' $NCPATH/.htaccess
fi

# Set $THEME_NAME
VALUE2="$THEME_NAME"
if ! grep -Fxq "$VALUE2" "$NCPATH/config/config.php"
then
    sed -i "s|'theme' => '',|'theme' => '$THEME_NAME',|g" $NCPATH/config/config.php
    echo "Theme set"
fi

# Pretty URLs
echo "Setting RewriteBase to \"/\" in config.php..."
chown -R www-data:www-data $NCPATH
sudo -u www-data php $NCPATH/occ config:system:set htaccess.RewriteBase --value="/"
sudo -u www-data php $NCPATH/occ maintenance:update:htaccess
bash $SECURE

# Repair
sudo -u www-data php $NCPATH/occ maintenance:repair

# Cleanup un-used packages
apt autoremove -y
apt autoclean

# Update GRUB, just in case
update-grub

CURRENTVERSION_after=$(sudo -u www-data php $NCPATH/occ status | grep "versionstring" | awk '{print $3}')
if [[ "$NCVERSION" == "$CURRENTVERSION_after" ]]
then
    echo
    echo "Latest version is: $NCVERSION. Current version is: $CURRENTVERSION_after."
    echo "UPGRADE SUCCESS!"
    echo "NEXTCLOUD UPDATE success-$(date +"%Y%m%d")" >> /var/log/cronjobs_success.log
    sudo -u www-data php $NCPATH/occ status
    sudo -u www-data php $NCPATH/occ maintenance:mode --off
    echo
    echo "Thank you for using Tech and Me's updater!"
    ## Un-hash this if you want the system to reboot
    # reboot
    exit 0
else
    echo
    echo "Latest version is: $NCVERSION. Current version is: $CURRENTVERSION_after."
    sudo -u www-data php $NCPATH/occ status
    echo "UPGRADE FAILED!"
    echo "Your files are still backed up at $BACKUP. No worries!"
    echo "Please report this issue to https://github.com/nextcloud/vm/issues"
    exit 1
fi
