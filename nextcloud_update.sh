#!/bin/bash
#
## Tech and Me ## - ©2016, https://www.techandme.se/
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
#Static Values
STATIC="https://raw.githubusercontent.com/nextcloud/vm/master/static"
DOWNLOADREPO="https://download.nextcloud.com/server/releases"
SECURE="$SCRIPTS/setup_secure_permissions_nextcloud.sh"
# Versions
CURRENTVERSION=$(php $NCPATH/status.php | grep "versionstring" | awk '{print $3}')
NCVERSION=$(curl -s $DOWNLOADREPO/ | tac | grep unknown.gif | sed 's/.*"nextcloud-\([^"]*\).zip.sha512".*/\1/;q')

# Must be root
[[ `id -u` -eq 0 ]] || { echo "Must be root to run script, in Ubuntu type: sudo -i"; exit 1; }

# Check if aptitude is installed
if [ $(dpkg-query -W -f='${Status}' aptitude 2>/dev/null | grep -c "ok installed") -eq 1 ]
then
    echo "Aptitude installed"
else
    apt-get install aptitude -y
fi

# System Upgrade
sudo apt-get update -q2
sudo aptitude full-upgrade -y

# Upgrade Nextcloud
echo "Upgrading Nextcloud..."
echo "Checking latest released version: $NCVERSION, and if it exists on the download server..."
wget -q --spider $DOWNLOADREPO/nextcloud-$NCVERSION.tar.bz2
if [ $? -eq 0 ]; then
    echo -e "\e[32mSUCCESS! Nextcloud $NCVERSION exists at Nextloud download server!\e[0m"
    echo
else
    echo
    echo -e "\e[91mNextcloud $NCVERSION doesn't exist.\e[0m"
    echo "Please check available versions here: $DOWNLOADREPO"
    echo
    exit 1
fi

# Check if new version is larger than current version installed.
if [[ "$NCVERSION" > "$CURRENTVERSION" ]]
then
    echo "Latest version is: $NCVERSION. Current version is: $CURRENTVERSION."
    echo "New version available! Upgrade continues..."
else
    echo "Latest version is: $NCVERSION. Current version is: $CURRENTVERSION."
    echo "No need to upgrade, this script will exit..."
    exit 0
fi
echo "Upgrading to Nextcloud $NCVERSION in 10 seconds... Press CTRL+C to abort."
sleep 10

# Backup data
echo "Backing up data..."
DATE=`date +%Y-%m-%d-%H%M%S`
if [ -d $BACKUP ]
then
    mkdir -p /var/NCBACKUP_OLD/$DATE
    mv $BACKUP/* /var/NCBACKUP_OLD/$DATE
    rm -R $BACKUP
    mkdir -p $BACKUP
fi
rsync -Aax $NCPATH/config $BACKUP
rsync -Aax $NCPATH/themes $BACKUP
rsync -Aax $NCPATH/apps $BACKUP
if [[ $? > 0 ]]
then
    echo "Backup was not OK. Please check $BACKUP and see if the folders are backed up properly"
    exit 1
else
    echo -e "\e[32m"
    echo "Backup OK!"
    echo -e "\e[0m"
fi
wget $DOWNLOADREPO/nextcloud-$NCVERSION.tar.bz2 -P $HTML

if [ -f $HTML/nextcloud-$NCVERSION.tar.bz2 ]
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

if [ -d $BACKUP/themes/ ]
then
    echo "$BACKUP/themes/ exists"
else
    echo "Something went wrong with backing up your old nextcloud instance, please check in $BACKUP if themes/ folder exist."
    exit 1
fi

# Let the magic begin...
if [ -d $BACKUP/apps/ ]
then
    echo "$BACKUP/apps/ exists, removing old Nextcloud instance in 5 seconds..." && sleep 5
    rm -rf $NCPATH
    tar -xjf $HTML/nextcloud-$NCVERSION.tar.bz2 -C $HTML
    rm $HTML/nextcloud-$NCVERSION.tar.bz2
    cp -R $BACKUP/themes $NCPATH/
    cp -R $BACKUP/config $NCPATH/
    cp -R $BACKUP/apps $NCPATH/
    bash $SECURE
    sudo -u www-data php $NCPATH/occ maintenance:mode --off
    sudo -u www-data php $NCPATH/occ upgrade
else
    echo "Something went wrong with backing up your old nextcloud instance, please check in $BACKUP if apps/ folders exist."
    exit 1
fi

# Change owner of $BACKUP folder to root
chown -R root:root $BACKUP

# Enable Apps
sudo -u www-data php $NCPATH/occ app:enable calendar
sudo -u www-data php $NCPATH/occ app:enable contacts
sudo -u www-data php $NCPATH/occ app:enable documents

# Increase max filesize (expects that changes are made in /etc/php5/apache2/php.ini)
# Here is a guide: https://www.techandme.se/increase-max-file-size/
VALUE="# php_value upload_max_filesize 513M"
if grep -Fxq "$VALUE" $NCPATH/.htaccess
then
    echo "Value correct"
else
    sed -i 's/  php_value upload_max_filesize 513M/# php_value upload_max_filesize 513M/g' $NCPATH/.htaccess
    sed -i 's/  php_value post_max_size 513M/# php_value post_max_size 513M/g' $NCPATH/.htaccess
    sed -i 's/  php_value memory_limit 512M/# php_value memory_limit 512M/g' $NCPATH/.htaccess
fi

# Set $THEME_NAME
VALUE2="$THEME_NAME"
if grep -Fxq "$VALUE2" "$NCPATH/config/config.php"
then
    echo "Theme correct"
else
    sed -i "s|'theme' => '',|'theme' => '$THEME_NAME',|g" $NCPATH/config/config.php
    echo "Theme set"
fi

# Set secure permissions
FILE="$SCRIPTS/setup_secure_permissions_nextcloud.sh"
if [ -f $FILE ]
then
    echo "Script exists"
else
    mkdir -p $SCRIPTS
    wget -q $STATIC/setup_secure_permissions_nextcloud.sh -P $SCRIPTS
    chmod +x $SCRIPTS/setup_secure_permissions_nextcloud.sh
fi
sudo bash $SCRIPTS/setup_secure_permissions_nextcloud.sh

# Repair
sudo -u www-data php $NCPATH/occ maintenance:repair

# Cleanup un-used packages
sudo apt-get autoremove -y
sudo apt-get autoclean

# Update GRUB, just in case
sudo update-grub

if [[ "$NCVERSION" == "$CURRENTVERSION" ]]
then
    echo "Latest version is: $NCVERSION. Current version is: $CURRENTVERSION."
    echo "UPGRADE SUCCESS!"
    echo "NEXTCLOUD UPDATE success-`date +"%Y%m%d"`" >> /var/log/cronjobs_success.log
    sudo -u www-data php $NCPATH/occ status
    sudo -u www-data php $NCPATH/occ maintenance:mode --off
    ## Un-hash this if you want the system to reboot
    # sudo reboot
    exit 0
else
    echo "Latest version is: $NCVERSION. Current version is: $CURRENTVERSION."
    echo "UPGRADE FAILED!"
    exit 1
fi
