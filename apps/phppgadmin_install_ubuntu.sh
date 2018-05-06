#!/bin/bash

# Tech and Me © - 2018, https://www.techandme.se/

# shellcheck disable=2034,2059
true
# shellcheck source=lib.sh
. <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Check if root
if ! is_root
then
    printf "\n${Red}Sorry, you are not root.\n${Color_Off}You must type: ${Cyan}sudo ${Color_Off}bash %s/phppgadmin_install_ubuntu16.sh\n" "$SCRIPTS"
    sleep 3
    exit 1
fi

# Check that the script can see the external IP (apache fails otherwise)
if [ -z "$WANIP4" ]
then
    echo "WANIP4 is an emtpy value, Apache will fail on reboot due to this. Please check your network and try again"
    sleep 3
    exit 1
fi

# Check distrobution and version
check_distro_version

echo
echo "Installing and securing phpPGadmin..."
echo "This may take a while, please don't abort."
echo

# Install phpPGadmin
apt update -q4 & spinner_loading
apt install -y -q \
    php-gettext \
    phppgadmin

# Allow local access
sed -i "s|Require local|Require ip $GATEWAY/24|g" /etc/apache2/conf-available/phppgadmin.conf

if ! service apache2 restart
then
    echo "Apache2 could not restart..."
    echo "The script will exit."
    exit 1
fi
