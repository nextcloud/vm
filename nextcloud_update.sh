#!/bin/bash
#
## Tech and Me ## - ©2016, https://www.techandme.se/
#
# Tested on Ubuntu Server 14.04 & 16.04.
#

PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/snap/bin

# Put your theme name here:
THEME_NAME=""

# Static values
STATIC="https://raw.githubusercontent.com/nextcloud/vm/master/static"
SCRIPTS=/var/scripts
NCPATH=/var/www/nextcloud
HTML=/var/www
SECURE="$SCRIPTS/setup_secure_permissions_owncloud.sh"
DATA=/var/ocdata

# Must be root
[[ `id -u` -eq 0 ]] || { echo "Must be root to run script, in Ubuntu type: sudo -i"; exit 1; }

# Check if aptitude is installed
if [ $(dpkg-query -W -f='${Status}' aptitude 2>/dev/null | grep -c "ok installed") -eq 1 ];
then
        echo "Aptitude installed"
else
	apt-get install aptitude -y
fi

# System Upgrade
sudo apt-get update -q2
sudo aptitude full-upgrade -y
echo
echo "System is now upgraded, now the script will upgrade Nextcloud."
echo "Which version do you want to upgrade to?"
read NCVERSION

echo "Upgrading to $NCVERSION in 15 seconds... Press CTRL+C to abort."
echo "Disclamer: Tech and Me is not responsible for any dataloss"
echo "Data and config files are backed up, but things could go wrong."
sleep 15

# Backup data
rsync -Aaxv $DATA $HTML
rsync -Aax $NCPATH/config $HTML
rsync -Aax $NCPATH/themes $HTML
rsync -Aax $NCPATH/apps $HTML
if [[ $? > 0 ]]
then
    	echo "Backup was not OK. Please check $HTML and see if the folders are backed up properly"
    	exit 1
else
	echo -e "\e[32m"
    	echo "Backup OK!"
    	echo -e "\e[0m"
fi
wget https://download.nextcloud.org/community/testing/nextcloud-$NCVERSION.tar.bz2 -P $HTML

if [ -f $HTML/nextcloud-$NCVERSION.tar.bz2 ];
then
        echo "$HTML/nextcloud-$NCVERSION exists"
else
        echo "Aborting,something went wrong with the download"
   	exit 1
fi

if [ -d $NCPATH/config/ ]; then
        echo "config/ exists" 
else
        echo "Something went wrong with backing up your old ownCloud instance, please check in $HTML if data/ and config/ folders exist."
   	exit 1
fi

if [ -d $NCPATH/themes/ ]; then
        echo "themes/ exists" 
else
        echo "Something went wrong with backing up your old ownCloud instance, please check in $HTML if data/ and config/ folders exist."
   	exit 1
fi

if [ -d $NCPATH/apps/ ]; then
        echo "apps/ exists" 
else
        echo "Something went wrong with backing up your old ownCloud instance, please check in $HTML if data/ and config/ folders exist."
   	exit 1
fi

if [ -d $DATA/ ]; then
        echo "data/ exists" && sleep 2
        rm -rf $NCPATH
        tar -xjf $HTML/nextcloud-$NCVERSION.tar.bz2 -C $HTML 
        rm $HTML/nextcloud-$NCVERSION.tar.bz2
        cp -R $HTML/themes $NCPATH/ && rm -rf $HTML/themes
        cp -Rv $HTML/data $DATA && rm -rf $HTML/data
        cp -R $HTML/config $NCPATH/ && rm -rf $HTML/config
        cp -R $HTML/apps $NCPATH/ && rm -rf $HTML/apps
        bash $SECURE
        sudo -u www-data php $NCPATH/occ maintenance:mode --off
        sudo -u www-data php $NCPATH/occ upgrade
else
        echo "Something went wrong with backing up your old ownCloud instance, please check in $HTML if data/ and config/ folders exist."
   	exit 1
fi

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
if grep -Fxq "$VALUE2" $NCPATH/config/config.php
then
        echo "Theme correct"
else
        sed -i "s|'theme' => '',|'theme' => '$THEME_NAME',|g" $NCPATH/config/config.php
	echo "Theme set"
fi

# Set secure permissions
FILE="$SCRIPTS/setup_secure_permissions_nextcloud.sh"
if [ -f $FILE ];
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

# Write to log
touch /var/log/cronjobs_success.log
echo "OWNCLOUD UPDATE success-`date +"%Y%m%d"`" >> /var/log/cronjobs_success.log
echo
echo Nextcloud version:
sudo -u www-data php $NCPATH/occ status
echo
echo

# Disable maintenance mode again just to be sure
sudo -u www-data php $NCPATH/occ maintenance:mode --off

## Un-hash this if you want the system to reboot
# sudo reboot

exit 0
