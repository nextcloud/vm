#!/bin/bash

# T&M Hansson IT AB © - 2021, https://www.hanssonit.se/

true
SCRIPT_NAME="Adminer"
SCRIPT_EXPLAINER="Adminer is a full-featured database management tool written in PHP."
# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh || source <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Check if root
root_check

# Check if adminer is already installed
if ! is_this_installed adminer
then
    # Ask for installing
    install_popup "$SCRIPT_NAME"
else
    # Ask for removal or reinstallation
    reinstall_remove_menu "$SCRIPT_NAME"
    # Removal
    check_external_ip # Check that the script can see the external IP (apache fails otherwise)
    a2disconf adminer.conf
    rm -f $ADMINER_CONF
    rm -rf $ADMINERDIR
    check_command apt-get purge adminer -y
    restart_webserver
    # Show successful uninstall if applicable
    removal_popup "$SCRIPT_NAME"
fi

# Check that the script can see the external IP (apache fails otherwise)
check_external_ip

# Check distribution and version
check_distro_version

# Install Apache2 
install_if_not apache2
a2enmod headers
a2enmod rewrite
a2enmod ssl

# Install Adminer
apt-get update -q4 & spinner_loading
install_if_not adminer
curl_to_dir "http://www.adminer.org" "latest.php" "$ADMINERDIR"
curl_to_dir "https://raw.githubusercontent.com/Niyko/Hydra-Dark-Theme-for-Adminer/master" "adminer.css" "$ADMINERDIR"
ln -s "$ADMINERDIR"/latest.php "$ADMINERDIR"/adminer.php

# Only add TLS 1.3 on Ubuntu later than 20.04
if version 20.04 "$DISTRO" 20.04.10
then
    TLS13="+TLSv1.3"
fi

cat << ADMINER_CREATE > "$ADMINER_CONF"
 <VirtualHost *:80>
     RewriteEngine On
     RewriteRule ^(.*)$ https://%{HTTP_HOST}$1:9443 [R=301,L]
 </VirtualHost>

Listen 9443

<VirtualHost *:9443>
    Header add Strict-Transport-Security: "max-age=15768000;includeSubdomains"

    # Intermediate configuration
    SSLEngine               on
    SSLCompression          off
    SSLProtocol             -all +TLSv1.2 $TLS13
    SSLCipherSuite          ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384 
    SSLHonorCipherOrder     off
    SSLSessionTickets       off
    ServerSignature         off

    # Logs
    LogLevel warn
    CustomLog \${APACHE_LOG_DIR}/access.log combined
    ErrorLog \${APACHE_LOG_DIR}/error.log

    # This is needed to redirect access on http://$ADDRESS:9443/ to https://$ADDRESS:9443/
    ErrorDocument 400 https://$ADDRESS:9443/

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
    msg_box "Adminer was successfully installed and can be reached here:
https://$ADDRESS:9443

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
