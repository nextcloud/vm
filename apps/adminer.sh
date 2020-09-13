#!/bin/bash

# T&M Hansson IT AB © - 2020, https://www.hanssonit.se/

# shellcheck disable=2034,2059
true
SCRIPT_NAME="Adminer"
SCRIPT_EXPLAINER="Adminer is a tool that lets you see the content of your database."
# shellcheck source=lib.sh
. <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Check if root
root_check

# Show explainer
explainer_popup

# Check if adminer is already installed
print_text_in_color "$ICyan" "Checking if Adminer is already installed..."
if is_this_installed adminer
then
    # Ask for removal
    removal_popup
    # Removal
    check_external_ip # Check that the script can see the external IP (apache fails otherwise)
    a2disconf adminer.conf
    rm -f $ADMINER_CONF
    rm -rf $ADMINERDIR
    check_command apt-get purge adminer -y
    restart_webserver
    # Ask for reinstalling
    reinstall_popup
fi

# Inform users
print_text_in_color "$ICyan" "Installing and securing Adminer..."

# Check that the script can see the external IP (apache fails otherwise)
check_external_ip

# Check distrobution and version
check_distro_version

# Install Adminer
apt update -q4 & spinner_loading
install_if_not adminer
curl_to_dir "http://www.adminer.org" "latest.php" "$ADMINERDIR"
curl_to_dir "https://raw.githubusercontent.com/Niyko/Hydra-Dark-Theme-for-Adminer/master" "adminer.css" "$ADMINERDIR"
ln -s "$ADMINERDIR"/latest.php "$ADMINERDIR"/adminer.php

cat << ADMINER_CREATE > "$ADMINER_CONF"
Listen 8443

<VirtualHost *:8443>
    Header add Strict-Transport-Security: "max-age=15768000;includeSubdomains"
    SSLEngine on
    
### YOUR SERVER ADDRESS ###
#    ServerAdmin admin@example.com
#    ServerName adminer.example.com

### SETTINGS ###
    <FilesMatch "\.php$">
        SetHandler "proxy:unix:/run/php/php7.4-fpm.nextcloud.sock|fcgi://localhost"
    </FilesMatch>

    DocumentRoot $ADMINERDIR

<Directory $ADMINERDIR>
    <IfModule mod_dir.c>
        DirectoryIndex adminer.php
    </IfModule>
    AllowOverride None

    # Only allow connections from localhost:
    Require ip $GATEWAY/24
</Directory>

### LOCATION OF CERT FILES ###
    SSLCertificateFile /etc/ssl/certs/ssl-cert-snakeoil.pem
    SSLCertificateKeyFile /etc/ssl/private/ssl-cert-snakeoil.key

</VirtualHost>
ADMINER_CREATE

# Enable config
check_command a2ensite adminer.conf

if ! restart_webserver
then
msg_box "Apache2 could not restart...
The script will exit."
    exit 1
else
msg_box "Adminer was sucessfully installed and can be reached here:
https://$ADDRESS:8443

You can download more plugins and get more information here: 
https://www.adminer.org

Your PostgreSQL connection information can be found in $NCPATH/config/config.php.
These are the current values:

$(grep dbhost $NCPATH/config/config.php)
$(grep dbuser $NCPATH/config/config.php)
$(grep dbpassword $NCPATH/config/config.php)
$(grep dbname $NCPATH/config/config.php)

In case you try to access Adminer and get 'Forbidden' you need to change the IP in:
$ADMINER_CONF"
fi

exit
