#!/bin/bash
# shellcheck disable=2034,2059
true
# shellcheck source=lib.sh
NCDB=1 && FIRST_IFACE=1 && CHECK_CURRENT_REPO=1 . <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)
unset FIRST_IFACE
unset CHECK_CURRENT_REPO
unset NCDB

# T&M Hansson IT AB © - 2019, https://www.hanssonit.se/

## If you want debug mode, please activate it further down in the code at line ~60

# FUNCTIONS #

msg_box() {
local PROMPT="$1"
    whiptail --msgbox "${PROMPT}" "$WT_HEIGHT" "$WT_WIDTH"
}

is_root() {
    if [[ "$EUID" -ne 0 ]]
    then
        return 1
    else
        return 0
    fi
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

site_200() {
print_text_in_color "$ICyan" "Checking connection..."
        CURL_STATUS="$(curl -sSL -w "%{http_code}" "${1}" | tail -1)"
        if [[ "$CURL_STATUS" = "200" ]]
        then
            return 0
        else
            print_text_in_color "$IRed" "curl didn't produce a 200 status, is the site reachable?"
            return 1
        fi
}

network_ok() {
    print_text_in_color "$ICyan" "Testing if network is OK..."
    install_if_not network-manager
    if ! service network-manager restart > /dev/null
    then
        service networking restart > /dev/null
    fi
    sleep 5 && site_200 github.com
}

check_command() {
  if ! "$@";
  then
     print_text_in_color "$ICyan" "Sorry but something went wrong. Please report this issue to $ISSUES and include the output of the error message. Thank you!"
	 print_text_in_color "$Red" "$* failed"
    exit 1
  fi
}

# Colors
Color_Off='\e[0m'
IRed='\e[0;91m'
IGreen='\e[0;92m'
ICyan='\e[0;96m'

print_text_in_color() {
	printf "%b%s%b\n" "$1" "$2" "$Color_Off"
}

# END OF FUNCTIONS #

# Check if root
root_check

# Check network
if network_ok
then
    printf "${IGreen}Online!${Color_Off}\n"
else
    print_text_in_color "$ICyan" "Setting correct interface..."
    [ -z "$IFACE" ] && IFACE=$(lshw -c network | grep "logical name" | awk '{print $3; exit}')
    # Set correct interface
cat <<-SETDHCP > "/etc/netplan/01-netcfg.yaml"
network:
  version: 2
  renderer: networkd
  ethernets:
    $IFACE:
      dhcp4: yes
      dhcp6: yes
SETDHCP
    check_command netplan apply
    check_command service network-manager restart
    ip link set "$IFACE" down
    wait
    ip link set "$IFACE" up
    wait
    check_command service network-manager restart
    print_text_in_color "$ICyan" "Checking connection..."
    sleep 1
    if ! nslookup github.com
    then
msg_box "The script failed to get an address from DHCP.
You must have a working network connection to run this script.

You will now be provided with the option to set a static IP manually instead."

    # Copy old interfaces files
msg_box "Copying old netplan.io config files file to:
/tmp/netplan_io_backup/"
    if [ -d /etc/netplan/ ]
    then
        mkdir -p /tmp/netplan_io_backup
        check_command cp -vR /etc/netplan/* /tmp/netplan_io_backup/
    fi

    # Ask for IP address
cat << ENTERIP
+----------------------------------------------------------+
|    Please enter the static IP address you want to set,   |
|    including the subnet. Example: 192.168.1.100/24       |
+----------------------------------------------------------+
ENTERIP
    echo
    read -r LANIP
    echo

    # Ask for gateway address
cat << ENTERGATEWAY
+----------------------------------------------------------+
|    Please enter the gateway address you want to set,     |
|    Example: 192.168.1.1                                  |
+----------------------------------------------------------+
ENTERGATEWAY
    echo
    read -r GATEWAYIP
    echo

    # Create the Static IP file
cat <<-IPCONFIG > /etc/netplan/01-netcfg.yaml
network:
   version: 2
   renderer: networkd
   ethernets:
       $IFACE: #object name
         dhcp4: no # dhcp v4 disable
         dhcp6: no # dhcp v6 disable
         addresses: [$LANIP] # client IP address
         gateway4: $GATEWAYIP # gateway address
         nameservers:
           addresses: [9.9.9.9,149.112.112.112] #name servers
IPCONFIG

msg_box "These are your settings, please make sure they are correct:

$(cat /etc/netplan/01-netcfg.yaml)"
    netplan try
    fi
fi

# Check network again
if network_ok
then
    printf "${IGreen}Online!${Color_Off}\n"
else
msg_box "Network NOT OK. You must have a working network connection to run this script.

Please contact us for support:
https://shop.hanssonit.se/product/premium-support-per-30-minutes/

Please also post this issue on: https://github.com/nextcloud/vm/issues"
    exit 1
fi

# shellcheck source=lib.sh
NCDB=1 && CHECK_CURRENT_REPO=1 && NC_UPDATE=1 . <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)
unset NC_UPDATE
unset CHECK_CURRENT_REPO
unset NCDB

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Nextcloud 13 is required.
lowest_compatible_nc 13

# Check that this run on the PostgreSQL VM
if ! which psql > /dev/null
then
    print_text_in_color "$Red" "This script is intended to be run on then PostgreSQL VM but PostgreSQL is not installed."
    print_text_in_color "$Red" "Aborting..."
    exit 1
fi

# Set keyboard layout, important when changing passwords and such
if [ "$KEYBOARD_LAYOUT" = "se" ]
then
    clear
    print_text_in_color "$ICyan" "Current keyboard layout is Swedish."
    if [[ "no" == $(ask_yes_or_no "Do you want to change keyboard layout?") ]]
    then
        print_text_in_color "$ICyan" "Not changing keyboard layout..."
        sleep 1
        clear
    else
        dpkg-reconfigure keyboard-configuration
        msg_box "We will now try to set the new keyboard layout directly in this session. If that fails, the server will be rebooted to apply the new keyboard settings.\n\nIf the server are rebooted, please login as usual and run this script again."
	if ! setupcon
        then
            reboot 
        fi
    fi
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
       download_static_script adduser
       bash $SCRIPTS/adduser.sh "$SCRIPTS/nextcloud-startup-script.sh"
       rm $SCRIPTS/adduser.sh
       else
msg_box "You probably see this message if the user 'ncadmin' does not exist on the system,
which could be the case if you are running directly from the scripts on Gihub and not the VM.

As long as the user you created have sudo permissions it's safe to continue.
This would be the case if you created a new user with the script in the previous step.

If the user you are running this script with is a user that doesn't have sudo permissions,
please abort this script and report this issue to $ISSUES."
        fi
    fi
fi

# Check if dpkg or apt is running
is_process_running apt
is_process_running dpkg

echo
print_text_in_color "$ICyan" "Getting scripts from GitHub to be able to run the first setup..."
# Scripts in static (.sh, .php, .py)
download_static_script temporary-fix
download_static_script update
download_static_script trusted
download_static_script test_connection
download_static_script setup_secure_permissions_nextcloud
download_static_script change_db_pass
download_static_script nextcloud
download_static_script update-config
download_static_script index
download_le_script activate-ssl

mv $SCRIPTS/index.php $HTML/index.php && rm -f $HTML/html/index.html
chmod 750 $HTML/index.php && chown www-data:www-data $HTML/index.php

# Change 000-default to $WEB_ROOT
sed -i "s|DocumentRoot /var/www/html|DocumentRoot $HTML|g" /etc/apache2/sites-available/000-default.conf

# Make possible to see the welcome screen (without this php-fpm won't reach it)
 sed -i '14i\    # http://lost.l-w.ca/0x05/apache-mod_proxy_fcgi-and-php-fpm/' /etc/apache2/sites-available/000-default.conf
 sed -i '15i\   <FilesMatch "\.php$">' /etc/apache2/sites-available/000-default.conf
 sed -i '16i\    <If "-f %{SCRIPT_FILENAME}">' /etc/apache2/sites-available/000-default.conf
 sed -i '17i\      SetHandler "proxy:unix:/run/php/php'$PHPVER'-fpm.nextcloud.sock|fcgi://localhost"' /etc/apache2/sites-available/000-default.conf
 sed -i '18i\   </If>' /etc/apache2/sites-available/000-default.conf
 sed -i '19i\   </FilesMatch>' /etc/apache2/sites-available/000-default.conf
 sed -i '20i\    ' /etc/apache2/sites-available/000-default.conf

# Make $SCRIPTS excutable
chmod +x -R $SCRIPTS
chown root:root -R $SCRIPTS

# Allow $UNIXUSER to run figlet script
chown "$UNIXUSER":"$UNIXUSER" "$SCRIPTS/nextcloud.sh"

msg_box() {
local PROMPT="$1"
    whiptail --title "Nextcloud VM - T&M Hansson IT - $(date +"%Y")" --msgbox "${PROMPT}" "$WT_HEIGHT" "$WT_WIDTH"
}

msg_box "This script will configure your Nextcloud and activate SSL.
It will also do the following:

- Generate new SSH keys for the server
- Generate new PostgreSQL password
- Install selected apps and automatically configure them
- Detect and set hostname
- Detect and set trusted domains
- Detect the best Ubuntu mirrors depending on your location
- Upgrade your system and Nextcloud to latest version
- Set secure permissions to Nextcloud
- Set new passwords to Linux and Nextcloud
- Change timezone
- Set correct Rewriterules for Nextcloud
- Copy content from .htaccess to .user.ini (because we use php-fpm)
- Add additional options if you choose them
- And more..."

msg_box "Please note:

[#] The script will take about 10 minutes to finish, depending on your internet connection.

[#] When complete it will delete all the *.sh, *.html, *.tar, *.zip inside:
    /root
    /home/$UNIXUSER

[#] Please consider donating if you like the product:
    https://shop.hanssonit.se/product-category/donate/

[#] You can also ask for help here:
    https://help.nextcloud.com/c/support/appliances-docker-snappy-vm
    https://shop.hanssonit.se/product/premium-support-per-30-minutes/"
clear

# Change Timezone
print_text_in_color "$ICyan" "Current timezone is $(cat /etc/timezone)"
if [[ "no" == $(ask_yes_or_no "Do you want to change the timezone?") ]]
then
    print_text_in_color "$ICyan" "Not changing timezone..."
    sleep 1
    clear
else
    dpkg-reconfigure tzdata
    clear
fi

# Check where the best mirrors are and update
msg_box "To make downloads as fast as possible when updating you should have mirrors that are as close to you as possible.
This VM comes with mirrors based on servers in that where used when the VM was released and packaged.

If you are located outside of Europe, we recomend you to change the mirrors so that downloads are faster."
print_text_in_color "$ICyan" "Checking current mirror..."
print_text_in_color "$ICyan" "Your current server repository is: $REPO"

if [[ "no" == $(ask_yes_or_no "Do you want to try to find a better mirror?") ]]
then
    print_text_in_color "$ICyan" "Keeping $REPO as mirror..."
    sleep 1
else
    print_text_in_color "$ICyan" "Locating the best mirrors..."
    apt update -q4 & spinner_loading
    apt install python-pip -y
    pip install \
        --upgrade pip \
        apt-select
    check_command apt-select -m up-to-date -t 5 -c -C "$(localectl status | grep "Layout" | awk '{print $3}')"
    sudo cp /etc/apt/sources.list /etc/apt/sources.list.backup && \
    if [ -f sources.list ]
    then
        sudo mv sources.list /etc/apt/
    fi
fi
clear

# Pretty URLs
print_text_in_color "$ICyan" "Setting RewriteBase to \"/\" in config.php..."
chown -R www-data:www-data $NCPATH
occ_command config:system:set overwrite.cli.url --value="http://localhost/"
occ_command config:system:set htaccess.RewriteBase --value="/"
occ_command maintenance:update:htaccess
bash $SECURE & spinner_loading

# Generate new SSH Keys
printf "\nGenerating new SSH keys for the server...\n"
rm -v /etc/ssh/ssh_host_*
dpkg-reconfigure openssh-server

# Generate new PostgreSQL password
print_text_in_color "$ICyan" "Generating new PostgreSQL password..."
check_command bash "$SCRIPTS/change_db_pass.sh"
sleep 3
clear

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
    print_text_in_color "$ICyan" "OK, but if you want to run it later, just type: sudo bash $SCRIPTS/activate-ssl.sh"
    any_key "Press any key to continue..."
fi
clear

# Install Apps
whiptail --title "Which apps do you want to install?" --checklist --separate-output "Automatically configure and install selected apps\nSelect by pressing the spacebar" "$WT_HEIGHT" "$WT_WIDTH" 4 \
"Fail2ban" "(Extra Bruteforce protection)   " OFF \
"Adminer" "(PostgreSQL GUI)       " OFF \
"Netdata" "(Real-time server monitoring)       " OFF \
"Collabora" "(Online editing [2GB RAM])   " OFF \
"OnlyOffice" "(Online editing [4GB RAM])   " OFF \
"Bitwarden" "(External password manager)   " OFF \
"FullTextSearch" "(Elasticsearch for Nextcloud [2GB RAM])   " OFF \
"PreviewGenerator" "(Pre-generate previews)   " OFF \
"Talk" "(Nextcloud Video calls and chat)   " OFF 2>results

while read -r -u 9 choice
do
    case $choice in
        Fail2ban)
            clear
            run_app_script fail2ban
        ;;
        
        Adminer)
            clear
            run_app_script adminer
        ;;
        
        Netdata)
            clear
            run_app_script netdata
        ;;
        
        OnlyOffice)
            clear
            run_app_script onlyoffice
        ;;
        
        Collabora)
            clear
            run_app_script collabora
        ;;

        Bitwarden)
            clear
            run_app_script tmbitwarden
        ;;
        
        FullTextSearch)
            clear
           run_app_script fulltextsearch
        ;;             
        
        PreviewGenerator)
            clear
           run_app_script previewgenerator
        ;;   

        Talk)
            clear
            run_app_script talk
        ;;

        *)
        ;;
    esac
done 9< results
rm -f results
clear

# Change passwords
# CLI USER
print_text_in_color "$ICyan" "For better security, change the system user password for [$(getent group sudo | cut -d: -f4 | cut -d, -f1)]"
any_key "Press any key to change password for system user..."
while true
do
    sudo passwd "$(getent group sudo | cut -d: -f4 | cut -d, -f1)" && break
done
echo
clear
# NEXTCLOUD USER
NCADMIN=$(occ_command user:list | awk '{print $3}')
print_text_in_color "$ICyan" "The current admin user in Nextcloud GUI is [$NCADMIN]"
print_text_in_color "$ICyan" "We will now replace this user with your own."
any_key "Press any key to replace the current admin user for Nextcloud..."
# Create new user
while true
do
    print_text_in_color "$ICyan" "Please enter the username for your new user:"
    read -r NEWUSER
    sudo -u www-data $NCPATH/occ user:add "$NEWUSER" -g admin && break
done
# Delete old user
if [[ "$NCADMIN" ]]
then
    print_text_in_color "$ICyan" "Deleting $NCADMIN..."
    occ_command user:delete "$NCADMIN"
fi
clear

# Set notifications for admin
NCADMIN=$(occ_command user:list | awk '{print $3}')
occ_command notification:generate -l "Please remember to setup SMTP to be able to send shared links, user notifications and more via email. Please go here and start setting it up: https://your-nextcloud/settings/admin." "$NCADMIN" "Please setup SMTP"
occ_command notification:generate -l "If you need support, please visit the shop: https://shop.hanssonit.se" "$NCADMIN" "Do you need support?"

# Fixes https://github.com/nextcloud/vm/issues/58
a2dismod status
restart_webserver

# Increase max filesize (expects that changes are made in $PHP_INI)
# Here is a guide: https://www.techandme.se/increase-max-file-size/
configure_max_upload

# Extra configurations
whiptail --title "Extra configurations" --checklist --separate-output "Choose what you want to configure\nSelect by pressing the spacebar" "$WT_HEIGHT" "$WT_WIDTH" 4 \
"Security" "(Add extra security based on this http://goo.gl/gEJHi7)" OFF \
"ModSecurity" "(Add ModSecurity for Apache2" OFF \
"Static IP" "(Set static IP in Ubuntu with netplan.io)" OFF \
"Automatic updates" "(Automatically update your server every week on Sundays)" OFF 2>results

while read -r -u 9 choice
do
    case $choice in
        "Security")
            clear
            run_static_script security
        ;;
        
        "ModSecurity")
            clear
            run_static_script modsecurity
        ;;

        "Static IP")
            clear
            run_static_script static_ip
        ;;
        
	"Automatic updates")
            clear
            run_static_script automatic_updates
        ;;	

        *)
        ;;
    esac
done 9< results
rm -f results

# Calculate the values of PHP-FPM based on the amount of RAM available (minimum 2 GB or 8 children)
calculate_php_fpm

# Run again if values are reset on last run
calculate_php_fpm

# Add temporary fix if needed
bash $SCRIPTS/temporary-fix.sh
rm "$SCRIPTS"/temporary-fix.sh

# Cleanup 1
occ_command maintenance:repair
rm -f "$SCRIPTS/ip.sh"
rm -f "$SCRIPTS/change_db_pass.sh"
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

# Download all app scripts
print_text_in_color "$ICyan" "Downloading all the latest app scripts to $SCRIPTS/apps..."
mkdir -p $SCRIPTS/apps
cd $SCRIPTS/apps
check_command curl -s https://codeload.github.com/nextcloud/vm/tar.gz/master | tar -xz --strip=2 vm-master/apps

# Upgrade system
print_text_in_color "$ICyan" "System will now upgrade..."
bash $SCRIPTS/update.sh

# Cleanup 2
apt autoremove -y
apt autoclean

# Set trusted domain in config.php
if [ -f "$SCRIPTS"/trusted.sh ] 
then
    bash "$SCRIPTS"/trusted.sh
    rm -f "$SCRIPTS"/trusted.sh
else
    run_static_script trusted
fi

# Success!
msg_box "Congratulations! You have successfully installed Nextcloud!

Login to Nextcloud in your browser:
- IP: $ADDRESS
- Hostname: $(hostname -f)

SUPPORT:
Please ask for help in the forums, visit our shop to buy support,
or buy a yearly subscription from Nextcloud:
- SUPPORT: https://shop.hanssonit.se/product/premium-support-per-30-minutes/
- FORUM: https://help.nextcloud.com/
- SUBSCRIPTION: https://nextcloud.com/pricing/ (Please refer to @enoch85)

Please report any bugs here: https://github.com/nextcloud/vm/issues

TIPS & TRICKS:
1. Publish your server online: https://goo.gl/iUGE2U

2. To login to PostgreSQL just type: sudo -u postgres psql nextcloud_db

3. To update this VM just type: sudo bash /var/scripts/update.sh

4. Change IP to something outside DHCP: sudo nano /etc/netplan/01-netcfg.yaml

5. For a better experiance it's a good idea to setup an email account here:
   https://yourcloud.xyz/settings/admin"

# Prefer IPv6
sed -i "s|precedence ::ffff:0:0/96  100|#precedence ::ffff:0:0/96  100|g" /etc/gai.conf

# Reboot
print_text_in_color "$IGreen" "Installation done, system will now reboot..."
rm -f "$SCRIPTS/nextcloud-startup-script.sh"
reboot
