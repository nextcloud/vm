#!/bin/bash

# Variables
HTML=/var/www
NCPATH=$HTML/nextcloud
SCRIPTS=/var/scripts
PASSVER=$(curl -s https://api.github.com/repos/nextcloud/passman/releases/latest | grep "tag_name" | cut -d\" -f4)
PASSVER_FILE=passman_$PASSVER.tar.gz
PASSVER_REPO=https://releases.passman.cc

# Check if root
if [ "$(whoami)" != "root" ]
then
    echo
    echo -e "\e[31mSorry, you are not root.\n\e[0mYou must type: \e[36msudo \e[0mbash $SCRIPTS/passman.sh"
    echo
    exit 1
fi

# Check if file is downloadable
echo "Checking latest released version on the Passman download server and if it's possible to download..."
curl -s wget -q $PASSVER_REPO/$PASSVER/$PASSVER_FILE > /dev/null
if [ $? -eq 0 ]
then
   echo "Latest version is: $PASSVER"
else
    echo "Failed! Download is not available at the moment, try again later."
    sleep 3
    exit 1
fi

# Download and install Passman
if [ -d $NCPATH/apps/passman ]
then
    sleep 1
else
    wget -q $PASSVER_REPO/$PASSVER_FILE -P $NCPATH/apps
    tar -zxf $NCPATH/apps/$PASSVER_FILE -C $NCPATH/apps
    cd $NCPATH/apps
    rm $PASSVER_FILE
fi

# Enable Passman
if [ -d $NCPATH/apps/passman ]
then
    sudo -u www-data php $NCPATH/occ app:enable passman
    sleep 2
else
   echo "Something went wrong with the installation, Passman couln't be activated..."
   exit 1
fi
