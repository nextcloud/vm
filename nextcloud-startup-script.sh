#!/bin/bash

. <(curl -sL https://cdn.rawgit.com/morph027/vm/color-vars/lib.sh)

# Tech and Me - ©2017, https://www.techandme.se/

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0

WWW_ROOT=/var/www
NCDATA=/var/ncdata
CLEARBOOT=$(dpkg -l linux-* | awk '/^ii/{ print $2}' | grep -v -e "$(uname -r | cut -f1,2 -d"-")" | grep -e "[0-9]" | xargs sudo apt -y purge)
PHPMYADMIN_CONF="/etc/apache2/conf-available/phpmyadmin.conf"
export PHPMYADMIN_CONF
STATIC="https://raw.githubusercontent.com/nextcloud/vm/master/static"
LETS_ENC="https://raw.githubusercontent.com/nextcloud/vm/master/lets-encrypt"
NCPASS=nextcloud
NCUSER=ncadmin
export NCUSER

# DEBUG mode
if [ $DEBUG -eq 1 ]
then
    set -ex
fi

# Check if root
if [[ $EUID -ne 0 ]]
then
    printf "\n${Red}Sorry, you are not root.\n${Color_Off}You must type: ${Cyan}sudo ${Color_Off}bash $SCRIPTS/nextcloud-startup-script.sh\n"
    exit 1
fi

# Check network
if network_ok
then
    printf "${Green}Online!${Color_Off}\n"
else
    echo "Setting correct interface..."
    # Set correct interface
    {
        sed '/# The primary network interface/q' /etc/network/interfaces
        printf 'auto %s\niface %s inet dhcp\n# This is an autoconfigured IPv6 interface\niface %s inet6 auto\n' "$IFACE" "$IFACE" "$IFACE"
    } > /etc/network/interfaces.new
    mv /etc/network/interfaces.new /etc/network/interfaces
    service networking restart
fi

# Check network
if network_ok
then
    printf "${Green}Online!${Color_Off}\n"
else
    printf "\nNetwork NOT OK. You must have a working Network connection to run this script.\n"
    echo "Please report this issue here: https://github.com/nextcloud/vm/issues/new"
    exit 1
fi

# Check where the best mirrors are and update
printf "\nTo make downloads as fast as possible when updating you should have mirrors that are as close to you as possible.\n"
echo "This VM comes with mirrors based on servers in that where used when the VM was released and packaged."
echo "We recomend you to change the mirrors based on where this is currently installed."
echo "Checking current mirror..."
printf "Your current server repository is:  ${Cyan}$REPO${Color_Off}\n"

if [[ "no" == $(ask_yes_or_no "Do you want to try to find a better mirror?") ]]
then
    echo "Keeping $REPO as mirror..."
    sleep 1
else
    echo "Locating the best mirrors..."
    apt update -q2 & spinner_loading
    apt install python-pip -y
    pip install \
        --upgrade pip \
        apt-select
    apt-select -m up-to-date -t 5 -c
    sudo cp /etc/apt/sources.list /etc/apt/sources.list.backup && \
    if [ -f sources.list ]
    then
        sudo mv sources.list /etc/apt/
    fi
fi


echo
echo "Getting scripts from GitHub to be able to run the first setup..."

# Get passman script
if [ -f $SCRIPTS/passman.sh ]
then
    rm $SCRIPTS/passman.sh
    wget -q $STATIC/passman.sh -P $SCRIPTS
else
    wget -q $STATIC/passman.sh -P $SCRIPTS
fi
if [ ! -f $SCRIPTS/passman.sh ]
then
    echo "passman failed"
    echo "Script failed to download. Please run: 'sudo bash $SCRIPTS/nextcloud-startup-script.sh' again."
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
if [ ! -f $SCRIPTS/nextant.sh ]
then
    echo "nextant failed"
    echo "Script failed to download. Please run: 'sudo bash $SCRIPTS/nextcloud-startup-script.sh' again." 
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
if [ ! -f $SCRIPTS/collabora.sh ]
then
    echo "collabora failed"
    echo "Script failed to download. Please run: 'sudo bash $SCRIPTS/nextcloud-startup-script.sh' again."
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
if [ ! -f $SCRIPTS/spreedme.sh ]
then
    echo "spreedme failed"
    echo "Script failed to download. Please run: 'sudo bash $SCRIPTS/nextcloud-startup-script.sh' again."
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
if [ ! -f $SCRIPTS/temporary-fix.sh ]
then
    echo "temporary-fix failed"
    echo "Script failed to download. Please run: 'sudo bash $SCRIPTS/nextcloud-startup-script.sh' again."
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
if [ ! -f $SCRIPTS/security.sh ]
then
    echo "security failed"
    echo "Script failed to download. Please run: 'sudo bash $SCRIPTS/nextcloud-startup-script.sh' again."
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
if [ ! -f $SCRIPTS/update.sh ]
then
    echo "nextcloud_update failed"
    echo "Script failed to download. Please run: 'sudo bash $SCRIPTS/nextcloud-startup-script.sh' again."
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
if [ ! -f $SCRIPTS/phpmyadmin_install_ubuntu16.sh ]
then
    echo "phpmyadmin_install_ubuntu16 failed"
    echo "Script failed to download. Please run: 'sudo bash $SCRIPTS/nextcloud-startup-script.sh' again."
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
if [ ! -f $SCRIPTS/update-config.php ]
then
    echo "update-config failed"
    echo "Script failed to download. Please run: 'sudo bash $SCRIPTS/nextcloud-startup-script.sh' again."
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
if [ ! -f $SCRIPTS/activate-ssl.sh ]
then
    echo "activate-ssl failed"
    echo "Script failed to download. Please run: 'sudo bash $SCRIPTS/nextcloud-startup-script.sh' again."
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
if [ ! -f $SCRIPTS/trusted.sh ]
then
    echo "trusted failed"
    echo "Script failed to download. Please run: 'sudo bash $SCRIPTS/nextcloud-startup-script.sh' again."
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
if [ ! -f $SCRIPTS/ip.sh ]
then
    echo "ip failed"
    echo "Script failed to download. Please run: 'sudo bash $SCRIPTS/nextcloud-startup-script.sh' again."
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
if [ ! -f $SCRIPTS/test_connection.sh ]
then
    echo "test_connection failed"
    echo "Script failed to download. Please run: 'sudo bash $SCRIPTS/nextcloud-startup-script.sh' again."
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
if [ ! -f $SCRIPTS/setup_secure_permissions_nextcloud.sh ]
then
    echo "setup_secure_permissions_nextcloud failed"
    echo "Script failed to download. Please run: 'sudo bash $SCRIPTS/nextcloud-startup-script.sh' again."
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
if [ ! -f $SCRIPTS/change_mysql_pass.sh ]
then
    echo "change_mysql_pass failed"
    echo "Script failed to download. Please run: 'sudo bash $SCRIPTS/nextcloud-startup-script.sh' again."
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
if [ ! -f $SCRIPTS/nextcloud.sh ]
then
    echo "nextcloud failed"
    echo "Script failed to download. Please run: 'sudo bash $SCRIPTS/nextcloud-startup-script.sh' again."
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
if [ ! -f $SCRIPTS/index.php ]
then
    echo "index.php failed"
    echo "Script failed to download. Please run: 'sudo bash $SCRIPTS/nextcloud-startup-script.sh' again."
    exit 1
fi

mv $SCRIPTS/index.php $WWW_ROOT/index.php && rm -f $WWW_ROOT/html/index.html
chmod 750 $WWW_ROOT/index.php && chown www-data:www-data $WWW_ROOT/index.php

# Change 000-default to $WEB_ROOT
sed -i "s|DocumentRoot /var/www/html|DocumentRoot $WWW_ROOT|g" /etc/apache2/sites-available/000-default.conf

# Make $SCRIPTS excutable
chmod +x -R $SCRIPTS
chown root:root -R $SCRIPTS

# Allow $UNIXUSER to run figlet script
chown "$UNIXUSER":"$UNIXUSER" "$SCRIPTS/nextcloud.sh"

clear
echo "+--------------------------------------------------------------------+"
echo "| This script will configure your Nextcloud and activate SSL.        |"
echo "| It will also do the following:                                     |"
echo "|                                                                    |"
echo "| - Generate new SSH keys for the server                             |"
echo "| - Generate new MySQL password                                      |"
echo "| - Configure UTF8mb4 (4-byte support for MySQL)                     |"
echo "| - Install phpMyadmin and make it secure                            |"
echo "| - Install selected apps and automatically configure them           |"
echo "| - Detect and set hostname                                          |"
echo "| - Upgrade your system and Nextcloud to latest version              |"
echo "| - Set secure permissions to Nextcloud                              |"
echo "| - Set new passwords to Linux and Nextcloud                         |"
echo "| - Set new keyboard layout                                          |"
echo "| - Change timezone                                                  |"
echo "| - Set static IP to the system (you have to set the same IP in      |"
echo "|   your router) https://www.techandme.se/open-port-80-443/          |"
echo "|   We don't set static IP if you run this on a *remote* VPS.        |"
echo "|                                                                    |"
echo "|   The script will take about 10 minutes to finish,                 |"
echo "|   depending on your internet connection.                           |"
echo "|                                                                    |"
echo "| ####################### Tech and Me - 2017 ####################### |"
echo "+--------------------------------------------------------------------+"
any_key "Press any key to start the script..."
clear

# VPS?
if [[ "no" == $(ask_yes_or_no "Do you run this script on a *remote* VPS like DigitalOcean, HostGator or similar?") ]]
then
    # Change IP
    printf "\n${Color_Off}OK, we assume you run this locally and we will now configure your IP to be static.${Color_Off}\n"
    echo "Your internal IP is: $ADDRESS"
    printf "\n${Color_Off}Write this down, you will need it to set static IP\n"
    echo "in your router later. It's included in this guide:"
    echo "https://www.techandme.se/open-port-80-443/ (step 1 - 5)"
    any_key "Press any key to set static IP..."
    ifdown "$IFACE"
    sleep 1
    ifup "$IFACE"
    sleep 1
    bash "$SCRIPTS/ip.sh"
    if [ -z "$IFACE" ]
    then
        echo "IFACE is an emtpy value. Trying to set IFACE with another method..."
        wget -q "$STATIC/ip2.sh" -P "$SCRIPTS"
        bash "$SCRIPTS/ip2.sh"
        rm -f "$SCRIPTS/ip2.sh"
    fi
    ifdown "$IFACE"
    sleep 1
    ifup "$IFACE"
    sleep 1
    echo
    echo "Testing if network is OK..."
    sleep 1
    echo
    CONTEST=$(bash $SCRIPTS/test_connection.sh)
    if [ "$CONTEST" == "Connected!" ]
    then
        # Connected!
        printf "${Green}Connected!${Color_Off}\n"
        printf "We will use the DHCP IP: ${Green}$ADDRESS${Color_Off}. If you want to change it later then just edit the interfaces file:"
        printf "sudo nano /etc/network/interfaces\n"
        echo "If you experience any bugs, please report it here:"
        echo "https://github.com/nextcloud/vm/issues/new"
        any_key "Press any key to continue..."
    else
        # Not connected!
        printf "${Red}Not Connected${Color_Off}\nYou should change your settings manually in the next step.\n"
        any_key "Press any key to open /etc/network/interfaces..."
        nano /etc/network/interfaces
        service networking restart
        clear
        echo "Testing if network is OK..."
        ifdown "$IFACE"
        sleep 1
        ifup "$IFACE"
        sleep 1
        bash "$SCRIPTS/test_connection.sh"
        sleep 1
    fi 
else
    echo "OK, then we will not set a static IP as your VPS provider already have setup the network for you..."
    sleep 5
fi
clear

# Set keyboard layout
echo "Current keyboard layout is $(localectl status | grep "Layout" | awk '{print $3}')"
if [[ "no" == $(ask_yes_or_no "Do you want to change keyboard layout?") ]]
then
    echo "Not changing keyboard layout..."
    sleep 1
    clear
else
    dpkg-reconfigure keyboard-configuration
clear
fi

# Pretty URLs
echo "Setting RewriteBase to \"/\" in config.php..."
chown -R www-data:www-data $NCPATH
sudo -u www-data php $NCPATH/occ config:system:set htaccess.RewriteBase --value="/"
sudo -u www-data php $NCPATH/occ maintenance:update:htaccess
bash $SCRIPTS/setup_secure_permissions_nextcloud.sh

# Generate new SSH Keys
printf "\nGenerating new SSH keys for the server...\n"
sleep 1
rm -v /etc/ssh/ssh_host_*
dpkg-reconfigure openssh-server

# Generate new MySQL password
echo
bash "$SCRIPTS/change_mysql_pass.sh" && wait # is the exit status always 0 on if this is sucessfull?
if [ $? -eq 0 ]; then # skip this?
  rm "$SCRIPTS/change_mysql_pass.sh"
  {
  echo "[mysqld]"
  echo "innodb_large_prefix=on"
  echo "innodb_file_format=barracuda"
  echo "innodb_file_per_table=1"
  } >> /root/.my.cnf
fi

# Enable UTF8mb4 (4-byte support)
NCDB=nextcloud_db
PW_FILE=/var/mysql_password.txt
printf "\nEnabling UTF8mb4 support on $NCDB....\n"
echo "Please be patient, it may take a while."
sudo /etc/init.d/mysql restart & spinner_loading
RESULT="mysqlshow --user=root --password=$(cat $PW_FILE) $NCDB| grep -v Wildcard | grep -o $NCDB"
if [ "$RESULT" == "$NCDB" ]; then
    mysql -u root -e "ALTER DATABASE $NCDB CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;" # want to test if this is succesfull
fi
if [ $? -eq 0 ] # Skip this?
then
    sudo -u www-data $NCPATH/occ config:system:set mysql.utf8mb4 --type boolean --value="true"
    sudo -u www-data $NCPATH/occ maintenance:repair
fi

# Install phpMyadmin
echo
bash $SCRIPTS/phpmyadmin_install_ubuntu16.sh
rm $SCRIPTS/phpmyadmin_install_ubuntu16.sh
clear

cat << LETSENC
+-----------------------------------------------+
|  The following script will install a trusted  |
|  SSL certificate through Let's Encrypt.       |
+-----------------------------------------------+
LETSENC

# Let's Encrypt
if [[ "yes" == $(ask_yes_or_no "Do you want to install SSL?") ]]
then
    bash $SCRIPTS/activate-ssl.sh
else
    echo
    echo "OK, but if you want to run it later, just type: sudo bash $SCRIPTS/activate-ssl.sh"
    any_key "Press any key to continue..."
fi
clear

whiptail --title "Which apps do you want to install?" --checklist --separate-output "Automatically configure and install selected apps\nSelect by pressing the spacebar" "$WT_HEIGHT" "$WT_WIDTH" 4 \
"Collabora" "(Online editing)   " OFF \
"Nextant" "(Full text search)   " OFF \
"Passman" "(Password storage)   " OFF \
"Spreed.ME" "(Video calls)   " OFF 2>results

while read -r -u 9 choice
do
    case $choice in
        Collabora)
            install_app collabora
        ;;

        Nextant)
            install_app nextant
        ;;

        Passman)
            install_app passman
        ;;

        Spreed.ME)
            install_app spreedme
        ;;

        *)
        ;;
    esac
done 9< results
rm -f results
clear

# Add extra security
if [[ "yes" == $(ask_yes_or_no "Do you want to add extra security, based on this: http://goo.gl/gEJHi7 ?") ]]
then
    bash $SCRIPTS/security.sh
    rm $SCRIPTS/security.sh
else
    echo
    echo "OK, but if you want to run it later, just type: sudo bash $SCRIPTS/security.sh"
    any_key "Press any key to continue..."
fi
clear

# Change Timezone
echo "Current timezone is $(cat /etc/timezone)"
echo "You must change it to your timezone"
any_key "Press any key to change timezone..."
dpkg-reconfigure tzdata
echo
sleep 3
clear

# Change password
printf "${Color_Off}\n"
echo "For better security, change the system user password for [$UNIXUSER]"
any_key "Press any key to change password for system user..."
while true
do
    sudo passwd "$UNIXUSER" && break
done
echo
clear
NCADMIN=$(sudo -u www-data php $NCPATH/occ user:list | awk '{print $3}')
printf "${Color_Off}\n"
echo "For better security, change the Nextcloud password for [$NCADMIN]"
echo "The current password for $NCADMIN is [$NCPASS]"
any_key "Press any key to change password for Nextcloud..."
while true
do
    sudo -u www-data php "$NCPATH/occ" user:resetpassword "$NCADMIN" && break
done
clear

# Fixes https://github.com/nextcloud/vm/issues/58
a2dismod status
service apache reload

# Increase max filesize (expects that changes are made in /etc/php/7.0/apache2/php.ini)
# Here is a guide: https://www.techandme.se/increase-max-file-size/
VALUE="# php_value upload_max_filesize 513M"
if ! grep -Fxq "$VALUE" $NCPATH/.htaccess
then
        sed -i 's/  php_value upload_max_filesize 513M/# php_value upload_max_filesize 513M/g' $NCPATH/.htaccess
        sed -i 's/  php_value post_max_size 513M/# php_value post_max_size 513M/g' $NCPATH/.htaccess
        sed -i 's/  php_value memory_limit 512M/# php_value memory_limit 512M/g' $NCPATH/.htaccess
fi

# Add temporary fix if needed
bash $SCRIPTS/temporary-fix.sh
rm $SCRIPTS/temporary-fix.sh

# Cleanup 1
sudo -u www-data php "$NCPATH/occ" maintenance:repair
rm -f "$SCRIPTS/ip.sh"
rm -f "$SCRIPTS/test_connection.sh"
rm -f "$SCRIPTS/instruction.sh"
rm -f "$NCDATA/nextcloud.log"

rm -f "$SCRIPTS/nextcloud-startup-script.sh"
find /root "/home/$UNIXUSER" -type f \( -name '*.sh*' -o -name '*.html*' -o -name '*.tar*' -o -name '*.zip*' \) -delete


sed -i "s|instruction.sh|nextcloud.sh|g" "/home/$UNIXUSER/.bash_profile"

truncate -s 0 \
    /root/.bash_history \
    "/home/$UNIXUSER/.bash_history" \
    /var/spool/mail/root \
    "/var/spool/mail/$UNIXUSER" \
    /var/log/apache2/access.log \
    /var/log/apache2/error.log \
    /var/log/cronjobs_success.log

sed -i "s|sudo -i||g" "/home/$UNIXUSER/.bash_profile"
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

# Upgrade system
echo "System will now upgrade..."
sleep 2
echo
bash $SCRIPTS/update.sh

# Cleanup 2
apt autoremove -y
apt autoclean
echo "$CLEARBOOT"
find /root "/home/$UNIXUSER" -type f \( -name '*.sh*' -o -name '*.html*' -o name '*.tar*' -o name '*.zip*' \) -delete
clear

ADDRESS2=$(grep "address" /etc/network/interfaces | awk '$1 == "address" { print $2 }')

# Success!
clear
printf "%s\n" "${Green}"
echo    "+--------------------------------------------------------------------+"
echo    "|      Congratulations! You have successfully installed Nextcloud!   |"
echo    "|                                                                    |"
printf "|         ${Color_Off}Login to Nextcloud in your browser:${Cyan}\" $ADDRESS2\"${Green}         |\n"
echo    "|                                                                    |"
printf "|         ${Color_Off}Publish your server online! ${Cyan}https://goo.gl/iUGE2U${Green}          |\n"
echo    "|                                                                    |"
printf "|         ${Color_Off}To login to MySQL just type: ${Cyan}'mysql -u root'${Green}               |\n"
echo    "|                                                                    |"
printf "|   ${Color_Off}To update this VM just type: ${Cyan}'sudo bash /var/scripts/update.sh'${Green}  |\n"
echo    "|                                                                    |"
printf "|    ${IRed}#################### Tech and Me - 2017 ####################${Green}    |\n"
echo    "+--------------------------------------------------------------------+"
printf "${Color_Off}\n"

# Update Config
if [ -f $SCRIPTS/update-config.php ]
then
    rm $SCRIPTS/update-config.php
    wget -q $STATIC/update-config.php -P $SCRIPTS
else
    wget -q $STATIC/update-config.php -P $SCRIPTS
fi

# Sets trusted domain in config.php
if [ -f $SCRIPTS/trusted.sh ]
then
    rm $SCRIPTS/trusted.sh
    wget -q $STATIC/trusted.sh -P $SCRIPTS
    bash $SCRIPTS/trusted.sh
    rm $SCRIPTS/update-config.php
    rm $SCRIPTS/trusted.sh
else
    wget -q $STATIC/trusted.sh -P $SCRIPTS
    bash $SCRIPTS/trusted.sh
    rm $SCRIPTS/trusted.sh
    rm $SCRIPTS/update-config.php
fi

# Prefer IPv6
sed -i "s|precedence ::ffff:0:0/96  100|#precedence ::ffff:0:0/96  100|g" /etc/gai.conf

# Reboot
rm -f "$SCRIPTS/nextcloud-startup-script.sh"
any_key "Installation finished, press any key to reboot system..."
reboot
