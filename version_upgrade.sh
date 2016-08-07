#!/bin/bash

# Tech and Me, ©2016 - www.techandme.se
#
# Check if root
        if [ "$(whoami)" != "root" ]; then
        echo
        echo -e "\e[31mSorry, you are not root.\n\e[0mYou must type: \e[36msudo \e[0mbash $SCRIPTS/version_upgrade.sh"
        echo
        exit 1
fi

### V1.1 ###

### V1.2 ###

### V1.3 ###

exit 0
