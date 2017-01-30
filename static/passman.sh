#!/bin/bash

# Variables
HTML=/var/www
NCPATH=$HTML/nextcloud
SCRIPTS=/var/scripts
# Requires "v2.0.0" tag-standard
PASSVER=$(curl -s https://api.github.com/repos/nextcloud/passman/releases/latest | grep 'tag_name' | cut -d" -f4 | sed -e "s|v||g")
PASSVER_FILE=passman_$PASSVER.tar.gz
PASSVER_REPO=https://github.com/nextcloud/passman/releases/download

# Check if root
if [ "$(whoami)" != "root" ]
then
    echo
    echo -e "\e[31mSorry, you are not root.\n\e[0mYou must type: \e[36msudo \e[0mbash $SCRIPTS/passman.sh"
    echo
    exit 1
fi

# Download and install Passman
if [ -d $NCPATH/apps/passman ]
then
    sleep 1
else
    wget -q $PASSVER_REPO/v$PASSVER/$PASSVER_FILE -P $NCPATH/apps
    tar -zxf $NCPATH/apps/$PASSVER_FILE -C $NCPATH/apps
    cd $NCPATH/apps
    rm $PASSVER_FILE
fi

# Enable Passman
if [ -d $NCPATH/apps/passman ]
then
    sudo -u www-data php $NCPATH/occ app:enable passman
else
   echo "Something went wrong with the installation, Passman couln't be activated..."
   exit 1
fi
