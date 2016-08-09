#!/bin/bash

# Tech and Me, ©2016 - www.techandme.se
#
# This install from Nextcloud official stable build with PHP 7, MySQL 5.7 and Apche 2.4.
# Ubuntu 16.04 is required. (Other distro's will likely not work, but could eg. debian)

set -e

# Nextcloud version
STABLEVERSION="nextcloud-9.0.53"

# Ubuntu version
OS=$(grep -ic "Ubuntu" /etc/issue.net)

# Nextcloud apps
CONVER=$(wget -q https://raw.githubusercontent.com/owncloud/contacts/master/appinfo/info.xml && grep -Po "(?<=<version>)[^<]*(?=</version>)" info.xml && rm info.xml)
CONVER_FILE=contacts.tar.gz
CONVER_REPO=https://github.com/owncloud/contacts/releases/download
CALVER=$(wget -q https://raw.githubusercontent.com/owncloud/calendar/master/appinfo/info.xml && grep -Po "(?<=<version>)[^<]*(?=</version>)" info.xml && rm info.xml)
CALVER_FILE=calendar.tar.gz
CALVER_REPO=https://github.com/owncloud/calendar/releases/download

# Passwords
SHUF=$(shuf -i 13-15 -n 1)
MYSQL_PASS=$(cat /dev/urandom | tr -dc "a-zA-Z0-9@#*=" | fold -w $SHUF | head -n 1)
PW_FILE=/var/mysql_password.txt

# Directories
SCRIPTS=/var/scripts
HTML=/var/www
NCPATH=$HTML/nextcloud
GPGDIR=/tmp/gpg
NCDATA=/var/ncdata

# Apache vhosts
SSL_CONF="/etc/apache2/sites-available/nextcloud_ssl_domain_self_signed.conf"
HTTP_CONF="/etc/apache2/sites-available/nextcloud_http_domain_self_signed.conf"

# Network
IFACE=$(lshw -c network | grep "logical name" | awk '{print $3}')
ADDRESS=$(hostname -I | cut -d ' ' -f 1)

# Devices
DEVICE="/dev/mmcblk0"
DEV="/dev/sda"
DEVHD="/dev/sda2"
DEVSP="/dev/sda1"

# Repositories
GITHUB_REPO="https://raw.githubusercontent.com/ezraholm50/NextBerry/master"
STATIC="https://raw.githubusercontent.com/ezraholm50/NextBerry/master/static"
NCREPO="https://download.nextcloud.com/server/releases"
GPGKEY="https://nextcloud.com/nextcloud.asc"

# Commands
CLEARBOOT=$(dpkg -l linux-* | awk '/^ii/{ print $2}' | grep -v -e `uname -r | cut -f1,2 -d"-"` | grep -e [0-9] | xargs sudo apt-get -y purge)

# Linux user, and Nextcloud user
UNIXUSER=ncadmin
UNIXPASS=nextcloud

# Check if root
        if [ "$(whoami)" != "root" ]; then
        echo
        echo -e "\e[31mSorry, you are not root.\n\e[0mYou must type: \e[36msudo \e[0mbash $SCRIPTS/nextcloud_install_production.sh"
        echo
        exit 1
fi

# Check Ubuntu version
echo "Checking server OS and version..."
if [ $OS -eq 1 ]
then
        sleep 1
else
        echo "Ubuntu Server is required to run this script."
        echo "Please install that distro and try again."
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
    echo "Ubuntu version $DISTRO must be between 16.04 - 16.04.4"
    exit
fi

# Check if key is available
if wget -q --spider "$NCREPO" > /dev/null; then
        echo "Nextcloud repo OK"
else
        echo "Nextcloud repo is not available, exiting..."
        exit 1
fi

# Check if it's a clean server
echo "Checking if it's a clean server..."
if [ $(dpkg-query -W -f='${Status}' mysql-common 2>/dev/null | grep -c "ok installed") -eq 1 ];
then
        echo "MySQL is installed, it must be a clean server."
        exit 1
fi

if [ $(dpkg-query -W -f='${Status}' apache2 2>/dev/null | grep -c "ok installed") -eq 1 ];
then
        echo "Apache2 is installed, it must be a clean server."
        exit 1
fi

if [ $(dpkg-query -W -f='${Status}' php 2>/dev/null | grep -c "ok installed") -eq 1 ];
then
        echo "PHP is installed, it must be a clean server."
        exit 1
fi

if [ $(dpkg-query -W -f='${Status}' nextcloud 2>/dev/null | grep -c "ok installed") -eq 1 ];
then
	echo "Nextcloud is installed, it must be a clean server."
	exit 1
fi

#if [ $(dpkg-query -W -f='${Status}' ubuntu-server 2>/dev/null | grep -c "ok installed") -eq 0 ];
#then
#        echo "'ubuntu-server' is not installed, this doesn't seem to be a server."
#        echo "Please install the server version of Ubuntu and restart the script"
#        exit 1 
#fi

# Create $UNIXUSER if not existing
if id "$UNIXUSER" >/dev/null 2>&1
then
        echo "$UNIXUSER already exists!"
else
	adduser --disabled-password --gecos "" $UNIXUSER
        echo -e "$UNIXUSER:$UNIXPASS" | chpasswd
        usermod -aG sudo $UNIXUSER
fi

if [ -d /home/$UNIXUSER ];
then
	echo "$UNIXUSER OK!"
else
	echo "Something went wrong when creating the user... Script will exit."
	exit 1
fi

# Create $SCRIPTS dir
      	if [ -d $SCRIPTS ]; then
      		sleep 1
      		else
      	mkdir -p $SCRIPTS
fi

# Change DNS
if ! [ -x "$(command -v resolvconf)" ]; then
	apt-get install resolvconf -y -q
	dpkg-reconfigure resolvconf
else
	echo 'reolvconf is installed.' >&2
fi

echo "nameserver 8.8.8.8" > /etc/resolvconf/resolv.conf.d/base
echo "nameserver 8.8.4.4" >> /etc/resolvconf/resolv.conf.d/base

# Check network
if ! [ -x "$(command -v nslookup)" ]; then
	apt-get install dnsutils -y -q
else
	echo 'dnsutils is installed.' >&2
fi
if ! [ -x "$(command -v ifup)" ]; then
	apt-get install ifupdown -y -q
else
	echo 'ifupdown is installed.' >&2
fi
sudo ifdown $IFACE && sudo ifup $IFACE
nslookup google.com
if [[ $? > 0 ]]
then
	echo "Network NOT OK. You must have a working Network connection to run this script."
        exit 1
else
	echo "Network OK."
fi

# Update and upgrade
apt-get -y autoclean \
	autoremove \
	update \
	upgrade
apt-get -f install -y
dpkg --configure --pending

# Install various packages
apt-get install -y ntp \
		module-init-tools \
		miredo \
		libminiupnpc10

# Only use swap to prevent out of memory.
echo "vm.swappiness = 1" >> /etc/sysctl.conf
sysctl -p

# Set locales
apt-get install language-pack-en-base -y
sudo locale-gen "sv_SE.UTF-8" && sudo dpkg-reconfigure --frontend=noninteractive locales

# Install aptitude
apt-get install aptitude -y

# Write MySQL pass to file and keep it safe
echo "$MYSQL_PASS" > $PW_FILE
chmod 600 $PW_FILE
chown root:root $PW_FILE

# Install MYSQL 5.7
apt-get install software-properties-common -y
echo "mysql-server-5.7 mysql-server/root_password password $MYSQL_PASS" | debconf-set-selections
echo "mysql-server-5.7 mysql-server/root_password_again password $MYSQL_PASS" | debconf-set-selections
apt-get install mysql-server-5.7 -y

# mysql_secure_installation
apt-get -y install expect
SECURE_MYSQL=$(expect -c "
set timeout 10
spawn mysql_secure_installation
expect \"Enter current password for root:\"
send \"$MYSQL_PASS\r\"
expect \"Would you like to setup VALIDATE PASSWORD plugin?\"
send \"n\r\"
expect \"Change the password for root ?\"
send \"n\r\"
expect \"Remove anonymous users?\"
send \"y\r\"
expect \"Disallow root login remotely?\"
send \"y\r\"
expect \"Remove test database and access to it?\"
send \"y\r\"
expect \"Reload privilege tables now?\"
send \"y\r\"
expect eof
")
echo "$SECURE_MYSQL"
apt-get -y purge expect

# Install Apache
apt-get install apache2 -y
a2enmod rewrite \
        headers \
        env \
        dir \
        mime \
        ssl \
        setenvif

# Set hostname and ServerName
sudo sh -c "echo 'ServerName nextcloud' >> /etc/apache2/apache2.conf"
sudo hostnamectl set-hostname nextcloud
service apache2 restart

# Install PHP 7.0
apt-get update -q2
apt-get install -y \
        libapache2-mod-php7.0 \
	php7.0-common \
	php7.0-mysql \
	php7.0-intl \
	php7.0-mcrypt \
	php7.0-ldap \
	php7.0-imap \
	php7.0-cli \
	php7.0-gd \
	php7.0-pgsql \
	php7.0-json \
	php7.0-sqlite3 \
	php7.0-curl \
	php7.0-xml \
	php7.0-zip \
	php7.0-mbstring \
	php-smbclient

# Enable SMB client
echo '# This enables php-smbclient' >> /etc/php/7.0/apache2/php.ini
echo 'extension="smbclient.so"' >> /etc/php/7.0/apache2/php.ini

# Install Unzip
apt-get install unzip -y

# Download and validate Nextcloud package
wget -q $NCREPO/$STABLEVERSION.zip -P $HTML
mkdir -p $GPGDIR
wget -q $NCREPO/$STABLEVERSION.zip.asc -P $GPGDIR
wget -q $GPGKEY -P $GPGDIR
chmod -R 600 $GPGDIR
gpg  --homedir $GPGDIR --import $GPGDIR/nextcloud.asc
gpg  --homedir $GPGDIR --verify $GPGDIR/$STABLEVERSION.zip.asc $HTML/$STABLEVERSION.zip
if [[ $? > 0 ]]
then
        echo "Package NOT OK! Installation is aborted..."
        exit 1
else
        echo "Package OK!"
fi

# Cleanup
rm -r $GPGDIR

# Extract package
unzip -q $HTML/$STABLEVERSION.zip -d $HTML
rm $HTML/$STABLEVERSION.zip

# Secure permissions
wget -q $STATIC/setup_secure_permissions_nextcloud.sh -P $SCRIPTS
bash $SCRIPTS/setup_secure_permissions_nextcloud.sh

# Install Nextcloud
cd $NCPATH
sudo -u www-data php occ maintenance:install --data-dir "$NCDATA" --database "mysql" --database-name "nextcloud_db" --database-user "root" --database-pass "$MYSQL_PASS" --admin-user "$UNIXUSER" --admin-pass "$UNIXPASS"
echo
echo "Nextcloud version:"
sudo -u www-data php $NCPATH/occ status
echo
sleep 3

# Prepare cron.php to be run every 15 minutes
crontab -u www-data -l | { cat; echo "*/15  *  *  *  * php -f $NCPATH/cron.php > /dev/null 2>&1"; } | crontab -u www-data -

# Change values in php.ini (increase max file size)
# max_execution_time
sed -i "s|max_execution_time = 30|max_execution_time = 3500|g" /etc/php/7.0/apache2/php.ini
# max_input_time
sed -i "s|max_input_time = 60|max_input_time = 3600|g" /etc/php/7.0/apache2/php.ini
# memory_limit
sed -i "s|memory_limit = 128M|memory_limit = 512M|g" /etc/php/7.0/apache2/php.ini
# post_max
sed -i "s|post_max_size = 8M|post_max_size = 1100M|g" /etc/php/7.0/apache2/php.ini
# upload_max
sed -i "s|upload_max_filesize = 2M|upload_max_filesize = 1000M|g" /etc/php/7.0/apache2/php.ini

# Install Figlet
apt-get install figlet -y

# Generate $HTTP_CONF
if [ -f $HTTP_CONF ];
        then
        echo "Virtual Host exists"
else
        touch "$HTTP_CONF"
        cat << HTTP_CREATE > "$HTTP_CONF"
<VirtualHost *:80>

### YOUR SERVER ADDRESS ###
#    ServerAdmin admin@example.com
#    ServerName example.com
#    ServerAlias subdomain.example.com

### SETTINGS ###
    DocumentRoot $NCPATH

    <Directory $NCPATH>
    Options Indexes FollowSymLinks
    AllowOverride All
    Require all granted
    Satisfy Any
    </Directory>

    Alias /nextcloud "$NCPATH/"

    <IfModule mod_dav.c>
    Dav off
    </IfModule>

    <Directory "$NCDATA">
    # just in case if .htaccess gets disabled
    Require all denied
    </Directory>

    SetEnv HOME $NCPATH
    SetEnv HTTP_HOME $NCPATH

</VirtualHost>
HTTP_CREATE
echo "$HTTP_CONF was successfully created"
sleep 3
fi

# Generate $SSL_CONF
if [ -f $SSL_CONF ];
        then
        echo "Virtual Host exists"
else
        touch "$SSL_CONF"
        cat << SSL_CREATE > "$SSL_CONF"
<VirtualHost *:443>
    Header add Strict-Transport-Security: "max-age=15768000;includeSubdomains"
    SSLEngine on

### YOUR SERVER ADDRESS ###
#    ServerAdmin admin@example.com
#    ServerName example.com
#    ServerAlias subdomain.example.com

### SETTINGS ###
    DocumentRoot $NCPATH

    <Directory $NCPATH>
    Options Indexes FollowSymLinks
    AllowOverride All
    Require all granted
    Satisfy Any
    </Directory>

    Alias /nextcloud "$NCPATH/"

    <IfModule mod_dav.c>
    Dav off
    </IfModule>

    <Directory "$NCDATA">
    # just in case if .htaccess gets disabled
    Require all denied
    </Directory>

    SetEnv HOME $NCPATH
    SetEnv HTTP_HOME $NCPATH

### LOCATION OF CERT FILES ###
    SSLCertificateFile /etc/ssl/certs/ssl-cert-snakeoil.pem
    SSLCertificateKeyFile /etc/ssl/private/ssl-cert-snakeoil.key
</VirtualHost>
SSL_CREATE
echo "$SSL_CONF was successfully created"
sleep 3
fi

# Enable new config
a2ensite nextcloud_ssl_domain_self_signed.conf
a2ensite nextcloud_http_domain_self_signed.conf
a2dissite default-ssl
service apache2 restart

## Set config values
# Experimental apps
sudo -u www-data php $NCPATH/occ config:system:set appstore.experimental.enabled --value="true"
# Default mail server as an example (make this user configurable?)
sudo -u www-data php $NCPATH/occ config:system:set mail_smtpmode --value="smtp"
sudo -u www-data php $NCPATH/occ config:system:set mail_smtpauth --value="1"
sudo -u www-data php $NCPATH/occ config:system:set mail_smtpport --value="465"
sudo -u www-data php $NCPATH/occ config:system:set mail_smtphost --value="smtp.gmail.com"
sudo -u www-data php $NCPATH/occ config:system:set mail_smtpauthtype --value="LOGIN"
sudo -u www-data php $NCPATH/occ config:system:set mail_from_address --value="www.techandme.se"
sudo -u www-data php $NCPATH/occ config:system:set mail_domain --value="gmail.com"
sudo -u www-data php $NCPATH/occ config:system:set mail_smtpsecure --value="ssl"
sudo -u www-data php $NCPATH/occ config:system:set mail_smtpname --value="www.techandme.se@gmail.com"
sudo -u www-data php $NCPATH/occ config:system:set mail_smtppassword --value="vinr vhpa jvbh hovy"

# Install Libreoffice Writer to be able to read MS documents.
sudo apt-get install --no-install-recommends libreoffice-writer -y

# Install packages for Webmin
apt-get install -y zip perl libnet-ssleay-perl openssl libauthen-pam-perl libpam-runtime libio-pty-perl apt-show-versions python

# Install Webmin
sed -i '$a deb http://download.webmin.com/download/repository sarge contrib' /etc/apt/sources.list
wget -q http://www.webmin.com/jcameron-key.asc -O- | sudo apt-key add -
apt-get update -q2
apt-get install webmin -y

# Download and install Documents
#if [ -d $NCPATH/apps/documents ]; then
#sleep 1
#else
#wget -q https://github.com/owncloud/documents/archive/master.zip -P $NCPATH/apps
#cd $NCPATH/apps
#unzip -q master.zip
#rm master.zip
#mv documents-master/ documents/
#fi

# Enable documents
#if [ -d $NCPATH/apps/documents ]; then
#sudo -u www-data php $NCPATH/occ app:enable documents
#sudo -u www-data php $NCPATH/occ config:system:set preview_libreoffice_path --value="/usr/bin/libreoffice"
#fi

# Download and install Contacts
if [ -d $NCPATH/apps/contacts ]; then
sleep 1
else
wget -q $CONVER_REPO/v$CONVER/$CONVER_FILE -P $NCPATH/apps
tar -zxf $NCPATH/apps/$CONVER_FILE -C $NCPATH/apps
cd $NCPATH/apps
rm $CONVER_FILE
fi

# Enable Contacts
if [ -d $NCPATH/apps/contacts ]; then
sudo -u www-data php $NCPATH/occ app:enable contacts
fi

# Download and install Calendar
if [ -d $NCPATH/apps/calendar ]; then
sleep 1
else
wget -q $CALVER_REPO/v$CALVER/$CALVER_FILE -P $NCPATH/apps
tar -zxf $NCPATH/apps/$CALVER_FILE -C $NCPATH/apps
cd $NCPATH/apps
rm $CALVER_FILE
fi

# Enable Calendar
if [ -d $NCPATH/apps/calendar ]; then
sudo -u www-data php $NCPATH/occ app:enable calendar
fi

# Change roots .bash_profile
        if [ -f $SCRIPTS/change-root-profile.sh ];
                then
                echo "change-root-profile.sh exists"
                else
        wget -q $STATIC/change-root-profile.sh -P $SCRIPTS
fi
# Change $UNIXUSER .bash_profile
        if [ -f $SCRIPTS/change-ncadmin-profile.sh ];
                then
                echo "change-ncadmin-profile.sh  exists"
                else
        wget -q $STATIC/change-ncadmin-profile.sh -P $SCRIPTS
fi
# Get startup-script for root
        if [ -f $SCRIPTS/nextcloud-startup-script.sh ];
                then
                echo "nextcloud-startup-script.sh exists"
                else
        wget -q $GITHUB_REPO/nextcloud-startup-script.sh -P $SCRIPTS
fi

# Welcome message after login (change in /home/$UNIXUSER/.profile
        if [ -f $SCRIPTS/instruction.sh ];
                then
                echo "instruction.sh exists"
                else
        wget -q $STATIC/instruction.sh -P $SCRIPTS
fi

# Get nextcloud-startup-script.sh
        if [ -f $SCRIPTS/nextcloud-startup-script.sh ];
                then
                echo "nextcloud-startup-script.sh exists"
                else
        wget -q $GITHUB_REPO/nextcloud-startup-script.sh -P $SCRIPTS
fi

# Clears command history on every login
        if [ -f $SCRIPTS/history.sh ];
                then
                echo "history.sh exists"
                else
        wget -q $STATIC/history.sh -P $SCRIPTS
fi

# Change root profile
        	bash $SCRIPTS/change-root-profile.sh
if [[ $? > 0 ]]
then
	echo "change-root-profile.sh were not executed correctly."
	sleep 10
else
	echo "change-root-profile.sh script executed OK."
	rm $SCRIPTS/change-root-profile.sh
	sleep 2
fi
# Change $UNIXUSER profile
        	bash $SCRIPTS/change-ncadmin-profile.sh
if [[ $? > 0 ]]
then
	echo "change-ncadmin-profile.sh were not executed correctly."
	sleep 10
else
	echo "change-ncadmin-profile.sh executed OK."
	rm $SCRIPTS/change-ncadmin-profile.sh
	sleep 2
fi

# Get script for Redis
        if [ -f $SCRIPTS/redis-server-ubuntu16.sh ];
                then
                echo "redis-server-ubuntu16.sh exists"
                else
        wget -q $STATIC/redis-server-ubuntu16.sh -P $SCRIPTS
fi

# Make $SCRIPTS excutable
chmod +x -R $SCRIPTS
chown root:root -R $SCRIPTS

# Allow $UNIXUSER to run these scripts
chown $UNIXUSER:$UNIXUSER $SCRIPTS/instruction.sh
chown $UNIXUSER:$UNIXUSER $SCRIPTS/history.sh

# Install Redis
bash $SCRIPTS/redis-server-ubuntu16.sh
rm $SCRIPTS/redis-server-ubuntu16.sh

# Upgrade
apt-get update -q2
aptitude full-upgrade -y

# Remove LXD (always shows up as failed during boot)
apt-get purge lxd -y

# Cleanup login screen
rm /etc/update-motd.d/00-header
rm /etc/update-motd.d/10-help-text

# Cleanup
echo "$CLEARBOOT"
apt-get autoremove -y
apt-get autoclean
if [ -f /home/$UNIXUSER/*.sh ];
then
	rm /home/$UNIXUSER/*.sh
fi

if [ -f /root/*.sh ];
then
	rm /root/*.sh
fi

# Set secure permissions final (./data/.htaccess has wrong permissions otherwise)
bash $SCRIPTS/setup_secure_permissions_nextcloud.sh

# Set version for the upgrade scripts to work
echo "1.0" > $SCRIPTS/version

# Run the update script to get the latest updates
# This keeps nextcloud_install_production.sh clean and makes a universal updater
wget $REPO/version_upgrade.sh -P $SCRIPTS
bash $SCRIPTS/version_upgrade.sh

# External USB
BLKID=$(blkid)

whiptail --yesno "Do you want to use an external HD/SSD and run the root partition off of it?" 20 60 1
 if [ $? -eq 0 ]; then # yes
	whiptail --msgbox "Please use an external power supply (USB HUB) to power your HD/SSD. This will increase the RPI's performance at peaks.)" 20 60 1
	whiptail --msgbox "Now please connect the HD/SSD to the RPI and make sure its the only storage device (USB keyboard dongle is fine, just no other USB STORAGE or HD's. Having multiple devices plugged in will mess up the installation and you will have to start over." 20 60 1 
	whiptail --yesno --title Is your device listed here as /dev/sda? "$BLKID" 20 60 1
 if [ $? -eq 1 ]; then
	whiptail --msgbox "Something went wrong, please run Tech and Tool to try it again, when the install is finished: sudo bash /var/scripts/techandtool.sh" 20 60 1
	reboot
fi
	whiptail --msgbox "All of your data will be deleted if you continue please backup/save your files on the HD/SSD that we are going to use first" 20 60 1	
	whiptail --yesno "Has your HD/SSD less capacity then 2TB?" --yes-button "Yes less" --no-button "No more" 20 60 1
 if [ $? -eq 0 ]; then # Yes use msdos

# Disable swap if it is setup before
if 		[ -f /swapfile ];
	then
      		swapoff -a
      		rm /swapfile
      		sed -i 's|/swapfile none swap defaults 0 0|#/swapfile none swap defaults 0 0|g' /etc/fstab
fi

# Step 1
fdisk $DEV << EOF
wipefs
EOF

fdisk $DEV << EOF
o
n
p
1

+4000M
w
EOF

fdisk $DEV << EOF
n
p
2


w
EOF
sync
partprobe

# Vars  
DEVHDUUID=$(blkid -o value -s UUID $DEVHD)
DEVSPUUID=$(blkid -o value -s UUID $DEVSP)

# Swap
mkswap -L PI_SWAP $DEVSP # format as swap
swapon $DEVSP # announce to system
echo "$DEVSP none swap sw 0 0" >> /etc/fstab
sync
partprobe

# Set cmdline.txt
mount /dev/mmcblk0p1 /mnt
sed -i 's|root=/dev/mmcblk0p2|root=PARTUUID=$DEVHDUUID|g' /mnt/cmdline.txt
umount /mnt

# External HD

    {
    i=1
    while read -r line; do
        i=$(( $i + 1 ))
        echo $i
    done < <(echo -ne '\n' | sudo mke2fs -t ext4 -b 4096 -L 'PI_ROOT' $DEVHD)
    } | whiptail --title "Progress" --gauge "Please wait while creating ext4 filesystem" 6 60 0

	sed -i 's|/dev/mmcblk0p2|#/dev/mmcblk0p2|g' /etc/fstab 

	mount $DEVHD /mnt

    {
    i=1
    while read -r line; do
        i=$(( $i + 1 ))
        echo $i
    done < <(rsync -aAXv --exclude={"/dev/*","/proc/*","/sys/*","/tmp/*","/run/*","/mnt/*","/media/*","/lost+found"} / /mnt)
    } | whiptail --title "Progress" --gauge "Please wait while moving from SD to HD/SSD" 6 60 0

	touch /var/scripts/HD
	umount /mnt

 else ########################################## Use GPT

# Disable swap if it is setup before
if 		[ -f /swapfile ];
	then
      		swapoff -a
      		rm /swapfile
      		sed -i 's|/swapfile none swap defaults 0 0|#/swapfile none swap defaults 0 0|g' /etc/fstab
fi

# Step 1
fdisk $DEV << EOF
wipefs
EOF

fdisk $DEV << EOF
g
n
p
1

+4000M
w
EOF

fdisk $DEV << EOF
n
p
2


w
EOF
sync
partprobe

# Vars  
GDEVHDUUID=$(blkid -o value -s UUID $DEVHD)
GDEVSPUUID=$(blkid -o value -s UUID $DEVSP)

# Swap
mkswap -L PI_SWAP $DEVSP # format as swap
swapon $DEVSP # announce to system
echo "$GDEVSPUUID none swap sw 0 0" >> /etc/fstab
sync
partprobe

# Set cmdline.txt
mount /dev/mmcblk0p1 /mnt
sed -i 's|root=/dev/mmcblk0p2|root=PARTUUID=$GDEVHDUUID|g' /mnt/cmdline.txt
umount /mnt

# External HD

    {
    i=1
    while read -r line; do
        i=$(( $i + 1 ))
        echo $i
    done < <(echo -ne '\n' | sudo mke2fs -t ext4 -b 4096 -L 'PI_ROOT' $DEVHD)
    } | whiptail --title "Progress" --gauge "Please wait while creating ext4 filesystem" 6 60 0

	sed -i 's|/dev/mmcblk0p2|#/dev/mmcblk0p2|g' /etc/fstab 

	mount $DEVHD /mnt

    {
    i=1
    while read -r line; do
        i=$(( $i + 1 ))
        echo $i
    done < <(rsync -aAXv --exclude={"/dev/*","/proc/*","/sys/*","/tmp/*","/run/*","/mnt/*","/media/*","/lost+found"} / /mnt)
    } | whiptail --title "Progress" --gauge "Please wait while moving from SD to HD/SSD" 6 60 0

	touch /var/scripts/HD
	umount /mnt

 fi # End of 2TB or less

else # No in use external HD?

	fdisk $DEVICE << EOF
	d
	2
	w
	EOF
	sync

	fdisk $DEVICE << EOF
	n
	p
	2


	w
	EOF
	sync
	partprobe

	# Let us know we're using the SD as ROOT partition
	toch /var/scripts/SD

 fi

# Reboot
reboot

exit 0
