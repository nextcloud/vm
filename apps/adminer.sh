#!/bin/bash

# T&M Hansson IT AB © - 2020, https://www.hanssonit.se/

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

# Check if adminer ist already installed
print_text_in_color "$ICyan" "Checking if Adminer is already installed..."
if is_this_installed adminer
then
    msg_box "It seems like 'adminer' is already installed."
    if [[ "no" == $(ask_yes_or_no "Do you want to continue anyway?") ]]
    then
        exit
    fi
fi

print_text_in_color "$ICyan" "Installing and securing Adminer..."

# Warn user about HTTP/2
http2_warn Adminer

# Check that the script can see the external IP (apache fails otherwise)
if [ -z "$WANIP4" ]
then
    print_text_in_color "$IRed" "WANIP4 is an emtpy value, Apache will fail on reboot due to this. Please check your network and try again."
    sleep 3
    exit 1
fi

# Check distrobution and version
check_distro_version

# Install Adminer
apt update -q4 & spinner_loading
install_if_not adminer
curl_to_dir "http://www.adminer.org" "latest.php" "$ADMINERDIR"
ln -s "$ADMINERDIR"/latest.php "$ADMINERDIR"/adminer.php

cat << ADMINER_CREATE > "$ADMINER_CONF"
Alias /adminer.php $ADMINERDIR/adminer.php

<Directory $ADMINERDIR>

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

Your PostgreSQL connection information can be found in $NCPATH/config/config.php

In case you try to access Adminer and get 'Forbidden' you need to change the IP in:
$ADMINER_CONF"
fi

exit
