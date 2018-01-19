#!/bin/bash
# shellcheck disable=2034,2059
true
# shellcheck source=lib.sh
FIRST_IFACE=1 && CHECK_CURRENT_REPO=1 . <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)
unset FIRST_IFACE
unset CHECK_CURRENT_REPO

# Tech and Me © - 2018, https://www.techandme.se/

## If you want debug mode, please activate it further down in the code at line ~60

is_root() {
    if [[ "$EUID" -ne 0 ]]
    then
        return 1
    else
        return 0
    fi
}

msg_box() {
local PROMPT="$1"
    whiptail --msgbox "${PROMPT}" "$WT_HEIGHT" "$WT_WIDTH"
}

root_check() {
if ! is_root
then
msg_box "Sorry, you are not root. You now have two options:

1. With SUDO directly:
   a) :~$ sudo bash $SCRIPTS/name-of-script.sh
2. Become ROOT and then type your command:
   a) :~$ sudo -i
   b) :~# $SCRIPTS/name-of-script.sh

In both cases above you can leave out $SCRIPTS/ if the script
is directly in your PATH.
More information can be found here: https://unix.stackexchange.com/a/3064"
    exit 1
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
root_check

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
msg_box "Network NOT OK!

You must have a working Network connection to run this script.
Please report this issue here: $ISSUES"
    exit 1
fi

# Is this run as a pure root user?
if is_root
then
    if [[ "$UNIXUSER" == "ncadmin" ]]
    then
        sleep 1
    else
        if [ -z "$UNIXUSER" ]
        then
msg_box "You seem to be running this as the pure root user.
You must run this as a regular user with sudo permissions.

Please create a user with sudo permissions and the run this command:
sudo -u [user-with-sudo-permissions] sudo bash /var/scripts/nextcloud-startup-script.sh

We will do this for you when you hit OK."
       run_static_script adduser $SCRIPTS/nextcloud-startup-script.sh
       else
msg_box "You probably see this message if the user 'ncadmin' does not exist on the system,
which could be the case if you are running directly from the scripts and not the VM.

As long as the user you created have sudo permissions it's safe to continue.
This would be the case if you in the previous step created a new user with the script.

If the user you are running this script with doesn't have sudo permissions,
please abort this script and report this issue to $ISSUES."
        fi
    fi
fi

# Check if dpkg or apt is running
is_process_running dpkg
is_process_running apt

# Check where the best mirrors are and update
msg_box "To make downloads as fast as possible when updating you should have mirrors that are as close to you as possible.
This VM comes with mirrors based on servers in that where used when the VM was released and packaged.
We recomend you to change the mirrors based on where this is currently installed."
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

msg_box "This script will configure your Nextcloud and activate SSL.
It will also do the following:

- Generate new SSH keys for the server
- Generate new MariaDB password
- Install phpMyadmin and make it secure
- Install selected apps and automatically configure them
- Detect and set hostname
- Upgrade your system and Nextcloud to latest version
- Set secure permissions to Nextcloud
- Set new passwords to Linux and Nextcloud
- Set new keyboard layout
- Change timezone
- Set static IP to the system (you have to set the same IP in
  your router) https://www.techandme.se/open-port-80-443/
  We don't set static IP if you run this on a *remote* VPS.

  The script will take about 10 minutes to finish,
  depending on your internet connection.

####################### Tech and Me - 2018 #######################"
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

# Generate new MariaDB password
echo "Generating new MARIADB password..."
if bash "$SCRIPTS/change_mysql_pass.sh" && wait
then
    rm "$SCRIPTS/change_mysql_pass.sh"
fi

msg_box "The following script will install a trusted
SSL certificate through Let's Encrypt.

It's recommended to use SSL together with Nextcloud.
Please open port 80 and 443 to this servers IP before you continue.

More information can be found here:
https://www.techandme.se/open-port-80-443/"

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

# Change Timezone
echo "Current timezone is $(cat /etc/timezone)"
if [[ "no" == $(ask_yes_or_no "Do you want to change the timezone?") ]]
then
    echo "Not changing timezone..."
    sleep 1
    clear
else
    dpkg-reconfigure tzdata
clear
fi


whiptail --title "Which apps do you want to install?" --checklist --separate-output "Automatically configure and install selected apps\nSelect by pressing the spacebar" "$WT_HEIGHT" "$WT_WIDTH" 4 \
"Fail2ban" "(Extra Bruteforce protection)   " OFF \
"phpMyadmin" "(*SQL GUI)       " OFF \
"Netdata" "(*Real-time server monitoring)       " OFF \
"Collabora" "(Online editing 2GB RAM)   " OFF \
"OnlyOffice" "(Online editing 4GB RAM)   " OFF \
"Passman" "(Password storage)   " OFF \
"Talk" "(Nextcloud Video calls and chat)   " OFF \
"Spreed.ME" "(3rd-party Video calls and chat)   " OFF 2>results

while read -r -u 9 choice
do
    case $choice in
        Fail2ban)
            run_app_script fail2ban
        ;;
        
        Netdata)
            run_app_script netdata
        ;;
        
        phpMyadmin)
            run_app_script phpmyadmin_install_ubuntu16
        ;;
        
        OnlyOffice)
            run_app_script onlyoffice
        ;;
        
        Collabora)
            run_app_script collabora
        ;;

        Passman)
           install_and_enable_app passman
        ;;

        Talk)
            install_and_enable_app spreed
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
rm -f "$SCRIPTS/change_mysql_pass.sh"
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

cat << ROOTNEWPROFILE > "/root/.bash_profile"
# ~/.profile: executed by Bourne-compatible login shells.

if [ "/bin/bash" ]
then
    if [ -f ~/.bashrc ]
    then
        . ~/.bashrc
    fi
fi

if [ -x /var/scripts/nextcloud-startup-script.sh ]
then
    /var/scripts/nextcloud-startup-script.sh
fi

if [ -x /var/scripts/history.sh ]
then
    /var/scripts/history.sh
fi

mesg n

ROOTNEWPROFILE

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
msg_box "Congratulations! You have successfully installed Nextcloud!
Login to Nextcloud in your browser:
- IP: $ADDRESS2 
- Hostname: $(hostname -f)

Some tips and tricks:
1. Publish your server online: https://goo.gl/iUGE2U
2. To login to MariaDB just type: mysql -u root
3. To update this VM just type: sudo bash /var/scripts/update.sh
4. Change IP to something outside DHCP: sudo nano /etc/network/interfaces
5. Please report any bugs here: https://github.com/nextcloud/vm/issues
6. Please ask for help in the forums, visit our shop, or buy support from Nextcloud:
- SUPPORT: https://shop.techandme.se
- FORUM: https://help.nextcloud.com/ 
- NEXTCLOUD: https://nextcloud.com/pricing/
  
###################### Tech and Me - 2018 ######################"

# Set trusted domain in config.php
if [ -f "$SCRIPTS"/trusted.sh ] 
then
    bash "$SCRIPTS"/trusted.sh
    rm -f "$SCRIPTS"/trusted.sh
fi

# Prefer IPv6
sed -i "s|precedence ::ffff:0:0/96  100|#precedence ::ffff:0:0/96  100|g" /etc/gai.conf

# Shutdown MariaDB gracefully
echo "Shutting down MariaDB..."
check_command sudo systemctl stop mariadb.service
rm -f /var/lib/mysql/ib_logfile[01]
echo

# Reboot
any_key "Installation finished, press any key to reboot system..."
rm -f "$SCRIPTS/nextcloud-startup-script.sh"
reboot
