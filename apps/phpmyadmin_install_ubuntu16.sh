#!/bin/bash

# Tech and Me © - 2017, https://www.techandme.se/

# shellcheck disable=2034,2059
true
# shellcheck source=lib.sh
. <(curl -sL https://raw.githubusercontent.com/morph027/vm/master/lib.sh)

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Check if root
if ! is_root
then
    printf "\n${Red}Sorry, you are not root.\n${Color_Off}You must type: ${Cyan}sudo ${Color_Off}bash %s/phpmyadmin_install.sh\n" "$SCRIPTS"
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

# Check Ubuntu version
echo
echo "Checking server OS and version..."
if [ "$OS" != 1 ]
then
    echo "Ubuntu Server is required to run this script."
    echo "Please install that distro and try again."
    sleep 3
    exit 1
fi


if ! version 16.04 "$DISTRO" 16.04.4; then
    echo "Ubuntu version seems to be $DISTRO"
    echo "It must be between 16.04 - 16.04.4"
    echo "Please install that version and try again."
    exit 1
fi

echo
echo "Installing and securing phpMyadmin..."
echo "This may take a while, please don't abort."
echo

# Install phpmyadmin
echo "phpmyadmin phpmyadmin/dbconfig-install boolean true" | debconf-set-selections
echo "phpmyadmin phpmyadmin/app-password-confirm password $PW_FILE" | debconf-set-selections
echo "phpmyadmin phpmyadmin/mysql/admin-pass password $PW_FILE" | debconf-set-selections
echo "phpmyadmin phpmyadmin/mysql/app-pass password $PW_FILE" | debconf-set-selections
echo "phpmyadmin phpmyadmin/reconfigure-webserver multiselect apache2" | debconf-set-selections
apt update -q4 & spinner_loading
apt install -y -q \
    php-gettext \
    phpmyadmin

# Remove Password file
rm /var/mysql_password.txt

# Secure phpMyadmin
if [ -f $PHPMYADMIN_CONF ]
then
    rm $PHPMYADMIN_CONF
fi
touch "$PHPMYADMIN_CONF"
cat << CONF_CREATE > "$PHPMYADMIN_CONF"
# phpMyAdmin default Apache configuration

Alias /phpmyadmin $PHPMYADMINDIR

<Directory $PHPMYADMINDIR>
        Options FollowSymLinks
        DirectoryIndex index.php

    <IfModule mod_php.c>
        <IfModule mod_mime.c>
            AddType application/x-httpd-php .php
        </IfModule>
        <FilesMatch ".+\.php$">
            SetHandler application/x-httpd-php
        </FilesMatch>

        php_flag magic_quotes_gpc Off
        php_flag track_vars On
        php_flag register_globals Off
        php_admin_flag allow_url_fopen On
        php_value include_path .
        php_admin_value upload_tmp_dir /var/lib/phpmyadmin/tmp
        php_admin_value open_basedir /usr/share/phpmyadmin/:/etc/phpmyadmin/:/var/lib/phpmyadmin/:/usr/share/php/php-gettext/:/usr/share/javascript/:/usr/share/php/tcpdf/:/usr/share/doc/phpm$
    </IfModule>

    <IfModule mod_authz_core.c>
# Apache 2.4
      <RequireAny>
        Require ip $WANIP4
    Require ip $ADDRESS
        Require ip 127.0.0.1
        Require ip ::1
      </RequireAny>
    </IfModule>

        <IfModule !mod_authz_core.c>
# Apache 2.2
        Order Deny,Allow
        Deny from All
        Allow from $WANIP4
        Allow from $ADDRESS
        Allow from ::1
        Allow from localhost
    </IfModule>
</Directory>

# Authorize for setup
<Directory $PHPMYADMINDIR/setup>
   Require all denied
</Directory>

# Authorize for setup
<Directory $PHPMYADMINDIR/setup>
    <IfModule mod_authz_core.c>
        <IfModule mod_authn_file.c>
            AuthType Basic
            AuthName "phpMyAdmin Setup"
            AuthUserFile /etc/phpmyadmin/htpasswd.setup
        </IfModule>
        Require valid-user
    </IfModule>
</Directory>

# Disallow web access to directories that don't need it
<Directory $PHPMYADMINDIR/libraries>
    Require all denied
</Directory>
<Directory $PHPMYADMINDIR/setup/lib>
    Require all denied
</Directory>
CONF_CREATE

# Secure phpMyadmin even more
CONFIG=/var/lib/phpmyadmin/config.inc.php
touch $CONFIG
cat << CONFIG_CREATE >> "$CONFIG"
<?php
\$i = 0;
\$i++;
\$cfg['Servers'][\$i]['host'] = 'localhost';
\$cfg['Servers'][\$i]['extension'] = 'mysql';
\$cfg['Servers'][\$i]['connect_type'] = 'socket';
\$cfg['Servers'][\$i]['compress'] = false;
\$cfg['Servers'][\$i]['auth_type'] = 'cookie';
\$cfg['UploadDir'] = '$SAVEPATH';
\$cfg['SaveDir'] = '$UPLOADPATH';
\$cfg['BZipDump'] = false;
\$cfg['Lang'] = 'en';
\$cfg['ServerDefault'] = 1;
\$cfg['ShowPhpInfo'] = true;
\$cfg['Export']['lock_tables'] = true;
?>
CONFIG_CREATE

if ! service apache2 restart
then 
    echo "Apache2 could not restart..."
    echo "The script will exit."
    exit 1
else
    echo
    echo "$PHPMYADMIN_CONF was successfully secured."
    echo
fi
