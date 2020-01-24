#!/bin/bash

# T&M Hansson IT AB © - 2020, https://www.hanssonit.se/

#########

IRed='\e[0;91m'         # Red
IGreen='\e[0;92m'       # Green
ICyan='\e[0;96m'        # Cyan
Color_Off='\e[0m'       # Text Reset
print_text_in_color() {
	printf "%b%s%b\n" "$1" "$2" "$Color_Off"
}

print_text_in_color "$ICyan" "Fetching all the variables from lib.sh..."

is_process_running() {
PROCESS="$1"

while :
do
    RESULT=$(pgrep "${PROCESS}")

    if [ "${RESULT:-null}" = null ]; then
            break
    else
            print_text_in_color "$ICyan" "${PROCESS} is running, waiting for it to stop..."
            sleep 10
    fi
done
}

#########

# Check if dpkg or apt is running
is_process_running apt
is_process_running dpkg

# Use local lib file in case there is no internet connection
if [ -f /var/scripts/lib.sh ]
then
# shellcheck disable=2034,2059
true
# shellcheck source=lib.sh
NCDB=1 && FIRST_IFACE=1 && CHECK_CURRENT_REPO=1 source /var/scripts/lib.sh
unset NCDB
unset FIRST_IFACE
unset  CHECK_CURRENT_REPO
 # If we have internet, then use the latest variables from the lib remote file
elif print_text_in_color "$ICyan" "Testing internet connection..." && ping github.com -c 2
then
true
# shellcheck source=lib.sh
NCDB=1 && FIRST_IFACE=1 && CHECK_CURRENT_REPO=1 . <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)
unset FIRST_IFACE
unset CHECK_CURRENT_REPO
unset NCDB
else
    print_text_in_color "$IRed" "You don't seem to have a working internet connection, and /var/scripts/lib.sh is missing so you can't run this script."
    print_text_in_color "$ICyan" "Please report this to https://github.com/nextcloud/vm/issues/"
    exit 1
fi

# Check if root
root_check

# Check network
if network_ok
then
    print_text_in_color "$IGreen" "Online!"
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

        # Run static_ip script
	bash /var/scripts/static_ip.sh
    fi
fi

# Check network again
if network_ok
then
    print_text_in_color "$IGreen" "Online!"
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

# Nextcloud 16 is required.
lowest_compatible_nc 16

# Check that this run on the PostgreSQL VM
if ! is_this_installed postgresql-10
then
    print_text_in_color "$IRed" "This script is intended to be run using a PostgreSQL database, but PostgreSQL is not installed."
    print_text_in_color "$IRed" "Aborting..."
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
        msg_box "We will now set the new keyboard layout directly in this session and reboot the server to apply the new keyboard settings.\n\nWhen the server are rebooted, please login as usual and run this script again."
	setupcon --force && reboot
    fi
fi

# Set locales
print_text_in_color "$ICyan" "Setting locales..."
KEYBOARD_LAYOUT=$(localectl status | grep "Layout" | awk '{print $3}')
if [ "$KEYBOARD_LAYOUT" = "se" ]
then
    print_text_in_color "$ICyan" "Svensk locale är redan konfigurerad."
elif [ "$KEYBOARD_LAYOUT" = "de" ]
then 
    sudo locale-gen "de_DE.UTF-8" && sudo dpkg-reconfigure --frontend=noninteractive locales
elif [ "$KEYBOARD_LAYOUT" = "us" ]
then
    sudo locale-gen "en_US.UTF-8" && sudo dpkg-reconfigure --frontend=noninteractive locales
elif [ "$KEYBOARD_LAYOUT" = "fr" ]
then
    sudo locale-gen "fr_FR.UTF-8" && sudo dpkg-reconfigure --frontend=noninteractive locales
elif [ "$KEYBOARD_LAYOUT" = "ch" ]
then
    sudo locale-gen "de_CH.UTF-8" && sudo dpkg-reconfigure --frontend=noninteractive locales
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

######## The first setup is OK to run to this point several times, but not any further ########
if [ -f "$SCRIPTS/you-can-not-run-the-startup-script-several-times" ]
then
msg_box "The Nextcloud startup script that handles the first setup (this one) is desinged to be run once, not several times in a row.

If you feel uncertain about adding some extra features during this setup, then it's best to wait until after the first setup is done. You can always add all the extra features later.

[For the Nextcloud VM:]
Please delete this VM from your host and reimport it once again, then run this setup like you did the first time.

[For the Nextcloud Home/SME Server:]
It's a bit more tricky since you can't revert in the same way as with a VM. The best thing you can do now is to save all the output from the session you ran before this one + write down all the steps you took and send and email to:
github@hanssonit.se with the subject 'Issues with first setup', and we'll take it from there.

Full documentation can be found here: https://docs.hanssonit.se
Please report any bugs you find here: $ISSUES"
    exit 1
fi

touch "$SCRIPTS/you-can-not-run-the-startup-script-several-times"

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
download_static_script apps
download_le_script activate-ssl
if home_sme_server
then
    download_static_script nhss_index
    mv $SCRIPTS/nhss_index.php $HTML/index.php && rm -f $HTML/html/index.html
    chmod 750 $HTML/index.php && chown www-data:www-data $HTML/index.php
else
    download_static_script index
    mv $SCRIPTS/index.php $HTML/index.php && rm -f $HTML/html/index.html
    chmod 750 $HTML/index.php && chown www-data:www-data $HTML/index.php
fi

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

[#] Please read the on-screen instructions carefully, they will guide you through the setup.

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
fi

# Change timezone in PHP
sed -i "s|;date.timezone.*|date.timezone = $(cat /etc/timezone)|g" "$PHP_INI"

# Change timezone for logging
occ_command config:system:set logtimezone --value="$(cat /etc/timezone)"
clear

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

# Extra configurations
whiptail --title "Extra configurations" --checklist --separate-output "Choose what you want to configure\nSelect by pressing the spacebar" "$WT_HEIGHT" "$WT_WIDTH" 4 \
"Security" "(Add extra security based on this http://goo.gl/gEJHi7)" OFF \
"Static IP" "(Set static IP in Ubuntu with netplan.io)" OFF \
"Automatic updates" "(Automatically update your server every week on Sundays)" OFF \
"CookieLifetime" "(Configure forced logout timeout for users using the web GUI)" OFF 2>results

while read -r -u 9 choice
do
    case $choice in
        "Security")
            clear
            run_static_script security
        ;;
	
        "Static IP")
            clear
            run_static_script static_ip
            rm -f "$SCRIPTS"/lib.sh
        ;;

	"Automatic updates")
            clear
            run_static_script automatic_updates
        ;;
		
        CookieLifetime)
            clear
            run_static_script cookielifetime
        ;;

        *)
        ;;
    esac
done 9< results
rm -f results

# Let's Encrypt
msg_box "The following script will install a trusted
SSL certificate through Let's Encrypt.

It's recommended to use SSL together with Nextcloud.
Please open port 80 and 443 to this servers IP before you continue.

More information can be found here:
https://www.techandme.se/open-port-80-443/"

if [[ "yes" == $(ask_yes_or_no "Do you want to install SSL?") ]]
then
    bash $SCRIPTS/activate-ssl.sh
else
    echo
    print_text_in_color "$ICyan" "OK, but if you want to run it later, just type: sudo bash $SCRIPTS/activate-ssl.sh"
    any_key "Press any key to continue..."
fi
clear

# Install apps
bash $SCRIPTS/apps.sh

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
    sleep 2
fi
clear

# Add default notifications
notify_admin_gui \
"Please setup SMTP" \
"Please remember to setup SMTP to be able to send shared links, user notifications and more via email. Please go here and start setting it up: https://your-nextcloud/settings/admin."

notify_admin_gui \
"Do you need support?" \
"If you need support, please visit the shop: https://shop.hanssonit.se, or the forum: https://help.nextcloud.com."

# Fixes https://github.com/nextcloud/vm/issues/58
a2dismod status
restart_webserver

if home_sme_server
then
    # Add specific values to PHP-FPM based on 16 GB RAM
    check_command sed -i "s|pm.max_children.*|pm.max_children = 300|g" "$PHP_POOL_DIR"/nextcloud.conf
    check_command sed -i "s|pm.start_servers.*|pm.start_servers = 50|g" "$PHP_POOL_DIR"/nextcloud.conf
    check_command sed -i "s|pm.min_spare_servers.*|pm.min_spare_servers = 50|g" "$PHP_POOL_DIR"/nextcloud.conf
    check_command sed -i "s|pm.max_spare_servers.*|pm.max_spare_servers = 200|g" "$PHP_POOL_DIR"/nextcloud.conf
    restart_webserver
else
    # Calculate the values of PHP-FPM based on the amount of RAM available (minimum 2 GB or 8 children)
    calculate_php_fpm

    # Run again if values are reset on last run
    calculate_php_fpm
fi

# Add temporary fix if needed
bash "$SCRIPTS"/temporary-fix.sh
rm "$SCRIPTS"/temporary-fix.sh

# Cleanup 1
occ_command maintenance:repair
rm -f "$SCRIPTS/ip.sh"
rm -f "$SCRIPTS/change_db_pass.sh"
rm -f "$SCRIPTS/test_connection.sh"
rm -f "$SCRIPTS/instruction.sh"
rm -f "$NCDATA/nextcloud.log"
rm -f "$SCRIPTS/static_ip.sh"

find /root "/home/$UNIXUSER" -type f \( -name '*.sh*' -o -name '*.html*' -o -name '*.tar*' -o -name 'results' -o -name '*.zip*' \) -delete
find "$NCPATH" -type f \( -name 'results' -o -name '*.sh*' \) -delete
sed -i "s|instruction.sh|nextcloud.sh|g" "/home/$UNIXUSER/.bash_profile"

truncate -s 0 \
    /root/.bash_history \
    "/home/$UNIXUSER/.bash_history" \
    /var/spool/mail/root \
    "/var/spool/mail/$UNIXUSER" \
    /var/log/apache2/access.log \
    /var/log/apache2/error.log \
    /var/log/cronjobs_success.log \
    "$VMLOGS/nextcloud.log"

sed -i "s|sudo -i||g" "/home/$UNIXUSER/.bash_profile"

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

5. For a better experience it's a good idea to setup an email account here:
   https://yourcloud.xyz/settings/admin"

# Prefer IPv6
sed -i "s|precedence ::ffff:0:0/96  100|#precedence ::ffff:0:0/96  100|g" /etc/gai.conf

# Reboot
print_text_in_color "$IGreen" "Installation done, system will now reboot..."
rm -f "$SCRIPTS/you-can-not-run-the-startup-script-several-times"
rm -f "$SCRIPTS/nextcloud-startup-script.sh"
reboot
