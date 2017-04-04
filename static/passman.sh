#!/bin/bash

# Variables
HTML=/var/www
NCPATH=$HTML/nextcloud
SCRIPTS=/var/scripts
PASSVER=$(curl -s https://api.github.com/repos/nextcloud/passman/releases/latest | grep "tag_name" | cut -d\" -f4)
PASSVER_FILE=passman_$PASSVER.tar.gz
PASSVER_REPO=https://releases.passman.cc
SHA256=/tmp/sha256

# Check if root
if [[ $EUID -ne 0 ]]
then
    echo
    printf "\e[31mSorry, you are not root.\n\e[0mYou must type: \e[36msudo \e[0mbash $SCRIPTS/passman.sh\n"
    echo
    exit 1
fi

# Check if file is downloadable
echo "Checking latest released version on the Passman download server and if it's possible to download..."
if wget -q -T 10 -t 2 "$PASSVER_REPO/$PASSVER_FILE" -O /dev/null
then
   echo "Latest version is: $PASSVER"
else
    echo "Failed! Download is not available at the moment, try again later."
    echo "Please report this issue here: https://github.com/nextcloud/passman/issues/new"
    printf "\e[32m\n"
    read -p "Press any key to continue..." -n1 -s
    printf "\e[0m\n"

    exit 1
fi

# Test checksum
mkdir -p $SHA256
wget -q "$PASSVER_REPO/$PASSVER_FILE" -P "$SHA256"
wget -q "$PASSVER_REPO/$PASSVER_FILE.sha256" -P "$SHA256"
echo "Verifying integrity of $PASSVER_FILE..."
cd "$SHA256"
CHECKSUM_STATE=$(echo -n "$(sha256sum -c "$PASSVER_FILE.sha256")" | tail -c 2)
if [ "$CHECKSUM_STATE" != "OK" ]
then
    echo "Warning! Checksum does not match!"
    rm $SHA256 -R
    exit 1
else
    echo "SUCCESS! Checksum is OK!"
    rm $SHA256 -R
fi

# Download and install Passman
if [ ! -d $NCPATH/apps/passman ]
then
    wget -q "$PASSVER_REPO/$PASSVER_FILE" -P "$NCPATH/apps"
    tar -zxf "$NCPATH/apps/$PASSVER_FILE" -C "$NCPATH/apps"
    cd "$NCPATH/apps"
    rm "$PASSVER_FILE"
fi

# Enable Passman
if [ -d $NCPATH/apps/passman ]
then
    sudo -u www-data php $NCPATH/occ app:enable passman
    sleep 2
else
    echo "Something went wrong with the installation, Passman couln't be activated..."
    echo "Please report this issue here: https://github.com/nextcloud/vm/issues/new"
    printf "\e[32m\n"
    read -p "Press any key to continue..." -n1 -s
    printf "\e[0m\n"
    exit 1
fi
