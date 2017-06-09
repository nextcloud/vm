#!/bin/bash
# shellcheck disable=2034,2059
true
# shellcheck source=lib.sh
NCDB=1 && MYCNFPW=1 && FIRST_IFACE=1 && CHECK_CURRENT_REPO=1 . <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)
unset FIRST_IFACE
unset CHECK_CURRENT_REPO
unset MYCNFPW
unset NCDB

# Tech and Me © - 2017, https://www.techandme.se/

## If you want debug mode, please activate it further down in the code at line ~60

is_root() {
    if [[ "$EUID" -ne 0 ]]
    then
        return 1
    else
        return 0
    fi
}

network_ok() {
    echo "Testing if network is OK..."
    service networking restart
    if wget -q -T 20 -t 2 http://github.com -O /dev/null
    then
        return 0
    else
        return 1
    fi
}

# Check if root
if ! is_root
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
    [ -z "$IFACE" ] && IFACE=$(lshw -c network | grep "logical name" | awk '{print $3; exit}')
    # Set correct interface
    {
        sed '/# The primary network interface/q' /etc/network/interfaces
        printf 'auto %s\niface %s inet dhcp\n# This is an autoconfigured IPv6 interface\niface %s inet6 auto\n' "$IFACE" "$IFACE" "$IFACE"
    } > /etc/network/interfaces.new
    mv /etc/network/interfaces.new /etc/network/interfaces
    service networking restart
    # shellcheck source=lib.sh
    CHECK_CURRENT_REPO=1 . <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)
    unset CHECK_CURRENT_REPO
fi

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Check network
if network_ok
then
    printf "${Green}Online!${Color_Off}\n"
else
    printf "\nNetwork NOT OK. You must have a working Network connection to run this script.\n"
    echo "Please report this issue here: $ISSUES"
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
    apt update -q4 & spinner_loading
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
# All the shell scripts in static (.sh)
download_static_script temporary-fix
download_static_script security
download_static_script update
download_static_script trusted
download_static_script ip
download_static_script test_connection
download_static_script setup_secure_permissions_nextcloud
download_static_script change_mysql_pass
download_static_script nextcloud
download_static_script update-config
download_static_script index
download_le_script activate-ssl

mv $SCRIPTS/index.php $HTML/index.php && rm -f $HTML/html/index.html
chmod 750 $HTML/index.php && chown www-data:www-data $HTML/index.php

# Change 000-default to $WEB_ROOT
sed -i "s|DocumentRoot /var/www/html|DocumentRoot $HTML|g" /etc/apache2/sites-available/000-default.conf

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
    wait
    ifup "$IFACE"
    wait
    bash "$SCRIPTS/ip.sh"
    if [ -z "$IFACE" ]
    then
        echo "IFACE is an emtpy value. Trying to set IFACE with another method..."
        download_static_script ip2
        bash "$SCRIPTS/ip2.sh"
        rm -f "$SCRIPTS/ip2.sh"
    fi
    ifdown "$IFACE"
    wait
    ifup "$IFACE"
    wait
    echo
    echo "Testing if network is OK..."
    echo
    CONTEST=$(bash $SCRIPTS/test_connection.sh)
    if [ "$CONTEST" == "Connected!" ]
    then
        # Connected!
        printf "${Green}Connected!${Color_Off}\n"
        printf "We will use the DHCP IP: ${Green}$ADDRESS${Color_Off}. If you want to change it later then just edit the interfaces file:\n"
        printf "sudo nano /etc/network/interfaces\n"
        echo "If you experience any bugs, please report it here:"
        echo "$ISSUES"
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
        wait
        ifup "$IFACE"
        wait
        bash "$SCRIPTS/test_connection.sh"
        wait
    fi
else
    echo "OK, then we will not set a static IP as your VPS provider already have setup the network for you..."
    sleep 5 & spinner_loading
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
bash $SECURE & spinner_loading

# Generate new SSH Keys
printf "\nGenerating new SSH keys for the server...\n"
rm -v /etc/ssh/ssh_host_*
dpkg-reconfigure openssh-server

# Generate new MySQL password
echo "Generating new MySQL password..."
if bash "$SCRIPTS/change_mysql_pass.sh" && wait
then
   rm "$SCRIPTS/change_mysql_pass.sh"
   {
   echo "[mysqld]"
   echo "innodb_large_prefix=on"
   echo "innodb_file_format=barracuda"
   echo "innodb_file_per_table=1"
   } >> /root/.my.cnf
fi

# Enable UTF8mb4 (4-byte support)
printf "\nEnabling UTF8mb4 support on $NCCONFIGDB....\n"
echo "Please be patient, it may take a while."
sudo /etc/init.d/mysql restart & spinner_loading
RESULT="mysqlshow --user=root --password=$MYSQLMYCNFPASS $NCCONFIGDB| grep -v Wildcard | grep -o $NCCONFIGDB"
if [ "$RESULT" == "$NCCONFIGDB" ]; then
    check_command mysql -u root -e "ALTER DATABASE $NCCONFIGDB CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;"
    wait
fi
check_command sudo -u www-data $NCPATH/occ config:system:set mysql.utf8mb4 --type boolean --value="true"
check_command sudo -u www-data $NCPATH/occ maintenance:repair
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
"phpMyadmin" "(MySQL GUI)       " OFF \
"Collabora" "(Online editing 2GB RAM)   " OFF \
"OnlyOffice" "(Online editing 4GB RAM)   " OFF \
"Nextant" "(Full text search)   " OFF \
"Passman" "(Password storage)   " OFF \
"Spreed.ME" "(Video calls)   " OFF 2>results

while read -r -u 9 choice
do
    case $choice in
        phpMyadmin)
            run_app_script phpmyadmin_install_ubuntu16
        ;;
        OnlyOffice)
            run_app_script onlyoffice
        ;;
        Collabora)
            run_app_script collabora
        ;;

        Nextant)
            run_app_script nextant
        ;;

        Passman)
            run_app_script passman
        ;;

        Spreed.ME)
            run_app_script spreedme
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
    rm "$SCRIPTS"/security.sh
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
service apache2 reload

# Increase max filesize (expects that changes are made in /etc/php/7.0/apache2/php.ini)
# Here is a guide: https://www.techandme.se/increase-max-file-size/
VALUE="# php_value upload_max_filesize 513M"
if ! grep -Fxq "$VALUE" $NCPATH/.htaccess
then
    sed -i 's/  php_value upload_max_filesize 513M/# php_value upload_max_filesize 511M/g' "$NCPATH"/.htaccess
    sed -i 's/  php_value post_max_size 513M/# php_value post_max_size 511M/g' "$NCPATH"/.htaccess
    sed -i 's/  php_value memory_limit 512M/# php_value memory_limit 512M/g' "$NCPATH"/.htaccess
fi

# Add temporary fix if needed
bash $SCRIPTS/temporary-fix.sh
rm "$SCRIPTS"/temporary-fix.sh

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
clear

# Upgrade system
echo "System will now upgrade..."
bash $SCRIPTS/update.sh

# Cleanup 2
apt autoremove -y
apt autoclean
CLEARBOOT=$(dpkg -l linux-* | awk '/^ii/{ print $2}' | grep -v -e "$(uname -r | cut -f1,2 -d"-")" | grep -e "[0-9]" | xargs sudo apt -y purge)
echo "$CLEARBOOT"

ADDRESS2=$(grep "address" /etc/network/interfaces | awk '$1 == "address" { print $2 }')
# Success!
clear
printf "%s\n""${Green}"
echo    "+--------------------------------------------------------------------+"
echo    "|      Congratulations! You have successfully installed Nextcloud!   |"
echo    "|                                                                    |"
printf "|         ${Color_Off}Login to Nextcloud in your browser: ${Cyan}\"$ADDRESS2\"${Green}         |\n"
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

# Set trusted domain in config.php
if [ -f "$SCRIPTS"/trusted.sh ] 
then
    bash "$SCRIPTS"/trusted.sh
    rm -f "$SCRIPTS"/trusted.sh
fi

# Prefer IPv6
sed -i "s|precedence ::ffff:0:0/96  100|#precedence ::ffff:0:0/96  100|g" /etc/gai.conf

# Reboot
any_key "Installation finished, press any key to reboot system..."
rm -f "$SCRIPTS/nextcloud-startup-script.sh"
reboot
