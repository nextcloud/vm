#!/bin/bash

# Tech and Me, ©2016 - www.techandme.se

DISTRO=$(grep -ic "Ubuntu 16.04 LTS" /etc/lsb-release)
PHPMYADMINDIR=/usr/share/phpmyadmin
WANIP=$(dig +short myip.opendns.com @resolver1.opendns.com)
ADDRESS=$(hostname -I | cut -d ' ' -f 1)
PHPMYADMIN_CONF="/etc/apache2/conf-available/phpmyadmin.conf"
PW_FILE=$(cat /var/mysql_password.txt)
UPLOADPATH=""
SAVEPATH=""

# Check if root
        if [ "$(whoami)" != "root" ]; then
        echo
        echo -e "\e[31mSorry, you are not root.\n\e[0mYou must type: \e[36msudo \e[0mbash $SCRIPTS/phpmyadmin_install.sh"
        echo
        exit 1
fi

# Check Ubuntu version

if [ $DISTRO -eq 1 ]
then
        echo "Ubuntu 16.04 LTS OK!"
else
        echo "Ubuntu 16.04 LTS is required to run this script."
        echo "Please install that distro and try again."
        exit 1
fi

echo
echo "Installing and securing phpMyadmin..."
echo
sleep 2

# Install phpmyadmin
echo 'phpmyadmin phpmyadmin/dbconfig-install boolean true' | debconf-set-selections
echo 'phpmyadmin phpmyadmin/app-password-confirm password $PW_FILE' | debconf-set-selections
echo 'phpmyadmin phpmyadmin/mysql/admin-pass password $PW_FILE' | debconf-set-selections
echo 'phpmyadmin phpmyadmin/mysql/app-pass password $PW_FILE' | debconf-set-selections
echo 'phpmyadmin phpmyadmin/reconfigure-webserver multiselect apache2' | debconf-set-selections
apt-get update
apt-get install -y -q \
	php-gettext \
	phpmyadmin

# Secure phpMyadmin
if [ -f $PHPMYADMIN_CONF ];
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
        Require ip $WANIP
	Require ip $ADDRESS
        Require ip 127.0.0.1
        Require ip ::1
      </RequireAny>
    </IfModule>

        <IfModule !mod_authz_core.c>
# Apache 2.2
        Order Deny,Allow
        Deny from All
        Allow from $WANIP
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

service apache2 restart

echo
echo "$PHPMYADMIN_CONF was successfully secured."
echo
sleep 3

exit 0
