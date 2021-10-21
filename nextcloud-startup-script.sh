#!/bin/bash

# T&M Hansson IT AB © - 2021, https://www.hanssonit.se/

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

# shellcheck disable=2034,2059,1091
true
SCRIPT_NAME="Nextcloud Startup Script"
# shellcheck source=lib.sh
source /var/scripts/lib.sh

msg_box "Welcome to the first setup of your Nextcloud appliance!

This version of the VM is not the full version, it's meant for testing purposes only.
The installation will be local, without valid TLS or any advanced functions e.g: Collabora, Talk, or OnlyOffice.

If you rather want to get the full version VM with everything that's missing here, you can download it directly from our partner.

To download the full version, please visit:
https://www.hanssonit.se/nextcloud-vm/"

# Get all needed variables from the library
first_iface
ncdb

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
      dhcp4: true
      dhcp6: true
SETDHCP
    check_command netplan apply
    print_text_in_color "$ICyan" "Checking connection..."
    sleep 1
    set_systemd_resolved_dns "$IFACE"
fi

# Check network again
if network_ok
then
    print_text_in_color "$IGreen" "Online!"
else
    print_text_in_color "$IGreen" "Still offline, but no worries we can continue anyway!"
fi

# shellcheck disable=2034,2059,1091
true
SCRIPT_NAME="Nextcloud Startup Script"
# shellcheck source=lib.sh
source /var/scripts/lib.sh 

# Get all needed variables from the library
ncdb
nc_update

# Check that this run on the PostgreSQL VM
if ! is_this_installed postgresql-common
then
    print_text_in_color "$IRed" "This script is intended to be run using a PostgreSQL database, but PostgreSQL is not installed."
    print_text_in_color "$IRed" "Aborting..."
    exit 1
fi

# Nextcloud 18 is required
lowest_compatible_nc 18

# Run the startup menu
bash $SCRIPTS/startup_configuration.sh

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

# Change timezone in PHP
sed -i "s|;date.timezone.*|date.timezone = $(cat /etc/timezone)|g" "$PHP_INI"

# Change timezone for logging
nextcloud_occ config:system:set logtimezone --value="$(cat /etc/timezone)"

# Generate new SSH Keys
printf "\nGenerating new SSH keys for the server...\n"
rm -v /etc/ssh/ssh_host_*
dpkg-reconfigure openssh-server

# Generate new PostgreSQL password
print_text_in_color "$ICyan" "Generating new PostgreSQL password..."
check_command bash "$SCRIPTS/change_db_pass.sh"
sleep 3

# Set trusted domain
sudo bash $SCRIPTS/trusted.sh

### Change passwords
# CLI USER
msg_box "For better security, we will now change the password for the CLI user in Ubuntu."
UNIXUSER="$(getent group sudo | cut -d: -f4 | cut -d, -f1)"
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
    msg_box "The new password for the current CLI user in Ubuntu ($UNIXUSER) is now set to: $UNIX_PASSWORD\n\nThis is used when you login to the Ubuntu Server console."
fi
unset UNIX_PASSWORD
clear

# NEXTCLOUD USER
NCADMIN=$(nextcloud_occ user:list | awk '{print $3}')
msg_box "We will now change the username and password for the Web Admin in Nextcloud."
while :
do
    NEWUSER=$(input_box_flow "Please type in the name of the Web Admin in Nextcloud.\nIt must differ from the current one: $NCADMIN.\n\nThe only allowed characters for the username are:\n 'a-z', 'A-Z', '0-9', and '_.@-'")
    if [[ "$NEWUSER" == *" "* ]]
    then
        msg_box "Please don't use spaces."
    elif [ "$NEWUSER" = "$NCADMIN" ]
    then
        msg_box "This username ($NCADMIN) is already in use. Please choose a different one."
    # - has to be espacaped otherwise it won't work.
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
    if [[ "$OC_PASS" == *" "* ]]
    then
        msg_box "Please don't use spaces."
    fi
    # Create new user
    export OC_PASS
    if su -s /bin/sh www-data -c "php $NCPATH/occ user:add $NEWUSER --password-from-env -g admin"
    then
        msg_box "The new Web Admin in Nextcloud is now: $NEWUSER\nThe password is set to: $OC_PASS\n\nThis is used when you login to Nextcloud itself, i.e. on the web."
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
clear

# Check if user got internet once more, and then do the Nextcloud upgrade
msg_box "We will no try to upgrade Nextcloud to the latest version.
Please press OK to continue."
if network_ok
then
    # Do the upgrade
    chown -R www-data:www-data "$NCPATH"
    rm -rf "$NCPATH"/assets
    yes no | sudo -u www-data php /var/www/nextcloud/updater/updater.phar
    nextcloud_occ maintenance:mode --off
fi

# Cleanup 1
find /root "/home/$UNIXUSER" -type f \( -name '*.sh*' -o -name '*.html*' -o -name '*.tar*' -o -name 'results' -o -name '*.zip*' \) -delete
find "$NCPATH" -type f \( -name 'results' -o -name '*.sh*' \) -delete

cat << UNIXUSERNEWPROFILE > "$UNIXUSER_PROFILE"
# ~/.profile: executed by the command interpreter for login shells.
# This file is not read by bash(1), if ~/.bash_profile or ~/.bash_login
# exists.
# see /usr/share/doc/bash/examples/startup-files for examples.
# the files are located in the bash-doc package.
# the default umask is set in /etc/profile; for setting the umask
# for ssh logins, install and configure the libpam-umask package.
#umask 022
# if running bash
if [ -n "5.0.16(1)-release" ]
then
    # include .bashrc if it exists
    if [ -f "/root/.bashrc" ]
    then
        . "/root/.bashrc"
    fi
fi
# set PATH so it includes user's private bin if it exists
if [ -d "/root/bin" ]
then
    PATH="/root/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/snap/bin"
fi
bash $SCRIPTS/welcome.sh
UNIXUSERNEWPROFILE

cat << ROOTNEWPROFILE > "$ROOT_PROFILE"
# ~/.profile: executed by Bourne-compatible login shells.

if [ "/bin/bash" ]
then
    if [ -f ~/.bashrc ]
    then
        . ~/.bashrc
    fi
fi

mesg n

ROOTNEWPROFILE

truncate -s 0 \
    /root/.bash_history \
    "/home/$UNIXUSER/.bash_history" \
    /var/spool/mail/root \
    "/var/spool/mail/$UNIXUSER" \
    /var/log/apache2/access.log \
    /var/log/apache2/error.log \
    /var/log/cronjobs_success.log \
    "$VMLOGS/nextcloud.log"

# Cleanup 2
apt autoremove -y
apt autoclean
nextcloud_occ maintenance:repair
rm -f "$NCDATA/nextcloud.log"
rm -f $SCRIPTS/startup_configuration.sh
rm -f $SCRIPTS/trusted.sh
rm -f $SCRIPTS/history.sh
rm -f $SCRIPTS/locate_mirror.sh
rm -f $SCRIPTS/locales.sh
rm -f $SCRIPTS/change_db_pass.sh
rm -f $SCRIPTS/instruction.sh

# Success!
msg_box "Congratulations! You have successfully installed Nextcloud!

LOGIN:
Login to Nextcloud in your browser:
- IP: $ADDRESS
- Hostname: $(hostname -f)

## PLEASE PRESS OK TO REBOOT. ##"

# Prefer IPv6
sed -i "s|precedence ::ffff:0:0/96  100|#precedence ::ffff:0:0/96  100|g" /etc/gai.conf

# Reboot
print_text_in_color "$IGreen" "Installation done, system will now reboot..."
check_command rm -f "$SCRIPTS/nextcloud-startup-script.sh"
reboot
