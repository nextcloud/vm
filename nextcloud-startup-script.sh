#!/bin/bash

# Tech and Me - ©2017, https://www.techandme.se/

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0

WWW_ROOT=/var/www
NCPATH=$WWW_ROOT/nextcloud
NCDATA=/var/ncdata
SCRIPTS=/var/scripts
IFACE=$(lshw -c network | grep "logical name" | awk '{print $3; exit}')
CLEARBOOT=$(dpkg -l linux-* | awk '/^ii/{ print $2}' | grep -v -e `uname -r | cut -f1,2 -d"-"` | grep -e [0-9] | xargs sudo apt -y purge)
PHPMYADMIN_CONF="/etc/apache2/conf-available/phpmyadmin.conf"
GITHUB_REPO="https://raw.githubusercontent.com/nextcloud/vm/master"
STATIC="https://raw.githubusercontent.com/nextcloud/vm/master/static"
LETS_ENC="https://raw.githubusercontent.com/nextcloud/vm/master/lets-encrypt"
UNIXUSER=$LOGNAME
NCPASS=nextcloud
NCUSER=ncadmin

# DEBUG mode
if [ $DEBUG -eq 1 ]
then
    set -e
    set -x
else
    sleep 1
fi

# Check if root
if [ "$(whoami)" != "root" ]
then
    echo
    echo -e "\e[31mSorry, you are not root.\n\e[0mYou must type: \e[36msudo \e[0mbash $SCRIPTS/nextcloud-startup-script.sh"
    echo
    exit 1
fi

# Check network
echo "Testing if network is OK..."
service networking restart
    curl -s http://github.com > /dev/null
if [ $? -eq 0 ]
then
    echo -e "\e[32mOnline!\e[0m"
else
echo "Setting correct interface..."
# Set correct interface
{ sed '/# The primary network interface/q' /etc/network/interfaces; printf 'auto %s\niface %s inet dhcp\n# This is an autoconfigured IPv6 interface\niface %s inet6 auto\n' "$IFACE" "$IFACE" "$IFACE"; } > /etc/network/interfaces.new
mv /etc/network/interfaces.new /etc/network/interfaces
service networking restart
fi

# Check network
echo "Testing if network is OK..."
service networking restart
    curl -s http://github.com > /dev/null
if [ $? -eq 0 ]
then
    echo -e "\e[32mOnline!\e[0m"
else
    echo
    echo "Network NOT OK. You must have a working Network connection to run this script."
    echo "Please report this issue here: https://github.com/nextcloud/vm/issues/new"
    exit 1
fi

# Get the best mirrors for Ubuntu based on location
echo "Locating the best mirrors..."
apt-select
sudo cp /etc/apt/sources.list /etc/apt/sources.list.backup && \
if [ -f sources.list ]
then
sudo mv sources.list /etc/apt/
fi

ADDRESS=$(hostname -I | cut -d ' ' -f 1)

echo "Getting scripts from GitHub to be able to run the first setup..."

# Get passman script
if [ -f $SCRIPTS/passman.sh ]
then
    rm $SCRIPTS/passman.sh
    wget -q $STATIC/passman.sh -P $SCRIPTS
else
    wget -q $STATIC/passman.sh -P $SCRIPTS
fi
if [ -f $SCRIPTS/passman.sh ]
then
    sleep 0.1
else
    echo "passman failed"
    echo "Script failed to download. Please run: 'sudo bash /var/scripts/nextcloud-startup-script.sh' again."
    exit 1
fi

# Get nextant script
if [ -f $SCRIPTS/nextant.sh ]
then
    rm $SCRIPTS/nextant.sh
    wget -q $STATIC/nextant.sh -P $SCRIPTS
else
    wget -q $STATIC/nextant.sh -P $SCRIPTS
fi
if [ -f $SCRIPTS/nextant.sh ]
then
    sleep 0.1
else
    echo "nextant failed"
    echo "Script failed to download. Please run: 'sudo bash /var/scripts/nextcloud-startup-script.sh' again." 
    exit 1
fi

# Get collabora script
if [ -f $SCRIPTS/collabora.sh ]
then
    rm $SCRIPTS/collabora.sh
    wget -q $STATIC/collabora.sh -P $SCRIPTS
else
    wget -q $STATIC/collabora.sh -P $SCRIPTS
fi
if [ -f $SCRIPTS/collabora.sh ]
then
    sleep 0.1
else
    echo "collabora failed"
    echo "Script failed to download. Please run: 'sudo bash /var/scripts/nextcloud-startup-script.sh' again."
    exit 1
fi

# Get spreedme script
if [ -f $SCRIPTS/spreedme.sh ]
then
    rm $SCRIPTS/spreedme.sh
    wget -q $STATIC/spreedme.sh -P $SCRIPTS
else
    wget -q $STATIC/spreedme.sh -P $SCRIPTS
fi
if [ -f $SCRIPTS/spreedme.sh ]
then
    sleep 0.1
else
    echo "spreedme failed"
    echo "Script failed to download. Please run: 'sudo bash /var/scripts/nextcloud-startup-script.sh' again."
    exit 1
fi

# Get script for temporary fixes
if [ -f $SCRIPTS/temporary.sh ]
then
    rm $SCRIPTS/temporary-fix.sh
    wget -q $STATIC/temporary-fix.sh -P $SCRIPTS
else
    wget -q $STATIC/temporary-fix.sh -P $SCRIPTS
fi
if [ -f $SCRIPTS/temporary-fix.sh ]
then
    sleep 0.1
else
    echo "temporary-fix failed"
    echo "Script failed to download. Please run: 'sudo bash /var/scripts/nextcloud-startup-script.sh' again."
    exit 1
fi

# Get security script
if [ -f $SCRIPTS/security.sh ]
then
    rm $SCRIPTS/security.sh
    wget -q $STATIC/security.sh -P $SCRIPTS
else
    wget -q $STATIC/security.sh -P $SCRIPTS
fi
if [ -f $SCRIPTS/security.sh ]
then
    sleep 0.1
else
    echo "security failed"
    echo "Script failed to download. Please run: 'sudo bash /var/scripts/nextcloud-startup-script.sh' again."
    exit 1
fi

# Get the latest nextcloud_update.sh
if [ -f $SCRIPTS/update.sh ]
then
    rm $SCRIPTS/update.sh
    wget -q $STATIC/update.sh -P $SCRIPTS
else
    wget -q $STATIC/update.sh -P $SCRIPTS
fi
if [ -f $SCRIPTS/update.sh ]
then
    sleep 0.1
else
    echo "nextcloud_update failed"
    echo "Script failed to download. Please run: 'sudo bash /var/scripts/nextcloud-startup-script.sh' again."
    exit 1
fi

# phpMyadmin
if [ -f $SCRIPTS/phpmyadmin_install_ubuntu16.sh ]
then
    rm $SCRIPTS/phpmyadmin_install_ubuntu16.sh
    wget -q $STATIC/phpmyadmin_install_ubuntu16.sh -P $SCRIPTS
else
    wget -q $STATIC/phpmyadmin_install_ubuntu16.sh -P $SCRIPTS
fi
if [ -f $SCRIPTS/phpmyadmin_install_ubuntu16.sh ]
then
    sleep 0.1
else
    echo "phpmyadmin_install_ubuntu16 failed"
    echo "Script failed to download. Please run: 'sudo bash /var/scripts/nextcloud-startup-script.sh' again."
    exit 1
fi

# Update Config
if [ -f $SCRIPTS/update-config.php ]
then
    rm $SCRIPTS/update-config.php
    wget -q $STATIC/update-config.php -P $SCRIPTS
else
    wget -q $STATIC/update-config.php -P $SCRIPTS
fi
if [ -f $SCRIPTS/update-config.php ]
then
    sleep 0.1
else
    echo "update-config failed"
    echo "Script failed to download. Please run: 'sudo bash /var/scripts/nextcloud-startup-script.sh' again."
    exit 1
fi

# Activate SSL
if [ -f $SCRIPTS/activate-ssl.sh ]
then
    rm $SCRIPTS/activate-ssl.sh
    wget -q $LETS_ENC/activate-ssl.sh -P $SCRIPTS
else
    wget -q $LETS_ENC/activate-ssl.sh -P $SCRIPTS
fi
if [ -f $SCRIPTS/activate-ssl.sh ]
then
    sleep 0.1
else
    echo "activate-ssl failed"
    echo "Script failed to download. Please run: 'sudo bash /var/scripts/nextcloud-startup-script.sh' again."
    exit 1
fi

# Sets trusted domain in when nextcloud-startup-script.sh is finished
if [ -f $SCRIPTS/trusted.sh ]
then
    rm $SCRIPTS/trusted.sh
    wget -q $STATIC/trusted.sh -P $SCRIPTS
else
    wget -q $STATIC/trusted.sh -P $SCRIPTS
fi
if [ -f $SCRIPTS/trusted.sh ]
then
    sleep 0.1
else
    echo "trusted failed"
    echo "Script failed to download. Please run: 'sudo bash /var/scripts/nextcloud-startup-script.sh' again."
    exit 1
fi

# Sets static IP to UNIX
if [ -f $SCRIPTS/ip.sh ]
then
    rm $SCRIPTS/ip.sh
    wget -q $STATIC/ip.sh -P $SCRIPTS
else
    wget -q $STATIC/ip.sh -P $SCRIPTS
fi
if [ -f $SCRIPTS/ip.sh ]
then
    sleep 0.1
else
    echo "ip failed"
    echo "Script failed to download. Please run: 'sudo bash /var/scripts/nextcloud-startup-script.sh' again."
    exit 1
fi

# Tests connection after static IP is set
if [ -f $SCRIPTS/test_connection.sh ]
then
    rm $SCRIPTS/test_connection.sh
    wget -q $STATIC/test_connection.sh -P $SCRIPTS
else
    wget -q $STATIC/test_connection.sh -P $SCRIPTS
fi
if [ -f $SCRIPTS/test_connection.sh ]
then
    sleep 0.1
else
    echo "test_connection failed"
    echo "Script failed to download. Please run: 'sudo bash /var/scripts/nextcloud-startup-script.sh' again."
    exit 1
fi

# Sets secure permissions after upgrade
if [ -f $SCRIPTS/setup_secure_permissions_nextcloud.sh ]
then
    rm $SCRIPTS/setup_secure_permissions_nextcloud.sh
    wget -q $STATIC/setup_secure_permissions_nextcloud.sh -P $SCRIPTS
else
    wget -q $STATIC/setup_secure_permissions_nextcloud.sh -P $SCRIPTS
fi
if [ -f $SCRIPTS/setup_secure_permissions_nextcloud.sh ]
then
    sleep 0.1
else
    echo "setup_secure_permissions_nextcloud failed"
    echo "Script failed to download. Please run: 'sudo bash /var/scripts/nextcloud-startup-script.sh' again."
    exit 1
fi

# Change MySQL password
if [ -f $SCRIPTS/change_mysql_pass.sh ]
then
    rm $SCRIPTS/change_mysql_pass.sh
    wget -q $STATIC/change_mysql_pass.sh
else
    wget -q $STATIC/change_mysql_pass.sh -P $SCRIPTS
fi
if [ -f $SCRIPTS/change_mysql_pass.sh ]
then
    sleep 0.1
else
    echo "change_mysql_pass failed"
    echo "Script failed to download. Please run: 'sudo bash /var/scripts/nextcloud-startup-script.sh' again."
    exit 1
fi

# Get figlet Tech and Me
if [ -f $SCRIPTS/nextcloud.sh ]
then
    rm $SCRIPTS/nextcloud.sh
    wget -q $STATIC/nextcloud.sh -P $SCRIPTS
else
    wget -q $STATIC/nextcloud.sh -P $SCRIPTS
fi
if [ -f $SCRIPTS/nextcloud.sh ]
then
    sleep 0.1
else
    echo "nextcloud failed"
    echo "Script failed to download. Please run: 'sudo bash /var/scripts/nextcloud-startup-script.sh' again."
    exit 1
fi
# Get the Welcome Screen when http://$address
if [ -f $SCRIPTS/index.php ]
then
    rm $SCRIPTS/index.php
    wget -q $GITHUB_REPO/index.php -P $SCRIPTS
else
    wget -q $GITHUB_REPO/index.php -P $SCRIPTS
fi

mv $SCRIPTS/index.php $WWW_ROOT/index.php && rm -f $WWW_ROOT/html/index.html
chmod 750 $WWW_ROOT/index.php && chown www-data:www-data $WWW_ROOT/index.php

# Change 000-default to $WEB_ROOT
sed -i "s|DocumentRoot /var/www/html|DocumentRoot $WWW_ROOT|g" /etc/apache2/sites-available/000-default.conf

# Make $SCRIPTS excutable
chmod +x -R $SCRIPTS
chown root:root -R $SCRIPTS

# Allow $UNIXUSER to run figlet script
chown $UNIXUSER:$UNIXUSER $SCRIPTS/nextcloud.sh

clear
echo "+--------------------------------------------------------------------+"
echo "| This script will configure your Nextcloud and activate SSL.        |"
echo "| It will also do the following:                                     |"
echo "|                                                                    |"
echo "| - Generate new SSH keys for the server                             |"
echo "| - Generate new MySQL password                                      |"
echo "| - Install phpMyadmin and make it secure                            |"
echo "| - Install selected apps and automatically configure them           |"
echo "| - Upgrade your system and Nextcloud to latest version              |"
echo "| - Set secure permissions to Nextcloud                              |"
echo "| - Set new passwords to Ubuntu Server and Nextcloud                 |"
echo "| - Set new keyboard layout                                          |"
echo "| - Change timezone                                                  |"
echo "| - Set static IP to the system (you have to set the same IP in      |"
echo "|   your router) https://www.techandme.se/open-port-80-443/          |"
echo "|                                                                    |"
echo "|   The script will take about 10 minutes to finish,                 |"
echo "|   depending on your internet connection.                           |"
echo "|                                                                    |"
echo "| ####################### Tech and Me - 2017 ####################### |"
echo "+--------------------------------------------------------------------+"
echo -e "\e[32m"
read -p "Press any key to start the script..." -n1 -s
clear
echo -e "\e[0m"

# Set keyboard layout
echo "Current keyboard layout is Swedish"
echo "You must change keyboard layout to your language"
echo -e "\e[32m"
read -p "Press any key to change keyboard layout... " -n1 -s
echo -e "\e[0m"
dpkg-reconfigure keyboard-configuration
echo
clear

# Set hostname and ServerName
echo "Setting hostname..."
FQN=$(host -TtA $(hostname -s)|grep "has address"|awk '{print $1}') ; \
if [[ "$FQN" == "" ]]
then
    FQN=$(hostname -s)
fi
sudo sh -c "echo 'ServerName $FQN' >> /etc/apache2/apache2.conf"
sudo hostnamectl set-hostname $FQN
service apache2 restart
cat << ETCHOSTS > "/etc/hosts"
127.0.1.1 $FQN.localdomain $FQN
127.0.0.1 localhost

# The following lines are desirable for IPv6 capable hosts
::1     localhost ip6-localhost ip6-loopback
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
ETCHOSTS
clear

if [[ "no" == $(ask_yes_or_no "Do you run this script on a *remote* VPS like DigitalOcean, HostGator or similar?") ]]
then
    echo
    echo "OK, then we will not set a static IP as your VPS provider already have setup the network for you..."
    echo
    sleep 5
    # Change IP
    echo -e "\e[0m"
    echo "The script will now configure your IP to be static."
    echo -e "\e[36m"
    echo -e "\e[1m"
    echo "Your internal IP is: $ADDRESS"
    echo -e "\e[0m"
    echo -e "Write this down, you will need it to set static IP"
    echo -e "in your router later. It's included in this guide:"
    echo -e "https://www.techandme.se/open-port-80-443/ (step 1 - 5)"
    echo -e "\e[32m"
    read -p "Press any key to set static IP..." -n1 -s
    clear
    echo -e "\e[0m"
    ifdown $IFACE
    sleep 1
    ifup $IFACE
    sleep 1
    bash $SCRIPTS/ip.sh
    ifdown $IFACE
    sleep 1
    ifup $IFACE
    sleep 1
    echo
    echo "Testing if network is OK..."
    sleep 1
    echo
    bash $SCRIPTS/test_connection.sh
    sleep 1
    echo
    echo -e "\e[0mIf the output is \e[32mConnected! \o/\e[0m everything is working."
    echo -e "\e[0mIf the output is \e[31mNot Connected!\e[0m you should change\nyour settings manually in the next step."
    echo -e "\e[32m"
    read -p "Press any key to open /etc/network/interfaces..." -n1 -s
    echo -e "\e[0m"
    nano /etc/network/interfaces
    service networking restart
    clear
    echo "Testing if network is OK..."
    ifdown $IFACE
    sleep 1
    ifup $IFACE
    sleep 1
    echo
    bash $SCRIPTS/test_connection.sh
    sleep 1
else
    sleep 1
fi
clear

# Pretty URLs
echo "Setting RewriteBase to "/" in config.php..."
chown -R www-data:www-data $NCPATH
sudo -u www-data php $NCPATH/occ config:system:set htaccess.RewriteBase --value="/"
sudo -u www-data php $NCPATH/occ maintenance:update:htaccess
bash $SCRIPTS/setup_secure_permissions_nextcloud.sh

# Generate new SSH Keys
echo
echo "Generating new SSH keys for the server..."
sleep 1
rm -v /etc/ssh/ssh_host_*
dpkg-reconfigure openssh-server

# Generate new MySQL password
echo
bash $SCRIPTS/change_mysql_pass.sh && wait
if [ $? -eq 0 ]
then
rm $SCRIPTS/change_mysql_pass.sh
echo "[mysqld]" >> /root/.my.cnf
echo "innodb_large_prefix=on" >> /root/.my.cnf
echo "innodb_file_format=barracuda" >> /root/.my.cnf
echo "innodb_file_per_table=1" >> /root/.my.cnf
fi

# Enable UTF8mb4 (4-byte support)
NCDB=nextcloud_db
PW_FILE=/var/mysql_password.txt
echo
echo "Enabling UTF8mb4 support on $NCDB...."
sudo /etc/init.d/mysql restart
RESULT="mysqlshow --user=root --password=$(cat $PW_FILE) $NCDB| grep -v Wildcard | grep -o $NCDB"
if [ "$RESULT" == "$NCDB" ]; then
    mysql -u root -e "ALTER DATABASE $NCDB CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;"
fi
if [ $? -eq 0 ]
then
sudo -u www-data $NCPATH/occ config:system:set mysql.utf8mb4 --type boolean --value="true"
sudo -u www-data $NCPATH/occ maintenance:repair
fi

# Install phpMyadmin
echo
bash $SCRIPTS/phpmyadmin_install_ubuntu16.sh
rm $SCRIPTS/phpmyadmin_install_ubuntu16.sh
clear

# Whiptail auto-size
calc_wt_size() {
  WT_HEIGHT=17
  WT_WIDTH=$(tput cols)

  if [ -z "$WT_WIDTH" ] || [ "$WT_WIDTH" -lt 60 ]; then
    WT_WIDTH=80
  fi
  if [ "$WT_WIDTH" -gt 178 ]; then
    WT_WIDTH=120
  fi
  WT_MENU_HEIGHT=$((WT_HEIGHT-7))
}

# Install Apps
function collabora {
    bash $SCRIPTS/collabora.sh
    rm $SCRIPTS/collabora.sh
}

function nextant {
    bash $SCRIPTS/nextant.sh
    rm $SCRIPTS/nextant.sh
}

function passman {
    bash $SCRIPTS/passman.sh
    rm $SCRIPTS/passman.sh
}


function spreedme {
    bash $SCRIPTS/spreedme.sh
    rm $SCRIPTS/spreedme.sh

}

whiptail --title "Which apps do you want to install?" --checklist --separate-output "Automatically configure and install selected apps" "$WT_HEIGHT" "$WT_WIDTH" 4 \
"Collabora" "(Online editing) [BETA]   " OFF \
"Nextant" "(Full text search)   " OFF \
"Passman" "(Password storage)   " OFF \
"Spreed.ME" "(Video calls)   " OFF 2>results

while read choice
do
        case $choice in
                Collabora) collabora
                ;;
                Nextant) nextant
                ;;
                Passman) passman
                ;;
                Spreed.ME) spreedme
                ;;
                *)
                ;;
        esac
done < results
clear

# Add extra security
function ask_yes_or_no() {
    read -p "$1 ([y]es or [N]o): "
    case $(echo $REPLY | tr '[A-Z]' '[a-z]') in
        y|yes) echo "yes" ;;
        *)     echo "no" ;;
    esac
}
if [[ "yes" == $(ask_yes_or_no "Do you want to add extra security, based on this: http://goo.gl/gEJHi7 ?") ]]
then
    bash $SCRIPTS/security.sh
    rm $SCRIPTS/security.sh
else
    echo
    echo "OK, but if you want to run it later, just type: sudo bash $SCRIPTS/security.sh"
    echo -e "\e[32m"
    read -p "Press any key to continue... " -n1 -s
    echo -e "\e[0m"
fi
clear

# Change Timezone
echo "Current timezone is $(cat /etc/timezone)"
echo "You must change timezone to your timezone"
echo -e "\e[32m"
read -p "Press any key to change timezone... " -n1 -s
echo -e "\e[0m"
dpkg-reconfigure tzdata
echo
sleep 3
clear

    # Change password
    echo -e "\e[0m"
    echo "For better security, change the Linux password for [$UNIXUSER]"
    echo -e "\e[32m"
    read -p "Press any key to change password for Linux... " -n1 -s
    echo -e "\e[0m"
    sudo passwd $UNIXUSER
    if [[ $? > 0 ]]
    then
        sudo passwd $UNIXUSER
    else
        sleep 2
    fi
    echo
    clear

    echo -e "\e[0m"
    echo "For better security, change the Nextcloud password for [$NCUSER]"
    echo "The current password for $NCUSER is [$NCPASS]"
    echo -e "\e[32m"
    read -p "Press any key to change password for Nextcloud... " -n1 -s
    echo -e "\e[0m"
    sudo -u www-data php $NCPATH/occ user:resetpassword $NCUSER
    if [[ $? > 0 ]]
    then
        sudo -u www-data php $NCPATH/occ user:resetpassword $NCUSER
    else
        sleep 2
    fi
clear

# Upgrade system
echo "System will now upgrade..."
sleep 2
echo
bash $SCRIPTS/update.sh

# Fixes https://github.com/nextcloud/vm/issues/58
a2dismod status
service apache restart

# Increase max filesize (expects that changes are made in /etc/php/7.0/apache2/php.ini)
# Here is a guide: https://www.techandme.se/increase-max-file-size/
VALUE="# php_value upload_max_filesize 513M"
if grep -Fxq "$VALUE" $NCPATH/.htaccess
then
        echo "Value correct"
else
        sed -i 's/  php_value upload_max_filesize 513M/# php_value upload_max_filesize 513M/g' $NCPATH/.htaccess
        sed -i 's/  php_value post_max_size 513M/# php_value post_max_size 513M/g' $NCPATH/.htaccess
        sed -i 's/  php_value memory_limit 512M/# php_value memory_limit 512M/g' $NCPATH/.htaccess
fi


# Add temporary fix if needed
bash $SCRIPTS/temporary-fix.sh
rm $SCRIPTS/temporary-fix.sh

# Cleanup 1
apt autoremove -y
apt autoclean
echo "$CLEARBOOT"
clear

# Cleanup 2
sudo -u www-data php $NCPATH/occ maintenance:repair
rm $SCRIPTS/ip.sh
rm $SCRIPTS/test_connection.sh
rm $SCRIPTS/instruction.sh
rm $NCDATA/nextcloud.log
rm $SCRIPTS/nextcloud-startup-script.sh
sed -i "s|instruction.sh|nextcloud.sh|g" /home/$UNIXUSER/.bash_profile
cat /dev/null > ~/.bash_history
cat /dev/null > /var/spool/mail/root
cat /dev/null > /var/spool/mail/$UNIXUSER
cat /dev/null > /var/log/apache2/access.log
cat /dev/null > /var/log/apache2/error.log
cat /dev/null > /var/log/cronjobs_success.log
sed -i "s|sudo -i||g" /home/$UNIXUSER/.bash_profile
cat /dev/null > /etc/rc.local
cat << RCLOCAL > "/etc/rc.local"
#!/bin/sh -e
#
# rc.local
#
# This script is executed at the end of each multiuser runlevel.
# Make sure that the script will "exit 0" on success or any other
# value on error.
#
# In order to enable or disable this script just change the execution
# bits.
#
# By default this script does nothing.

exit 0

RCLOCAL

ADDRESS2=$(grep "address" /etc/network/interfaces | awk '$1 == "address" { print $2 }')

# Success!
clear
echo -e "\e[32m"
echo    "+--------------------------------------------------------------------+"
echo    "|      Congratulations! You have successfully installed Nextcloud!   |"
echo    "|                                                                    |"
echo -e "|         \e[0mLogin to Nextcloud in your browser:\e[36m" $ADDRESS2"\e[32m           |"
echo    "|                                                                    |"
echo -e "|         \e[0mPublish your server online! \e[36mhttps://goo.gl/iUGE2U\e[32m          |"
echo    "|                                                                    |"
echo -e "|         \e[0mTo login to MySQL just type: \e[36m'mysql -u root'\e[32m               |"
echo    "|                                                                    |"
echo -e "|   \e[0mTo update this VM just type: \e[36m'sudo bash /var/scripts/update.sh'\e[32m  |"
echo    "|                                                                    |"
echo -e "|    \e[91m#################### Tech and Me - 2017 ####################\e[32m    |"
echo    "+--------------------------------------------------------------------+"
echo
echo -e "\e[0m"

# VPS?
function ask_yes_or_no() {
    read -p "$1 ([y]es or [N]o): "
    case $(echo $REPLY | tr '[A-Z]' '[a-z]') in
        y|yes) echo "yes" ;;
        *)     echo "no" ;;
    esac
}

cat << LETSENC
+-----------------------------------------------+
|  Ok, now the last part - a proper SSL cert.   |
|                                               |
|  The following script will install a trusted  |
|  SSL certificate through Let's Encrypt.       |
+-----------------------------------------------+
LETSENC

# Let's Encrypt
function ask_yes_or_no() {
    read -p "$1 ([y]es or [N]o): "
    case $(echo $REPLY | tr '[A-Z]' '[a-z]') in
        y|yes) echo "yes" ;;
        *)     echo "no" ;;
    esac
}
if [[ "yes" == $(ask_yes_or_no "Do you want to install SSL?") ]]
then
    bash $SCRIPTS/activate-ssl.sh
else
    echo
    echo "OK, but if you want to run it later, just type: sudo bash $SCRIPTS/activate-ssl.sh"
    echo -e "\e[32m"
    read -p "Press any key to continue... " -n1 -s
    echo -e "\e[0m"
fi

# Change Trusted Domain and CLI
bash $SCRIPTS/trusted.sh
rm $SCRIPTS/trusted.sh
rm $SCRIPTS/update-config.php

# Prefer IPv6
sed -i "s|precedence ::ffff:0:0/96  100|#precedence ::ffff:0:0/96  100|g" /etc/gai.conf

# Reboot
echo "System will now reboot..."
reboot

exit 0
