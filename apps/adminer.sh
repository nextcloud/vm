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
root_check

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
echo "Installing and securing Adminer..."
echo

# Install Adminer
apt update -q4 & spinner_loading
install_if_not adminer
sudo wget -q "http://www.adminer.org/latest.php" -O "$ADMINERDIR"/latest.php
sudo ln -s "$ADMINERDIR"/latest.php "$ADMINERDIR"/adminer.php

cat << ADMINER_CREATE > "$ADMINER_CONF"
Alias /adminer.php "$ADMINERDIR"/adminer.php

<Directory "$ADMINERDIR">

<IfModule mod_dir.c>
DirectoryIndex adminer.php
</IfModule>
AllowOverride None

# Only allow connections from localhost:
Require ip $GATEWAY/24

</Directory>
ADMINER_CREATE

# Enable config
check_command a2enconf adminer.conf

if ! restart_webserver
then
msg_box "Apache2 could not restart...
The script will exit."
    exit 1
else
msg_box "Adminer was sucessfully installed and can be reached here:
http://$ADDRESS/adminer.php

You can download more plugins and get more information here: 
https://www.adminer.org

Your PostgreSQL connection information can be found in $NCPATH/config/confgig.php

In case you try to access Adminer and get 'Forbidden' you need to change the IP in:
$ADMINER_CONF"
fi
