#!/bin/bash

# T&M Hansson IT AB © - 2024, https://www.hanssonit.se/
# GNU General Public License v3.0
# https://github.com/nextcloud/vm/blob/main/LICENSE

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

true
SCRIPT_NAME="Nextcloud Startup Script"
# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh

# Get all needed variables from the library
ncdb

# Check if root
root_check

# Create a snapshot before modifying anything
check_free_space
if does_snapshot_exist "NcVM-installation" || [ "$FREE_SPACE" -ge 50 ]
then
    if does_snapshot_exist "NcVM-installation"
    then
        check_command lvremove /dev/ubuntu-vg/NcVM-installation -y
    fi
    if ! lvcreate --size 5G --snapshot --name "NcVM-startup" /dev/ubuntu-vg/ubuntu-lv
    then
        msg_box "The creation of a snapshot failed.
If you just merged and old one, please reboot your server once more.
It should work afterwards again."
        exit 1
    fi
fi

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
      dhcp4: true
      dhcp6: true
SETDHCP
    check_command netplan apply
    print_text_in_color "$ICyan" "Checking connection..."
    sleep 1
    set_systemd_resolved_dns "$IFACE"
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
elif home_sme_server
then
    msg_box "It seems like the last try failed as well using LAN ethernet.

Since the Home/SME server is equipped with a Wi-Fi module, you will now be asked to enable it to get connectivity.

Please note: It's not recommended to run a server on Wi-Fi; using an ethernet cable is always the best."
    if yesno_box_yes "Do you want to enable Wi-Fi on this server?"
    then
        install_if_not network-manager
        nmtui
    fi
        if network_ok
        then
            print_text_in_color "$IGreen" "Online!"
	else
        msg_box "Network is NOT OK. You must have a working network connection to run this script.

Please contact us for support:
https://shop.hanssonit.se/product/premium-support-per-30-minutes/

Please also post this issue on: https://github.com/nextcloud/vm/issues"
        exit 1
        fi
else
    msg_box "Network is NOT OK. You must have a working network connection to run this script.

Please contact us for support:
https://shop.hanssonit.se/product/premium-support-per-30-minutes/

Please also post this issue on: https://github.com/nextcloud/vm/issues"
    exit 1
fi

# Check that this run on the PostgreSQL VM
if ! is_this_installed postgresql-common
then
    print_text_in_color "$IRed" "This script is intended to be \
run using a PostgreSQL database, but PostgreSQL is not installed."
    print_text_in_color "$IRed" "Aborting..."
    exit 1
fi

# Run the startup menu
run_script MENU startup_configuration

true
SCRIPT_NAME="Nextcloud Startup Script"
# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh

# Get all needed variables from the library
ncdb
nc_update

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Nextcloud 21 is required
lowest_compatible_nc 21

# Add temporary fix if needed
if network_ok
then
    run_script STATIC temporary-fix-beginning
fi

# Import if missing and export again to import it with UUID
zpool_import_if_missing

# Set phone region (needs the latest KEYBOARD_LAYOUT from lib)
# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh
if [ -n "$KEYBOARD_LAYOUT" ]
then
    nextcloud_occ config:system:set default_phone_region --value="$KEYBOARD_LAYOUT"
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
            msg_box "You seem to be running this as the root user.
You must run this as a regular user with sudo permissions.

Please create a user with sudo permissions and the run this command:
sudo -u [user-with-sudo-permissions] sudo bash /var/scripts/nextcloud-startup-script.sh

We will do this for you when you hit OK."
       download_script STATIC adduser
       bash $SCRIPTS/adduser.sh "$SCRIPTS/nextcloud-startup-script.sh"
       rm $SCRIPTS/adduser.sh
       else
           msg_box "You probably see this message if the user 'ncadmin' does not exist on the system,
which could be the case if you are running directly from the scripts on Github and not the VM.

As long as the user you created have sudo permissions it's safe to continue.
This would be the case if you created a new user with the script in the previous step.

If the user you are running this script with is a user that doesn't have sudo permissions,
please abort this script and report this issue to $ISSUES."
            if yesno_box_yes "Do you want to abort this script?"
            then
                exit
            fi
        fi
    fi
fi

######## The first setup is OK to run to this point several times, but not any further ########
if [ -f "$SCRIPTS/you-can-not-run-the-startup-script-several-times" ]
then
    msg_box "The $SCRIPT_NAME script that handles this first setup \
is designed to be run once, not several times in a row.

If you feel uncertain about adding some extra features during this setup, \
then it's best to wait until after the first setup is done. You can always add all the extra features later.

[For the Nextcloud VM:]
Please delete this VM from your host and reimport it once again, then run this setup like you did the first time.

[For the Nextcloud Home/SME Server:]
It's a bit trickier since you can't revert in the same way as a VM. \
The best thing you can do now is to save all the output from the session you \
ran before this one + write down all the steps you took and send and email to:
github@hanssonit.se with the subject 'Issues with first setup', and we'll take it from there.

Full documentation can be found here: https://docs.hanssonit.se
Please report any bugs you find here: $ISSUES"
    exit 1
fi

touch "$SCRIPTS/you-can-not-run-the-startup-script-several-times"

if home_sme_server
then
    download_script STATIC nhss_index
    mv $SCRIPTS/nhss_index.php $HTML/index.php && rm -f $HTML/html/index.html
    chmod 750 $HTML/index.php && chown www-data:www-data $HTML/index.php
else
    download_script STATIC index
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

# Allow $UNIXUSER to run figlet script
chown "$UNIXUSER":"$UNIXUSER" "$SCRIPTS/nextcloud.sh"

msg_box "This script will configure your Nextcloud and activate TLS.
It will also do the following:

- Generate new SSH keys for the server
- Generate new PostgreSQL password
- Install selected apps and automatically configure them
- Detect and set hostname
- Detect and set trusted domains
- Upgrade your system and Nextcloud to latest version
- Set secure permissions to Nextcloud
- Set new passwords to Linux and Nextcloud
- Change timezone
- Set correct Rewriterules for Nextcloud
- Copy content from .htaccess to .user.ini (because we use php-fpm)
- Add additional options if you choose them
- Set correct CPU cores for Imaginary
- And more..."

msg_box "PLEASE NOTE:
[#] Please finish the whole setup. The server will reboot once done.

[#] Please read the on-screen instructions carefully, they will guide you through the setup.

[#] When complete it will delete all the *.sh, *.html, *.tar, *.zip inside:
    /root
    /home/$UNIXUSER

[#] Please consider donating if you like the product:
    https://shop.hanssonit.se/product-category/donate/

[#] You can also ask for help here:
    https://help.nextcloud.com/c/support/appliances-docker-snappy-vm
    https://shop.hanssonit.se/product/premium-support-per-30-minutes/"

msg_box "PLEASE NOTE:

The first setup is meant to be run once, and not aborted.
If you feel uncertain about the options during the setup, just choose the defaults by hitting [ENTER] at each question.

When the setup is done, the server will automatically reboot.

Please report any issues to: $ISSUES"

# Change timezone in PHP
sed -i "s|;date.timezone.*|date.timezone = $(cat /etc/timezone)|g" "$PHP_INI"

# Change timezone for logging
nextcloud_occ config:system:set logtimezone --value="$(cat /etc/timezone)"

# Pretty URLs
print_text_in_color "$ICyan" "Setting RewriteBase to \"/\" in config.php..."
chown -R www-data:www-data $NCPATH
nextcloud_occ config:system:set overwrite.cli.url --value="http://localhost/"
nextcloud_occ config:system:set htaccess.RewriteBase --value="/"
nextcloud_occ maintenance:update:htaccess
bash $SECURE & spinner_loading

# Generate new SSH Keys
printf "\nGenerating new SSH keys for the server...\n"
rm -v /etc/ssh/ssh_host_*
dpkg-reconfigure openssh-server

# Generate new PostgreSQL password
print_text_in_color "$ICyan" "Generating new PostgreSQL password..."
check_command bash "$SCRIPTS/change_db_pass.sh"
sleep 3

# Server configurations
bash $SCRIPTS/server_configuration.sh

# Nextcloud configuration
bash $SCRIPTS/nextcloud_configuration.sh

# Install apps
bash $SCRIPTS/additional_apps.sh

### Change passwords
# CLI USER
UNIXUSER="$(getent group sudo | cut -d: -f4 | cut -d, -f1)"
if [[ "$UNIXUSER" != "ncadmin" ]]
then
   print_text_in_color "$ICyan" "No need to change password for CLI user '$UNIXUSER' since it's not the default user."
else
    msg_box "For better security, we will now change the password for the CLI user in Ubuntu."
    while :
    do
        UNIX_PASSWORD=$(input_box_flow "Please type in the new password for the current CLI user in Ubuntu: $UNIXUSER.")
        if [[ "$UNIX_PASSWORD" == *" "* ]]
        then
            msg_box "Please don't use spaces."
        else
            break
        fi
    done
    if check_command echo "$UNIXUSER:$UNIX_PASSWORD" | sudo chpasswd
    then
        msg_box "The new password for the current CLI user in Ubuntu ($UNIXUSER) is now set to: $UNIX_PASSWORD

This is used when you login to the Ubuntu CLI."
    fi
fi
unset UNIX_PASSWORD

# NEXTCLOUD USER
NCADMIN=$(nextcloud_occ user:list | awk '{print $3}')
if [[ "$NCADMIN" != "ncadmin" ]]
then
   print_text_in_color "$ICyan" "No need to change password for GUI user '$NCADMIN' since it's not the default user."
else
    msg_box "We will now change the username and password for the Web Admin in Nextcloud."
    while :
    do
        NEWUSER=$(input_box_flow "Please type in the name of the Web Admin in Nextcloud.
It must differ from the current one: $NCADMIN.\n\nThe only allowed characters for the username are:
'a-z', 'A-Z', '0-9', and '_.@-'")
        if [[ "$NEWUSER" == *" "* ]]
        then
            msg_box "Please don't use spaces."
        elif [ "$NEWUSER" = "$NCADMIN" ]
        then
            msg_box "This username ($NCADMIN) is already in use. Please choose a different one."
        # - has to be escaped otherwise it won't work.
        # Inspired by: https://unix.stackexchange.com/a/498731/433213
        elif [ "${NEWUSER//[A-Za-z0-9_.\-@]}" ]
        then
            msg_box "Allowed characters for the username are:\na-z', 'A-Z', '0-9', and '_.@-'\n\nPlease try again."
        else
            break
        fi
    done
    while :
    do
        OC_PASS=$(input_box_flow "Please type in the new password for the new Web Admin ($NEWUSER) in Nextcloud.")
        # Create new user
        export OC_PASS
        if su -s /bin/sh www-data -c "php $NCPATH/occ user:add $NEWUSER --password-from-env -g admin"
        then
            msg_box "The new Web Admin in Nextcloud is now: $NEWUSER\nThe password is set to: $OC_PASS
This is used when you login to Nextcloud itself, i.e. on the web."
            unset OC_PASS
            break
        else
            any_key "Press any key to choose a different password."
        fi
    done
    # Delete old user
    if [[ "$NCADMIN" ]]
    then
        print_text_in_color "$ICyan" "Deleting $NCADMIN..."
        nextcloud_occ user:delete "$NCADMIN"
        sleep 2
    fi
fi

# We need to unset the cached admin-user since we have changed its name
unset NC_ADMIN_USER

msg_box "Well done, you have now finished most of the setup.

There are still a few steps left but they are automated so sit back and relax! :)"

# Add default notifications
notify_admin_gui \
"Do you need support?" \
"If you need support, please visit the shop: https://shop.hanssonit.se, or the forum: https://help.nextcloud.com."

if ! is_this_installed php"$PHPVER"-imagick
then
    notify_admin_gui \
    "Regarding Imagick not being installed" \
    "As you may have noticed, Imagick is not installed. We care about your security, \
and here's the reason: https://github.com/nextcloud/server/issues/13099"
fi

# Fixes https://github.com/nextcloud/vm/issues/58
a2dismod status
restart_webserver

if home_sme_server
then
    install_if_not bc
    mem_available="$(awk '/MemTotal/{print $2}' /proc/meminfo)"
    mem_available_gb="$(echo "scale=0; $mem_available/(1024*1024)" | bc)"
    # 32 GB RAM
    if [[ 30 -lt "${mem_available_gb}" ]]
    then
        # Add specific values to PHP-FPM based on 32 GB RAM
        check_command sed -i "s|pm.max_children.*|pm.max_children = 600|g" "$PHP_POOL_DIR"/nextcloud.conf
        check_command sed -i "s|pm.start_servers.*|pm.start_servers = 100|g" "$PHP_POOL_DIR"/nextcloud.conf
        check_command sed -i "s|pm.min_spare_servers.*|pm.min_spare_servers = 20|g" "$PHP_POOL_DIR"/nextcloud.conf
        check_command sed -i "s|pm.max_spare_servers.*|pm.max_spare_servers = 480|g" "$PHP_POOL_DIR"/nextcloud.conf
        restart_webserver
    # 16 GB RAM
    elif [[ 14 -lt "${mem_available_gb}" ]]
    then
        # Add specific values to PHP-FPM based on 16 GB RAM
        check_command sed -i "s|pm.max_children.*|pm.max_children = 300|g" "$PHP_POOL_DIR"/nextcloud.conf
        check_command sed -i "s|pm.start_servers.*|pm.start_servers = 50|g" "$PHP_POOL_DIR"/nextcloud.conf
        check_command sed -i "s|pm.min_spare_servers.*|pm.min_spare_servers = 20|g" "$PHP_POOL_DIR"/nextcloud.conf
        check_command sed -i "s|pm.max_spare_servers.*|pm.max_spare_servers = 280|g" "$PHP_POOL_DIR"/nextcloud.conf
        restart_webserver
    fi
else
    # Calculate the values of PHP-FPM based on the amount of RAM available (minimum 2 GB or 8 children)
    calculate_php_fpm

    # Run again if values are reset on last run
    calculate_php_fpm
fi

# Set correct amount of CPUs for Imaginary
if does_this_docker_exist ghcr.io/nextcloud-releases/aio-imaginary
then
    if which nproc >/dev/null 2>&1
    then
        nextcloud_occ config:system:set preview_concurrency_new --value="$(nproc)"
        nextcloud_occ config:system:set preview_concurrency_all --value="$(($(nproc)*2))"
    else
        nextcloud_occ config:system:set preview_concurrency_new --value="2"
        nextcloud_occ config:system:set preview_concurrency_all --value="4"
    fi
fi

# Add temporary fix if needed
if network_ok
then
    run_script STATIC temporary-fix-end
fi

# Cleanup 1
nextcloud_occ maintenance:repair
rm -f "$SCRIPTS/ip.sh"
rm -f "$SCRIPTS/change_db_pass.sh"
rm -f "$SCRIPTS/instruction.sh"
rm -f "$NCDATA/nextcloud.log"
rm -f "$SCRIPTS/static_ip.sh"
rm -f "$SCRIPTS/lib.sh"
rm -f "$SCRIPTS/server_configuration.sh"
rm -f "$SCRIPTS/nextcloud_configuration.sh"
rm -f "$SCRIPTS/additional_apps.sh"
rm -f "$SCRIPTS/adduser.sh"
rm -f "$SCRIPTS/activate-tls.sh"
rm -f "$SCRIPTS/desec_menu.sh"
rm -f "$NCDATA"/*.log

find /root "/home/$UNIXUSER" -type f \( -name '*.sh*' -o -name '*.html*' -o -name '*.tar*' -o -name 'results' -o -name '*.zip*' \) -delete
sed -i "s|instruction.sh|nextcloud.sh|g" "/home/$UNIXUSER/.bash_profile"
# TODO: Do we really need this?
# https://github.com/nextcloud/server/issues/48773
# find "$NCPATH" -type f \( -name 'results' -o -name '*.sh*' \) -delete
find "$NCPATH" -type f \( -name 'results' \) -delete

truncate -s 0 \
    /root/.bash_history \
    "/home/$UNIXUSER/.bash_history" \
    /var/spool/mail/root \
    "/var/spool/mail/$UNIXUSER" \
    /var/log/apache2/access.log \
    /var/log/apache2/error.log \
    "$VMLOGS/nextcloud.log"

sed -i "s|sudo -i||g" "$UNIXUSER_PROFILE"

cat << ROOTNEWPROFILE > "$ROOT_PROFILE"
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

# Set trusted domains
run_script STATIC trusted_domains

# Upgrade system
print_text_in_color "$ICyan" "System will now upgrade..."
bash $SCRIPTS/update.sh minor

# Add missing indices (if any)
nextcloud_occ db:add-missing-indices

# Check if new major is out, and inform on how to update
nc_update
if version_gt "$NCMAJOR" "$CURRENTMAJOR"
then
    msg_box "We noticed that there's a new major release of Nextcloud ($NCVERSION).\nIf you want to update to the latest release instantly, please check this:\n
https://docs.hanssonit.se/s/W6fMouPiqQz3_Mog/virtual-machines-vm/d/W7Du9uPiqQz3_Mr1/nextcloud-vm-machine-configuration?currentPageId=W7D3quPiqQz3_MsE"
fi

# Repair
nextcloud_occ maintenance:repair --include-expensive

# Cleanup 2
apt-get autoremove -y
apt-get autoclean

# Success!
msg_box "The installation process is *almost* done.

Please hit OK in all the following prompts and let the server reboot to complete the installation process."

# Enterprise?
msg_box "ENTERPRISE?
Nextcloud Enterprise gives professional organizations software optimized and tested for mission critical environments.

More info here: https://nextcloud.com/enterprise/
Get your license here: https://shop.hanssonit.se/product/nextcloud-enterprise-license-100-users/"

msg_box "TIPS & TRICKS:
1. Publish your server online: http://shortio.hanssonit.se/ffOQOXS6Kh
2. To login to PostgreSQL just type: sudo -u postgres psql nextcloud_db
3. To update this server just type: sudo bash /var/scripts/update.sh
4. Install apps, configure Nextcloud, and server: sudo bash $SCRIPTS/menu.sh"

msg_box "SUPPORT:
Please ask for help in the forums, visit our shop to buy support:
- SUPPORT: https://shop.hanssonit.se/product/premium-support-per-30-minutes/
- FORUM: https://help.nextcloud.com/

BUGS:
Please report any bugs here: https://github.com/nextcloud/vm/issues"

msg_box "### PLEASE HIT OK TO REBOOT ###

Congratulations! You have successfully installed Nextcloud!

LOGIN:
Login to Nextcloud in your browser:
- IP: $ADDRESS
- Hostname: $(hostname -f)

### PLEASE HIT OK TO REBOOT ###"

# Reboot
print_text_in_color "$IGreen" "Installation done! Please hit OK to cleanup the setup files, and reboot the system."
check_command rm -f "$SCRIPTS/you-can-not-run-the-startup-script-several-times"
check_command rm -f "$SCRIPTS/nextcloud-startup-script.sh"
if ! reboot
then
    shutdown -r now
fi
