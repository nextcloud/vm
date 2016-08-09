#!/bin/bash

# Tech and Me, ©2016 - www.techandme.se

# Variable
SCRIPTS="/var/scripts/"
VERSION=$(cat $SCRIPTS/version)

# Check if root
        if [ "$(whoami)" != "root" ]; then
        echo
        echo -e "\e[31mSorry, you are not root.\n\e[0mYou must type: \e[36msudo \e[0mbash $SCRIPTS/version_upgrade.sh"
        echo
        exit 1
fi

### V1.1 ###
 if grep -q 1.0 "$SCRIPTS/version"; then
   rm $SCRIPTS/version
   echo "1.1" > $SCRIPTS/version
   echo
   echo "Installing version 1.1 ..."
   echo
   sleep 2

# Version upgrade here

 else
   echo
   echo
   echo "Current version is $VERSION..."
   echo
   echo "Version 1.1 is not going to be installed, moving on..."
   echo
 fi

### V1.2 ###
 if grep -q 1.1 "$SCRIPTS/version"; then
   rm $SCRIPTS/version
   echo "1.2" > $SCRIPTS/version
   echo
   echo "Installing version 1.2 ..."
   echo
   sleep 2

# Version upgrade here

 else
   echo 
   echo
   echo "Current version is $VERSION..."
   echo 
   echo "Version 1.2 is not going to be installed, moving on..."
   echo
 fi

exit 0
