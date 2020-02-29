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

# Check if adminer is already installed
print_text_in_color "$ICyan" "Checking if Adminer is already installed..."
if is_this_installed adminer
then
    choice=$(whiptail --radiolist "It seems like 'Adminer' is already installed.\nChoose what you want to do.\nSelect by pressing the spacebar and ENTER" "$WT_HEIGHT" "$WT_WIDTH" 4 \
    "Uninstall Adminer" "" OFF \
    "Reinstall Adminer" "" ON 3>&1 1>&2 2>&3)
    
    case "$choice" in
        "Uninstall Adminer")
            # Check that the script can see the external IP (apache fails otherwise)
            check_external_ip
            print_text_in_color "$ICyan" "Uninstalling Adminer and resetting all settings..."
            a2disconf adminer.conf
            rm $ADMINER_CONF
            rm $ADMINERDIR/adminer.php
            check_command apt purge adminer -y
            restart_webserver
            msg_box "Adminer was successfully uninstalled and all settings were resetted."
            exit
        ;;
        "Reinstall Adminer")
            # Check that the script can see the external IP (apache fails otherwise)
            check_external_ip
            print_text_in_color "$ICyan" "Reinstalling and securing Adminer..."
            a2disconf adminer.conf
            rm $ADMINER_CONF
            rm $ADMINERDIR/adminer.php
            check_command apt purge adminer -y
        ;;
        *)
        ;;
    esac
else
    print_text_in_color "$ICyan" "Installing and securing Adminer..."
fi

if [ -f "$SCRIPTS"/apps/adminer.sh ]
then
    msg_box "It seems like you have chosen the option 'Security' during the startup script and are using all files locally.\nPlease note that continuing will download files from www.adminer.org for installing and updating adminer, that will not be checked for integrity."
    if [[ "no" == $(ask_yes_or_no "Do you want to install adminer anyway?") ]]
    then
        exit
    fi
fi

# Warn user about HTTP/2
http2_warn Adminer

# Check that the script can see the external IP (apache fails otherwise)
check_external_ip

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
