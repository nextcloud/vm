#!/bin/bash

# Tech and Me, ©2017 - www.techandme.se

OS=$(grep -ic "Ubuntu" /etc/issue.net)
PHPMYADMINDIR=/usr/share/phpmyadmin
WANIP=$(dig +short myip.opendns.com @resolver1.opendns.com)
ADDRESS=$(hostname -I | cut -d ' ' -f 1)
PHPMYADMIN_CONF="/etc/apache2/conf-available/phpmyadmin.conf"
PW_FILE=$(cat /var/mysql_password.txt)
UPLOADPATH=""
SAVEPATH=""

# Check if root
if [ "$(whoami)" != "root" ]
then
    echo
    printf "\e[31mSorry, you are not root.\n\e[0mYou must type: \e[36msudo \e[0mbash $SCRIPTS/phpmyadmin_install.sh\n"
    echo # remove echo here and do \n instead there are more places like this iirc
    sleep 3
    exit 1
fi

# Check that the script can see the external IP (apache fails otherwise)
if [ -z "$WANIP" ]
then
    echo "WANIP is an emtpy value, Apache will fail on reboot due to this. Please check your network and try again"
    sleep 3
    exit 1
fi

# Check Ubuntu version
echo
echo "Checking server OS and version..."
if [ $OS -eq 1 ]
then
    sleep 1
else
    echo "Ubuntu Server is required to run this script."
    echo "Please install that distro and try again."
    sleep 3
    exit 1
fi

DISTRO=$(lsb_release -sd | cut -d ' ' -f 2)
version(){
    local h t v

    [[ $2 = "$1" || $2 = "$3" ]] && return 0

    v=$(printf '%s\n' "$@" | sort -V)
    h=$(head -n1 <<<"$v")
    t=$(tail -n1 <<<"$v")

    [[ $2 != "$h" && $2 != "$t" ]]
}

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
sleep 2

# Install phpmyadmin
echo 'phpmyadmin phpmyadmin/dbconfig-install boolean true' | debconf-set-selections
echo 'phpmyadmin phpmyadmin/app-password-confirm password $PW_FILE' | debconf-set-selections
echo 'phpmyadmin phpmyadmin/mysql/admin-pass password $PW_FILE' | debconf-set-selections
echo 'phpmyadmin phpmyadmin/mysql/app-pass password $PW_FILE' | debconf-set-selections
echo 'phpmyadmin phpmyadmin/reconfigure-webserver multiselect apache2' | debconf-set-selections
apt update -q2
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

service apache2 restart
if [[ $? > 0 ]]
then 
    echo "Apache2 could not restart..."
    echo "The script will exit."
    exit 1
else
    echo
    echo "$PHPMYADMIN_CONF was successfully secured."
    echo
    sleep 3
fi
