#!/bin/bash

#################################################################################################################
# DO NOT USE THIS SCRIPT WHEN UPDATING NEXTCLOUD / YOUR SERVER! RUN `sudo bash /var/scripts/update.sh` INSTEAD. #
#################################################################################################################

# T&M Hansson IT AB © - 2024, https://www.hanssonit.se/
# GNU General Public License v3.0
# https://github.com/nextcloud/vm/blob/main/LICENSE

true
SCRIPT_NAME="Nextcloud Update Script"
# shellcheck source=lib.sh
source <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/main/lib.sh)

# Get all needed variables from the library
ncdb
nc_update

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/snap/bin

# Must be root
root_check

# Check if dpkg or apt is running
is_process_running apt
is_process_running dpkg

# Automatically restart services (Ubuntu 24.04)
if ! version 16.04.10 "$DISTRO" 22.04.10
then
    if [ ! -f /etc/needrestart/needrestart.conf ]
    then
        install_if_not needrestart
    fi
    if ! grep -rq "{restart} = 'a'" /etc/needrestart/needrestart.conf
    then
        # Restart mode: (l)ist only, (i)nteractive or (a)utomatically.
        sed -i "s|#\$nrconf{restart} =.*|\$nrconf{restart} = 'a'\;|g" /etc/needrestart/needrestart.conf
    fi
fi

# Check for pending-snapshot
if does_snapshot_exist "NcVM-snapshot-pending"
then
    msg_box "Cannot proceed with the update currently because NcVM-snapshot-pending exists.\n
It is possible that a backup is currently running or an update wasn't successful.\n
Advice: don't restart your system now if that is the case!\n
If you are sure that no update or backup is currently running, you can fix this by rebooting your server."
    # Kill all "$SCRIPTS/update.sh" processes to make sure that no automatic restart happens after exiting this script
    # shellcheck disable=2009
    PROCESS_IDS=$(ps aux | grep "$SCRIPTS/update.sh" | grep -v grep | awk '{print $2}')
    if [ -n "$PROCESS_IDS" ]
    then
        mapfile -t PROCESS_IDS <<< "$PROCESS_IDS"
        for process in "${PROCESS_IDS[@]}"
        do
            print_text_in_color "$ICyan" "Killing the process with PID $process to prevent a potential automatic restart..."
            if ! kill "$process"
            then
                print_text_in_color "$IRed" "Couldn't kill the process with PID $process..."
            fi
        done
    fi
    exit 1
fi

# Change from APCu to Redis for local cache
# https://github.com/nextcloud/vm/pull/2040
if pecl list | grep apcu >/dev/null 2>&1
then
    sed -i "/memcache.local/d" "$NCPATH"/config/config.php
    if pecl list | grep redis >/dev/null 2>&1
    then
        nextcloud_occ config:system:set memcache.local --value='\OC\Memcache\Redis'
    else
       nextcloud_occ config:system:delete memcache.local
    fi
fi

# Set product name
if home_sme_server
then
    PRODUCTNAME="Nextcloud HanssonIT Server"
else
    PRODUCTNAME="Nextcloud HanssonIT VM"
fi
if is_app_installed theming
then
    if [ "$(nextcloud_occ config:app:get theming productName)" != "$PRODUCTNAME" ]
    then
        nextcloud_occ config:app:set theming productName --value "$PRODUCTNAME"
    fi
fi

# Add aliases
if [ -f /root/.bash_aliases ]
then
    if ! grep -q "nextcloud" /root/.bash_aliases
    then
{
echo "alias nextcloud_occ='sudo -u www-data php /var/www/nextcloud/occ'"
echo "alias run_update_nextcloud='bash /var/scripts/update.sh'"
} >> /root/.bash_aliases
    fi
elif [ ! -f /root/.bash_aliases ]
then
{
echo "alias nextcloud_occ='sudo -u www-data php /var/www/nextcloud/occ'"
echo "alias run_update_nextcloud='bash /var/scripts/update.sh'"
} > /root/.bash_aliases
fi

# Inform about started update
notify_admin_gui \
"Update script started!" \
"The update script in the Nextcloud VM has been executed.
You will be notified when the update is done.
Please don't shutdown or restart your server until then."

# Create a snapshot before doing anything else
check_free_space
if ! [ -f "$SCRIPTS/nextcloud-startup-script.sh" ] && (does_snapshot_exist "NcVM-startup" \
|| does_snapshot_exist "NcVM-snapshot" || [ "$FREE_SPACE" -ge 50 ] )
then
    # Create backup first
    if [ -f "$SCRIPTS/daily-borg-backup.sh" ] && does_snapshot_exist "NcVM-snapshot"
    then
        rm -f /tmp/DAILY_BACKUP_CREATION_SUCCESSFUL
        export SKIP_DAILY_BACKUP_CHECK=1
        bash "$SCRIPTS/daily-borg-backup.sh"
        if ! [ -f "/tmp/DAILY_BACKUP_CREATION_SUCCESSFUL" ]
        then
            notify_admin_gui "Update failed because backup could not be created!" \
            "Could not create a backup! $(date +%T)"
            exit 1
        fi
    fi
    # Add automatical unlock upon reboot
    crontab -u root -l | grep -v "lvrename /dev/ubuntu-vg/NcVM-snapshot-pending"  | crontab -u root -
    crontab -u root -l | { cat; echo "@reboot /usr/sbin/lvrename /dev/ubuntu-vg/NcVM-snapshot-pending \
/dev/ubuntu-vg/NcVM-snapshot &>/dev/null" ; } | crontab -u root -
    SNAPSHOT_EXISTS=1
    if is_docker_running
    then
        check_command systemctl stop docker
    fi
    sudo -u www-data php "$NCPATH"/occ maintenance:mode --on
    if does_snapshot_exist "NcVM-startup"
    then
        check_command lvremove /dev/ubuntu-vg/NcVM-startup -y
    elif does_snapshot_exist "NcVM-snapshot"
    then
        if ! lvremove /dev/ubuntu-vg/NcVM-snapshot -y
        then
            sudo -u www-data php "$NCPATH"/occ maintenance:mode --off
            start_if_stopped docker
            notify_admin_gui "Update failed!" \
"Could not remove NcVM-snapshot - Please reboot your server! $(date +%T)"
            msg_box "It seems like the old snapshot could not get removed.
This should work again after a reboot of your server."
            exit 1
        fi
    fi
    if ! lvcreate --size 5G --snapshot --name "NcVM-snapshot" /dev/ubuntu-vg/ubuntu-lv
    then
        sudo -u www-data php "$NCPATH"/occ maintenance:mode --off
        start_if_stopped docker
        notify_admin_gui "Update failed!" \
"Could not create NcVM-snapshot - Please reboot your server! $(date +%T)"
        msg_box "The creation of a snapshot failed.
If you just merged and old one, please reboot your server again.
It should then start working again."
        exit 1
    fi
    if ! lvrename /dev/ubuntu-vg/NcVM-snapshot /dev/ubuntu-vg/NcVM-snapshot-pending
    then
        sudo -u www-data php "$NCPATH"/occ maintenance:mode --off
        start_if_stopped docker
        msg_box "Could not rename the snapshot before starting the update. Please reboot your system!"
        exit 1
    fi
    sudo -u www-data php "$NCPATH"/occ maintenance:mode --off
    start_if_stopped docker
fi

# Check if /boot is filled more than 90% and exit the script if that's
# the case since we don't want to end up with a broken system
if [ -d /boot ]
then
    if [[ "$(df -h | grep -m 1 /boot | awk '{print $5}' | cut -d "%" -f1)" -gt 90 ]]
    then
        msg_box "It seems like your boot drive is more than 90% full. \
You can't proceed to upgrade, as it would likely break your system.

To be able to proceed with the update you need to delete some old Linux kernels. If you need support, please visit:
https://shop.hanssonit.se/product/premium-support-per-30-minutes/"
        exit
    fi
fi

# Remove leftovers
rm -f /root/php-upgrade.sh
rm -f /tmp/php-upgrade.sh
rm -f /root/db-migration.sh
rm -f /root/migrate-between-psql-versions.sh
rm -f "$SCRIPTS"/php-upgrade.sh
rm -f "$SCRIPTS"/db-migration.sh
rm -f "$SCRIPTS"/migrate-between-psql-versions.sh

# Fix bug in nextcloud.sh
CURRUSR="$(getent group sudo | cut -d: -f4 | cut -d, -f1)"
if [ -f "$SCRIPTS/techandme.sh" ]
then
   rm -f "$SCRIPTS/techandme.sh"
   download_script STATIC nextcloud
   chown "$CURRUSR":"$CURRUSR" "$SCRIPTS/nextcloud.sh"
   chmod +x "$SCRIPTS/nextcloud.sh"
   if [ -f /home/"$CURRUSR"/.bash_profile ]
   then
       sed -i "s|techandme|nextcloud|g" /home/"$CURRUSR"/.bash_profile
   elif [ -f /home/"$CURRUSR"/.profile ]
   then
       sed -i "s|techandme|nextcloud|g" /home/"$CURRUSR"/.profile
   fi
else
    # Only update if it's older than 60 days (60 seconds * 60 minutes * 24 hours * 60 days)
    if [ -f "$SCRIPTS"/nextcloud.sh ]
    then
        if [ "$(stat --format=%Y "$SCRIPTS"/nextcloud.sh)" -le "$(( $(date +%s) - (60*60*24*60) ))" ]
        then
            download_script STATIC nextcloud
            chown "$CURRUSR":"$CURRUSR" "$SCRIPTS"/nextcloud.sh
        fi
    fi
fi

# Fix fancy progress bar for apt-get
# https://askubuntu.com/a/754653
if [ -d /etc/apt/apt.conf.d ]
then
    if ! [ -f /etc/apt/apt.conf.d/99progressbar ]
    then
        echo 'Dpkg::Progress-Fancy "1";' > /etc/apt/apt.conf.d/99progressbar
        echo 'APT::Color "1";' >> /etc/apt/apt.conf.d/99progressbar
        chmod 644 /etc/apt/apt.conf.d/99progressbar
    fi
fi

# Since the branch change, always get the latest update script
download_script STATIC update
chmod +x $SCRIPTS/update.sh

# Ubuntu 16.04 is deprecated
check_distro_version

# Hold PHP if Ondrejs PPA is used
print_text_in_color "$ICyan" "Fetching latest packages with apt..."
apt-get clean all
apt-get update -q4 & spinner_loading
if apt-cache policy | grep "ondrej" >/dev/null 2>&1
then
    print_text_in_color "$ICyan" "Ondrejs PPA is installed. \
Holding PHP to avoid upgrading to a newer version without migration..."
    apt-mark hold php* >/dev/null 2>&1
fi

# Don't allow MySQL/MariaDB
if [[ $NCDBTYPE = mysql ]]
then
    msg_box "MySQL/MariaDB is not supported in this script anymore. Please contact us to get support \
for upgrading your server: https://shop.hanssonit.se/product/premium-support-per-30-minutes/"
    exit 0
fi

# Check if the log DIR actually is a file
if [ -f /var/log/nextcloud ]
then
    rm -f /var/log/nextcloud
fi

# Set secure permissions
if [ ! -f "$SECURE" ]
then
    mkdir -p "$SCRIPTS"
    download_script STATIC setup_secure_permissions_nextcloud
    chmod +x "$SECURE"
else
    rm "$SECURE"
    download_script STATIC setup_secure_permissions_nextcloud
    chmod +x "$SECURE"
fi

# Remove the local lib.sh since it's causing issues with new functions (2020-06-01)
if [ -f "$SCRIPTS"/lib.sh ]
then
    rm -f "$SCRIPTS"/lib.sh
fi

# Make sure everyone gets access to menu.sh
download_script MENU menu

# Make sure fetch_lib.sh is available
download_script STATIC fetch_lib

# Update docker-ce to overlay2 since devicemapper is deprecated
if [ -f /etc/systemd/system/docker.service ]
then
    if grep -q "devicemapper" /etc/systemd/system/docker.service
    then
        print_text_in_color "$ICyan" "Changing to Overlay2 for Docker CE..."
        print_text_in_color "$ICyan" "Please report any issues to $ISSUES."
        run_script STATIC docker_overlay2
    elif grep -q "aufs" /etc/default/docker
    then
        apt-mark hold docker-ce
        run_script STATIC docker_overlay2
    fi
fi

if is_this_installed veracrypt
then
    # Hold veracrypt if installed since unmounting all drives, updating and mounting them again is not feasible
    # If you desperately need the update, you can do so manually
    apt-mark hold veracrypt
fi

# Enter maintenance:mode
print_text_in_color "$IGreen" "Enabling maintenance:mode..."
sudo -u www-data php "$NCPATH"/occ maintenance:mode --on

# Upgrade Talk repositrory if Talk is installed (2022-12-26)
if is_this_installed nextcloud-spreed-signaling
then
    print_text_in_color "$ICyan" "Upgrading dependencies for Talk..."
    apt-get update -q4 --allow-releaseinfo-change & spinner_loading
fi

# Upgrade OS dependencies
export DEBIAN_FRONTEND=noninteractive ; apt-get dist-upgrade -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"

# Temporary fix for PHP 2023-08-27
# There's a bug in PHP 8.1.21 which causes server to crash
# If you're on Ondrejs PPA, PHP isn't updated, so do that here instead
apt-mark unhold php* >/dev/null 2>&1
apt-get update -q4
export DEBIAN_FRONTEND=noninteractive ; apt-get upgrade -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"
apt-mark hold php* >/dev/null 2>&1

# Improve Apache for PHP-FPM
if is_this_installed php"$PHPVER"-fpm
then
    if [ -d "$PHP_FPM_DIR" ]
    then
        # Just make sure that MPM_EVENT is default
        a2dismod mpm_prefork
        a2enmod mpm_event
        restart_webserver
    fi
fi

# Fix Realtek on PN51
if asuspn51
then
    if ! version 24.04 "$DISTRO" 24.04.10
    then
        # Upgrade Realtek drivers
        print_text_in_color "$ICyan" "Upgrading Realtek firmware..."
        curl_to_dir https://raw.githubusercontent.com/nextcloud/vm/main/network/asusnuc pn51.sh "$SCRIPTS"
        bash "$SCRIPTS"/pn51.sh
    fi
fi

# Update Netdata
if [ -d /etc/netdata ]
then
    print_text_in_color "$ICyan" "Updating Netdata..."
    install_if_not cmake # Needed for Netdata in newer versions
    install_if_not libuv1-dev # Needed for Netdata in newer versions
    NETDATA_UPDATER_PATH="$(find /usr -name 'netdata-updater.sh')"
    if [ -n "$NETDATA_UPDATER_PATH" ]
    then
        bash "$NETDATA_UPDATER_PATH"
    else
        curl_to_dir https://raw.githubusercontent.com/netdata/netdata/main/packaging/installer/ netdata-updater.sh "$SCRIPTS"
        bash "$SCRIPTS"/netdata-updater.sh
        rm -f "$SCRIPTS"/netdata-updater.sh
    fi
fi

# Reinstall certbot (use snap instead of package)
# https://askubuntu.com/a/1271565
if dpkg -l | grep certbot >/dev/null 2>&1
then
    # certbot will be removed, but still listed, so we need to check if the snap is installed as well so that this doesn't run every time
    if ! snap list certbot >/dev/null 2>&1
    then
        print_text_in_color "$ICyan" "Reinstalling certbot (Let's Encrypt) as a snap instead..."
        apt-get remove certbot -y
        apt-get autoremove -y
        install_if_not snapd
        snap install core
        snap install certbot --classic
        # Update $PATH in current session (login and logout is required otherwise)
        check_command hash -r
    fi
fi

# Fix PHP error message
mkdir -p /tmp/pear/cache

# Just in case PECLs XML are bad
if ! pecl channel-update pecl.php.net
then
    curl_to_dir http://pecl.php.net channel.xml /tmp
    pear channel-update /tmp/channel.xml
    rm -f /tmp/channel.xml
fi

# Update Redis PHP extension (18.04 -->, since 16.04 already is deprecated in the top of this script)
print_text_in_color "$ICyan" "Trying to upgrade the Redis PECL extension..."

# Check current PHP version
check_php

# Do the upgrade
if pecl list | grep redis >/dev/null 2>&1
then
    if is_this_installed php"$PHPVER"-common
    then
        install_if_not php"$PHPVER"-dev
    fi

    yes no | pecl upgrade redis
    systemctl restart redis-server.service
fi
# Remove old redis
if grep -qFx extension=redis.so "$PHP_INI"
then
    sed -i "/extension=redis.so/d" "$PHP_INI"
fi
# Check if redis is enabled and create the file if not
if [ ! -f "$PHP_MODS_DIR"/redis.ini ]
then
    touch "$PHP_MODS_DIR"/redis.ini
fi
# Enable new redis
if ! grep -qFx extension=redis.so "$PHP_MODS_DIR"/redis.ini
then
    echo "# PECL redis" > "$PHP_MODS_DIR"/redis.ini
    echo "extension=redis.so" >> "$PHP_MODS_DIR"/redis.ini
    check_command phpenmod -v ALL redis
fi

# Remove APCu https://github.com/nextcloud/vm/issues/2039
if is_this_installed "php$PHPVER"-dev
then
    # Delete PECL APCu
    if pecl list | grep -q apcu
    then
        if ! yes no | pecl uninstall apcu
        then
            msg_box "APCu PHP module removal failed! Please report this to $ISSUES"
        else
            print_text_in_color "$IGreen" "APCu PHP module removal OK!"
        fi
        # Delete everything else
        check_command phpdismod -v ALL apcu
        rm -f "$PHP_MODS_DIR"/apcu.ini
        rm -f "$PHP_MODS_DIR"/apcu_bc.ini
        sed -i "/extension=apcu.so/d" "$PHP_INI"
        sed -i "/APCu/d" "$PHP_INI"
        sed -i "/apc./d" "$PHP_INI"
    fi
fi

# Also remove php-acpu if installed
if is_this_installed php-acpu
then
    apt-get purge php-apcu
    apt-get autoremove -y
fi
if is_this_installed php"$PHPVER"-apcu
then
    apt-get purge php"$PHPVER"-apcu
    apt-get autoremove -y
fi

# Upgrade other PECL dependencies
if [ "${CURRENTVERSION%%.*}" -ge "17" ]
then
    if [ -f "$PHP_INI" ]
    then
        print_text_in_color "$ICyan" "Trying to upgrade igbinary, and smbclient..."
        if pecl list | grep igbinary >/dev/null 2>&1
        then
            yes no | pecl upgrade igbinary
            # Remove old igbinary
            if grep -qFx extension=igbinary.so "$PHP_INI"
            then
                sed -i "/extension=igbinary.so/d" "$PHP_INI"
            fi
            # Check if igbinary is enabled and create the file if not
            if [ ! -f "$PHP_MODS_DIR"/igbinary.ini ]
            then
                touch "$PHP_MODS_DIR"/igbinary.ini
            fi
            # Enable new igbinary
            if ! grep -qFx extension=igbinary.so "$PHP_MODS_DIR"/igbinary.ini
            then
                echo "# PECL igbinary" > "$PHP_MODS_DIR"/igbinary.ini
                echo "extension=igbinary.so" >> "$PHP_MODS_DIR"/igbinary.ini
                check_command phpenmod -v ALL igbinary
            fi
        fi
        if pecl list | grep -q smbclient
        then
            yes no | pecl upgrade smbclient
            # Check if smbclient is enabled and create the file if not
            if [ ! -f "$PHP_MODS_DIR"/smbclient.ini ]
            then
               touch "$PHP_MODS_DIR"/smbclient.ini
            fi
            # Enable new smbclient
            if ! grep -qFx extension=smbclient.so "$PHP_MODS_DIR"/smbclient.ini
            then
                echo "# PECL smbclient" > "$PHP_MODS_DIR"/smbclient.ini
                echo "extension=smbclient.so" >> "$PHP_MODS_DIR"/smbclient.ini
                check_command phpenmod -v ALL smbclient
            fi
            # Remove old smbclient
            if grep -qFx extension=smbclient.so "$PHP_INI"
            then
                sed -i "/extension=smbclient.so/d" "$PHP_INI"
            fi
        fi
        if pecl list | grep -q inotify
        then
            # Remove old inotify
            if grep -qFx extension=inotify.so "$PHP_INI"
            then
                sed -i "/extension=inotify.so/d" "$PHP_INI"
            fi
            yes no | pecl upgrade inotify
            if [ ! -f "$PHP_MODS_DIR"/inotify.ini ]
            then
                touch "$PHP_MODS_DIR"/inotify.ini
            fi
            if ! grep -qFx extension=inotify.so "$PHP_MODS_DIR"/inotify.ini
            then
                echo "# PECL inotify" > "$PHP_MODS_DIR"/inotify.ini
                echo "extension=inotify.so" >> "$PHP_MODS_DIR"/inotify.ini
                check_command phpenmod -v ALL inotify
            fi
        fi
    fi
fi

# Make sure services are restarted
restart_webserver

# Update adminer
if [ -d "$ADMINERDIR" ]
then
    print_text_in_color "$ICyan" "Updating Adminer..."
    rm -f "$ADMINERDIR"/latest.php "$ADMINERDIR"/adminer.php "$ADMINERDIR"/adminer-pgsql.php
    # Download the latest version
    curl_to_dir "https://download.adminerevo.org/latest/adminer" "adminer-pgsql.zip" "$ADMINERDIR"
    install_if_not unzip
    # Unzip the latest version
    unzip "$ADMINERDIR"/adminer-pgsql.zip -d "$ADMINERDIR"
    rm -f "$ADMINERDIR"/adminer-pgsql.zip
    mv "$ADMINERDIR"/adminer-pgsql.php "$ADMINERDIR"/adminer.php
fi

# Get latest Maxmind databse for Geoblock
if grep -q "^#Geoip-block" /etc/apache2/apache2.conf
then
    if grep -c GeoIPDBFile /etc/apache2/apache2.conf
    then
        msg_box "We have updated GeoBlock to a new version which isn't compatible with the old one. Please reinstall with the menu script to get the latest version."
        notify_admin_gui \
"GeoBlock needs to be reinstalled!" \
"We have updated GeoBlock to a new version which isn't compatible with the old one.
Please reinstall with the menu script to get the latest version.

sudo bash /ar/scripts/menu.sh --> Server Configuration --> GeoBlock"
    fi
elif [ -f "$GEOBLOCK_MOD" ]
then
    if download_geoip_mmdb
    then
        print_text_in_color "$IGreen" "GeoBlock database updated!"
    fi
fi

# Update docker containers and remove Watchtower if Bitwarden is present due to compatibility issue
# If Watchtower is installed, but Bitwarden is missing, then let watchtower do its thing
# If Watchtower is installed together with Bitwarden, then remove Watchtower and run updates
# individually depending on which docker containers that exist.
if is_docker_running
then
    # Fix Docker compose issue
    if is_this_installed docker-compose
    then
        apt purge docker-compose -y
        install_if_not docker-compose-plugin
    fi
    # To fix https://github.com/nextcloud/vm/issues/1459 we need to remove Watchtower
    # to avoid updating Bitwarden again, and only update the specified docker images above
    if docker ps -a --format '{{.Names}}' | grep -Eq "bitwarden";
    then
        if [ -d /root/bwdata ] || [ -d "$BITWARDEN_HOME"/bwdata ]
        then
            if does_this_docker_exist 'containrrr/watchtower'
            then
                docker stop watchtower
                WATCHTOWER=1
            elif does_this_docker_exist 'v2tec/watchtower'
            then
                docker stop watchtower
                WATCHTOWER=1
            fi
            docker container prune -f
            docker image prune -a -f
            docker volume prune -f
            if [ -n "$WATCHTOWER" ]
            then
                notify_admin_gui "Watchtower removed" "Due to compatibility issues with Bitwarden and Watchtower, \
we have removed Watchtower from this server. Updates will now happen for each container separately."
            fi
        fi
    fi
    # Update selected images
    # Vaultwarden
    docker_update_specific 'vaultwarden' "Vaultwarden"
    # Bitwarden RS
    if is_docker_running && docker ps -a --format '{{.Image}}' | grep -Eq "bitwardenrs/server:latest";
    then
        print_text_in_color "$ICyan" "Updating Bitwarden RS. This can take a while..."
        docker pull assaflavie/runlike &>/dev/null
        echo '#/bin/bash' > /tmp/bitwarden-conf
        chmod 700 /tmp/bitwarden-conf
        docker run --rm -v /var/run/docker.sock:/var/run/docker.sock assaflavie/runlike -p bitwarden_rs >> /tmp/bitwarden-conf
        sed -i 's|bitwardenrs/server:latest|vaultwarden/server:latest|' /tmp/bitwarden-conf
        docker stop bitwarden_rs
        docker rm bitwarden_rs
        if ! DOCKER_RUN_OUTPUT=$(bash /tmp/bitwarden-conf 2>&1)
        then
            check_command cp /tmp/bitwarden-conf "$SCRIPTS"
            chmod 700 "$SCRIPTS/bitwarden-conf"
            notify_admin_gui "Could not update Bitwarden RS." "Please recreate the docker container yourself.
You can find its config here: $SCRIPTS/bitwarden-conf
See the debug log below:
$DOCKER_RUN_OUTPUT"
            msg_box "Could not update Bitwarden RS. Please recreate the docker container yourself.
You can find its config here: $SCRIPTS/bitwarden-conf
See the debug log below:
$DOCKER_RUN_OUTPUT"
        else
            docker image prune -a -f
        fi
        rm -f /tmp/bitwarden-conf
    else
        docker_update_specific 'bitwarden_rs' "Bitwarden RS"
    fi
    # Collabora CODE
    docker_update_specific 'code' 'Collabora'
    # OnlyOffice
    ## Don't upgrade to community if EE is installed
    if ! does_this_docker_exist onlyoffice-ee
    then
        if does_this_docker_exist 'onlyoffice/documentserver'
        then
            docker_update_specific 'onlyoffice' 'OnlyOffice'
        fi
    fi
    # Full Text Search
    if [ "${CURRENTVERSION%%.*}" -ge "25" ]
    then
        fulltextsearch_install
        if does_this_docker_exist "$nc_fts" && does_this_docker_exist "$opens_fts"
        then
            msg_box "Please consider reinstalling FullTextSearch since you seem to have the old (and not working) implemantation by issuing the uninstall script: sudo bash $SCRIPTS/menu.sh --> Additional Apps --> FullTextSearch"
        elif [ -d "$FULLTEXTSEARCH_DIR" ]
        then
            # Check if new name standard is set, and only update if it is (since it contains the latest tag)
            if grep -rq "$FULLTEXTSEARCH_IMAGE_NAME" "$FULLTEXTSEARCH_DIR/docker-compose.yaml"
            then
                if [ -n "$FULLTEXTSEARCH_IMAGE_NAME_LATEST_TAG" ]
                then
                    sed -i "s|image: docker.elastic.co/elasticsearch/elasticsearch:.*|image: docker.elastic.co/elasticsearch/elasticsearch:$FULLTEXTSEARCH_IMAGE_NAME_LATEST_TAG|g" "$FULLTEXTSEARCH_DIR/docker-compose.yaml"
                    docker-compose_update "$FULLTEXTSEARCH_IMAGE_NAME" 'Full Text Search' "$FULLTEXTSEARCH_DIR"
                fi
            else
                print_text_in_color "$ICyan" "Full Text Search is version based, to upgrade it, please change the version in $FULLTEXTSEARCH_DIR and run 'docker compose pull && docker compose up -d'. Latest tags are here: https://www.docker.elastic.co/r/elasticsearch and release notes here: https://www.elastic.co/guide/en/elasticsearch/reference/current/release-highlights.html"
            fi
        fi
    fi
    # Talk Recording
    docker_update_specific 'talk-recording' "Talk Recording"
    # Plex
    docker_update_specific 'plex' "Plex Media Server"
    # Imaginary
    docker_update_specific 'imaginary' "Imaginary"
fi

# Fix Collabora change too coolwsd
if grep -r loolwsd "$SITES_AVAILABLE"/*.conf
then
    print_text_in_color "$ICyan" "Updating Collabora Engine..."
    LOOLWSDCONF=$(grep -r loolwsd "$SITES_AVAILABLE"/*.conf | awk '{print $1}' | cut -d ":" -f1)
    mapfile -t LOOLWSDCONF <<< "$LOOLWSDCONF"
    for apacheconf in "${LOOLWSDCONF[@]}"
    do
        sed -i "s|/loleaflet|/browser|g" "${apacheconf}"
        sed -i "s|loleaflet is the|browser is the|g" "${apacheconf}"
        sed -i "s|loolwsd|coolwsd|g" "${apacheconf}"
        sed -i "s|/lool|/cool|g" "${apacheconf}"
    done
    check_command restart_webserver
fi

# Cleanup un-used packages
apt-get autoremove -y
apt-get autoclean

# Update GRUB, just in case
update-grub

# Free some space (ZFS snapshots)
if is_this_installed libzfs4linux
then
    if grep -rq ncdata /etc/mtab
    then
        run_script DISK prune_zfs_snaphots
    fi
fi

# Update updatenotification.sh (gets updated after each nextcloud update as well; see down below the script)
if [ -f "$SCRIPTS"/updatenotification.sh ] && ! grep -q "Check for supported Nextcloud version" "$SCRIPTS/updatenotification.sh"
then
    download_script STATIC updatenotification
    chmod +x "$SCRIPTS"/updatenotification.sh
fi

# Disable maintenance:mode
print_text_in_color "$IGreen" "Disabling maintenance:mode..."
sudo -u www-data php "$NCPATH"/occ maintenance:mode --off

# Make all previous files executable
print_text_in_color "$ICyan" "Finding all executable files in $NC_APPS_PATH"
find_executables="$(find $NC_APPS_PATH -type f -executable)"

# Update all Nextcloud apps
if [ "${CURRENTVERSION%%.*}" -ge "15" ]
then
    # Check for upgrades
    print_text_in_color "$ICyan" "Trying to automatically update all Nextcloud apps..."
    UPDATED_APPS="$(nextcloud_occ_no_check app:update --all)"
    # Update pdfannotate
    if [ -d "$NC_APPS_PATH/pdfannotate" ]
    then
        INFO_XML="$(curl -s https://gitlab.com/nextcloud-other/nextcloud-annotate/-/raw/master/appinfo/info.xml)"
        if [ "$(echo "$INFO_XML" | grep -oP 'min-version="[0-9]+"' | grep -oP '[0-9]+')" -le "${CURRENTVERSION%%.*}" ] \
&& [ "$(echo "$INFO_XML" | grep -oP 'max-version="[0-9]+"' | grep -oP '[0-9]+')" -ge "${CURRENTVERSION%%.*}" ]
        then
            print_text_in_color "$ICyan" "Updating the pdfannotate app..."
            cd "$NC_APPS_PATH/pdfannotate"
            git pull
            chown -R www-data:www-data ./
            chmod -R 770 ./
        fi
    fi
fi

# Check which apps got updated
if [ -n "$UPDATED_APPS" ]
then
    print_text_in_color "$IGreen" "$UPDATED_APPS"
    notify_admin_gui \
    "Your apps just got updated!" \
    "$UPDATED_APPS"
    # Just make sure everything is updated (sometimes app requires occ upgrade to be run)
    nextcloud_occ upgrade
else
    print_text_in_color "$IGreen" "Your apps are already up to date!"
fi

# Apply correct redirect rule to avoid security check errors
REDIRECTRULE="$(grep -r "\[R=301,L\]" $SITES_AVAILABLE | cut -d ":" -f1)"
if [ -n "$REDIRECTRULE" ]
then
    # Change the redirect rule in all files in Apache available
    mapfile -t REDIRECTRULE <<< "$REDIRECTRULE"
    for rule in "${REDIRECTRULE[@]}"
    do
        sed -i "s|{HTTP_HOST} \[R=301,L\]|{HTTP_HOST}\$1 \[END,NE,R=permanent\]|g" "$rule"
    done
    # Restart Apache
    if check_command apachectl configtest
    then
        restart_webserver
    fi
fi

# Nextcloud 13 is required.
lowest_compatible_nc 13

# Restart notify push if existing
if [ -f "$NOTIFY_PUSH_SERVICE_PATH" ]
then
    chmod +x "$NC_APPS_PATH"/notify_push/bin/x86_64/notify_push
    systemctl restart notify_push.service
fi

if [ -f /tmp/minor.version ]
then
    NCBAD=$(cat /tmp/minor.version)
    NCVERSION=$(curl -s -m 900 "$NCREPO"/ | sed --silent 's/.*href="nextcloud-\([^"]\+\).zip.asc".*/\1/p' | sort --version-sort | grep "${CURRENTVERSION%%.*}" | tail -1)
    export NCVERSION
    export STABLEVERSION="nextcloud-$NCVERSION"
    rm -f /tmp/minor.version
elif [ -f /tmp/nextmajor.version ]
then
    NCBAD=$(cat /tmp/nextmajor.version)
    if [ "$NCNEXT" -lt "15" ]
    then
        NCVERSION=$(curl -s -m 900 "$NCREPO"/ | sed --silent 's/.*href="nextcloud-\([^"]\+\).zip.asc".*/\1/p' | sort --version-sort | grep "$NCNEXT" | head -1)
    else
        NCVERSION=$(curl -s -m 900 "$NCREPO"/ | sed --silent 's/.*href="nextcloud-\([^"]\+\).zip.asc".*/\1/p' | sort --version-sort | grep "$NCNEXT" | tail -1)
    fi
    if [ -z "$NCVERSION" ]
    then
        msg_box "The version that you are trying to upgrade to doesn't exist."
        exit 1
    fi
    export NCVERSION
    export STABLEVERSION="nextcloud-$NCVERSION"
    rm -f /tmp/nextmajor.version
elif [ -f /tmp/prerelease.version ]
then
    PRERELEASE_VERSION=yes
    msg_box "WARNING! You are about to update to a Beta/RC version of Nextcloud.\nThere's no turning back, \
as it's not currently possible to downgrade.\n\nPlease only continue if you have made a backup, or took a snapshot."
    if ! yesno_box_no "Are you sure you would like to proceed?"
    then
        rm -f /tmp/prerelease.version
        unset PRERELEASE_VERSION
    else
        if grep -q beta /tmp/prerelease.version
        then
            NCREPO="https://download.nextcloud.com/server/prereleases"
            NCVERSION=$(curl -s -m 900 $NCREPO/ | sed --silent 's/.*href="nextcloud-\([^"]\+\).zip.asc".*/\1/p' | sort --version-sort | tail -1)
            STABLEVERSION="nextcloud-$NCVERSION"
            rm -f /tmp/prerelease.version
        elif grep -q "rc" /tmp/prerelease.version
        then
            NCREPO="https://download.nextcloud.com/server/prereleases"
            NCVERSION=$(cat /tmp/prerelease.version)
            STABLEVERSION="nextcloud-$NCVERSION"
            rm -f /tmp/prerelease.version
        fi
    fi
fi

# Rename snapshot
if [ -n "$SNAPSHOT_EXISTS" ]
then
    check_command lvrename /dev/ubuntu-vg/NcVM-snapshot-pending /dev/ubuntu-vg/NcVM-snapshot
fi

# We can't jump between major versions
major_versions_unsupported

# Check if new version is larger than current version installed. Skip version check if you want to upgrade to a prerelease.
if [ -z "$PRERELEASE_VERSION" ]
then
    print_text_in_color "$ICyan" "Checking for new Nextcloud version..."
    if version_gt "$NCVERSION" "$CURRENTVERSION"
    then
        print_text_in_color "$ICyan" "Latest release is: $NCVERSION. Current version is: $CURRENTVERSION."
        print_text_in_color "$IGreen" "New version available, upgrade continues!"
    else
        print_text_in_color "$IGreen" "You already run the latest version! ($CURRENTVERSION)"
        notify_admin_gui \
        "Update successful!" \
        "The update script finished successfully! No new Nextcloud update was found."
        exit 0
    fi
fi

# Update updatenotification.sh
if [ -f "$SCRIPTS"/updatenotification.sh ]
then
    download_script STATIC updatenotification
    chmod +x "$SCRIPTS"/updatenotification.sh
    crontab -u root -l | grep -v "$SCRIPTS/updatenotification.sh" | crontab -u root -
    crontab -u root -l | { cat; echo "59 $AUT_UPDATES_TIME * * * $SCRIPTS/updatenotification.sh > /dev/null 2>&1"; } | crontab -u root -
fi

############# Don't upgrade to specific version
DONOTUPDATETO='29.0.0'
if [[ "$NCVERSION" == "$DONOTUPDATETO" ]]
then
    msg_box "Due to major bugs with Nextcloud $DONOTUPDATETO we won't upgrade to that version since it's a risk it will break your server. Please try to upgrade again when the next maintenance release is out."
    exit
fi

# Check if PHP version is compatible with $NCVERSION
PHP_VER=71
NC_VER=16
if [ "${NCVERSION%%.*}" -ge "$NC_VER" ]
then
    if [ "$(php -v | head -n 1 | cut -d " " -f 2 | cut -c 1,3)" -lt "$PHP_VER" ]
    then
        msg_box "Your PHP version isn't compatible with the new version of Nextcloud. Please upgrade your PHP stack and try again.

If you need support, please visit https://shop.hanssonit.se/product/upgrade-php-version-including-dependencies/"
        exit
    fi
fi

# Check if PHP version is compatible with $NCVERSION
PHP_VER=72
NC_VER=20
if [ "${NCVERSION%%.*}" -ge "$NC_VER" ]
then
    if [ "$(php -v | head -n 1 | cut -d " " -f 2 | cut -c 1,3)" -lt "$PHP_VER" ]
    then
        msg_box "Your PHP version isn't compatible with the new version of Nextcloud. Please upgrade your PHP stack and try again.

If you need support, please visit https://shop.hanssonit.se/product/upgrade-php-version-including-dependencies/"
        exit
    fi
fi

# Check if PHP version is compatible with $NCVERSION
PHP_VER=73
NC_VER=21
if [ "${NCVERSION%%.*}" -ge "$NC_VER" ]
then
    if [ "$(php -v | head -n 1 | cut -d " " -f 2 | cut -c 1,3)" -lt "$PHP_VER" ]
    then
msg_box "Your PHP version isn't compatible with the new version of Nextcloud. Please upgrade your PHP stack and try again.

If you need support, please visit https://shop.hanssonit.se/product/upgrade-php-version-including-dependencies/"
        exit
    fi
fi

# Check if PHP version is compatible with $NCVERSION
# https://github.com/nextcloud/server/issues/29258
PHP_VER=74
NC_VER=24
if [ "${NCVERSION%%.*}" -ge "$NC_VER" ]
then
    if [ "$(php -v | head -n 1 | cut -d " " -f 2 | cut -c 1,3)" -lt "$PHP_VER" ]
    then
msg_box "Your PHP version isn't compatible with the new version of Nextcloud. Please upgrade your PHP stack and try again.

If you need support, please visit https://shop.hanssonit.se/product/upgrade-php-version-including-dependencies/"
        exit
    fi
fi

# Check if PHP version is compatible with $NCVERSION
# https://github.com/nextcloud/server/issues/29258
PHP_VER=80
NC_VER=26
if [ "${NCVERSION%%.*}" -ge "$NC_VER" ]
then
    if [ "$(php -v | head -n 1 | cut -d " " -f 2 | cut -c 1,3)" -lt "$PHP_VER" ]
    then
msg_box "Your PHP version isn't compatible with the new version of Nextcloud. Please upgrade your PHP stack and try again.

If you need support, please visit https://shop.hanssonit.se/product/upgrade-php-version-including-dependencies/"
        exit
    fi
fi

# Check if PHP version is compatible with $NCVERSION
# https://github.com/nextcloud/server/issues/29258
PHP_VER=81
NC_VER=31
if [ "${NCVERSION%%.*}" -ge "$NC_VER" ]
then
    if [ "$(php -v | head -n 1 | cut -d " " -f 2 | cut -c 1,3)" -lt "$PHP_VER" ]
    then
msg_box "Your PHP version isn't compatible with the new version of Nextcloud. Please upgrade your PHP stack and try again.

If you need support, please visit https://shop.hanssonit.se/product/upgrade-php-version-including-dependencies/"
        exit
    fi
fi

# Check if PHP version is compatible with $NCVERSION
# https://github.com/nextcloud/server/issues/29258
PHP_VER=82
NC_VER=32
if [ "${NCVERSION%%.*}" -ge "$NC_VER" ]
then
    if [ "$(php -v | head -n 1 | cut -d " " -f 2 | cut -c 1,3)" -lt "$PHP_VER" ]
    then
msg_box "Your PHP version isn't compatible with the new version of Nextcloud. Please upgrade your PHP stack and try again.

If you need support, please visit https://shop.hanssonit.se/product/upgrade-php-version-including-dependencies/"
        exit
    fi
fi

# Upgrade Nextcloud
if ! site_200 "$NCREPO"
then
    msg_box "$NCREPO seems to be down, or temporarily not reachable. Please try again in a few minutes."
    exit 1
fi

countdown "Backing up files and upgrading to Nextcloud $NCVERSION in 10 seconds... Press CTRL+C to abort." "10"

# Rename snapshot
if [ -n "$SNAPSHOT_EXISTS" ]
then
    check_command lvrename /dev/ubuntu-vg/NcVM-snapshot /dev/ubuntu-vg/NcVM-snapshot-pending
fi

# Stop Apache2
print_text_in_color "$ICyan" "Stopping Apache2..."
check_command systemctl stop apache2.service

# Create backup dir (/mnt/NCBACKUP/)
if [ ! -d "$BACKUP" ]
then
    mkdir -p "$BACKUP"
fi

# Backup PostgreSQL
if is_this_installed postgresql-common
then
    cd /tmp
    # Test connection to PostgreSQL
    if ! sudo -u postgres psql -w -c "\q"
    then
        # If it fails, trust the 'postgres' user to be able to perform backup
        rsync -a /etc/postgresql/*/main/pg_hba.conf "$BACKUP"/pg_hba.conf_BACKUP
        sed -i "s|local   all             postgres                                .*|local   all             postgres                                trust|g" /etc/postgresql/*/main/pg_hba.conf
        systemctl restart postgresql.service
        if sudo -u postgres psql -c "SELECT 1 AS result FROM pg_database WHERE datname='$NCDB'" | grep "1 row" > /dev/null
        then
            print_text_in_color "$ICyan" "Doing pgdump of $NCDB..."
            check_command sudo -u postgres pg_dump -Fc "$NCDB"  > "$BACKUP"/nextclouddb.dump
            # Import:
            # sudo -u postgres pg_restore --verbose --clean --no-acl --no-owner -h localhost -U ncadmin -d nextcloud_db "$BACKUP"/nextclouddb.dump
        else
            print_text_in_color "$ICyan" "Doing pgdump of all databases..."
            check_command sudo -u postgres pg_dumpall > "$BACKUP"/alldatabases.dump
        fi
    else
        # If there's no issues, then continue as normal
        if sudo -u postgres psql -c "SELECT 1 AS result FROM pg_database WHERE datname='$NCDB'" | grep "1 row" > /dev/null
        then
            print_text_in_color "$ICyan" "Doing pgdump of $NCDB..."
            check_command sudo -u postgres pg_dump -Fc "$NCDB"  > "$BACKUP"/nextclouddb.dump
            # Import:
            # sudo -u postgres pg_restore --verbose --clean --no-acl --no-owner -h localhost -U ncadmin -d nextcloud_db "$BACKUP"/nextclouddb.dump
        else
            print_text_in_color "$ICyan" "Doing pgdump of all databases..."
            check_command sudo -u postgres pg_dumpall > "$BACKUP"/alldatabases.dump
        fi
    fi
fi

# Prevent apps from breaking the update due to incompatibility
# Fixes errors like https://github.com/nextcloud/vm/issues/1834
# Needs to be executed before backing up the config directory
if [ "${CURRENTVERSION%%.*}" -lt "${NCVERSION%%.*}" ]
then
    print_text_in_color "$ICyan" "Deleting 'app_install_overwrite array' to prevent app breakage..."
    nextcloud_occ config:system:delete app_install_overwrite
fi

# Move backups to location according to $VAR
if [ -d /var/NCBACKUP/ ]
then
    mv /var/NCBACKUP "$BACKUP"
    mv /var/NCBACKUP-OLD "$BACKUP"-OLD/
fi

# Check if backup exists and move to old
print_text_in_color "$ICyan" "Backing up data..."
if [ -d "$BACKUP" ]
then
    install_if_not rsync
    mkdir -p "$BACKUP"-OLD/"$(date +%Y-%m-%d-%H%M%S)"
    rsync -Aaxz "$BACKUP"/* "$BACKUP"-OLD/"$(date +%Y-%m-%d-%H%M%S)"
    rm -rf "$BACKUP"-OLD/"$(date --date='1 year ago' +%Y)"*
    rm -rf "$BACKUP"
    mkdir -p "$BACKUP"
fi

# Do a backup of the ZFS mount
if is_this_installed zfs-auto-snapshot
then
    if grep -rq ncdata /etc/mtab
    then
        check_multiverse
        sed -i "s|date --utc|date|g" /usr/sbin/zfs-auto-snapshot
        check_command zfs-auto-snapshot -r ncdata
    fi
fi

# Backup data
for folders in config apps
do
    if [[ "$(rsync -Aaxz "$NCPATH"/$folders "$BACKUP")" -eq 0 ]]
    then
        BACKUP_OK=1
    else
        unset BACKUP_OK
    fi
done

if [ -z "$BACKUP_OK" ]
then
    msg_box "Backup was not OK. Please check $BACKUP and see if the folders are backed up properly"
    exit 1
else
    print_text_in_color "$IGreen" "Backup OK!"
fi

# Download and validate Nextcloud package
check_command download_verify_nextcloud_stable

if [ -f "$HTML/$STABLEVERSION.tar.bz2" ]
then
    print_text_in_color "$ICyan" "$HTML/$STABLEVERSION.tar.bz2 exists"
else
    msg_box "Aborting, something went wrong with the download"
    exit 1
fi

if [ -d "$BACKUP"/config/ ]
then
    print_text_in_color "$ICyan" "$BACKUP/config/ exists"
else
    msg_box "Something went wrong with backing up your old Nextcloud instance
Please check in $BACKUP if config/ folder exist."
    exit 1
fi

if [ -d "$BACKUP"/apps/ ]
then
    print_text_in_color "$ICyan" "$BACKUP/apps/ exists"
    echo
    print_text_in_color "$IGreen" "All files are backed up."
    send_mail \
    "New Nextcloud version found!" \
    "We will now start the update to Nextcloud $NCVERSION. $(date +%T)"
    countdown "Removing old Nextcloud instance in 5 seconds..." "5"
    rm -rf "$NCPATH"
    print_text_in_color "$IGreen" "Extracting new package...."
    check_command tar -xjf "$HTML/$STABLEVERSION.tar.bz2" -C "$HTML"
    rm "$HTML/$STABLEVERSION.tar.bz2"
    print_text_in_color "$IGreen" "Restoring config to Nextcloud..."
    rsync -Aaxz "$BACKUP"/config "$NCPATH"/
    bash "$SECURE" & spinner_loading
    # Don't execute the update before all cronjobs are finished
    check_running_cronjobs
    # Execute the update
    nextcloud_occ upgrade
    # Optimize
    print_text_in_color "$ICyan" "Optimizing Nextcloud..."
    yes | nextcloud_occ db:convert-filecache-bigint
    nextcloud_occ db:add-missing-indices
    CURRENTVERSION=$(sudo -u www-data php "$NCPATH"/occ status | grep "versionstring" | awk '{print $3}')
    if [ "${CURRENTVERSION%%.*}" -ge "19" ]
    then
        check_php
        nextcloud_occ db:add-missing-columns
        install_if_not php"$PHPVER"-bcmath
    fi
    if [ "${CURRENTVERSION%%.*}" -ge "20" ]
    then
        nextcloud_occ db:add-missing-primary-keys
    fi
    if [ "${CURRENTVERSION%%.*}" -ge "21" ]
    then
        # Set phone region
        if [ -n "$KEYBOARD_LAYOUT" ]
        then
            nextcloud_occ config:system:set default_phone_region --value="$KEYBOARD_LAYOUT"
        fi
    fi
    if [ "${CURRENTVERSION%%.*}" -ge "23" ]
    then
        # Update opcache.interned_strings_buffer
        if ! grep -rq opcache.interned_strings_buffer="$opcache_interned_strings_buffer_value" "$PHP_INI"
        then
            sed -i "s|opcache.interned_strings_buffer=.*|opcache.interned_strings_buffer=$opcache_interned_strings_buffer_value|g" "$PHP_INI"
            restart_webserver
        fi
    fi
    if [ "${CURRENTVERSION%%.*}" -ge "27" ]
    then
        nextcloud_occ dav:sync-system-addressbook
    fi
else
    msg_box "Something went wrong with backing up your old Nextcloud instance
Please check in $BACKUP if the folders exist."
    exit 1
fi

# Repair
nextcloud_occ maintenance:repair --include-expensive

# Update Bitwarden
if is_docker_running
then
    if docker ps -a --format '{{.Names}}' | grep -Eq "bitwarden";
    then
        if is_this_installed apache2
        then
            if [ -d /root/bwdata ]
            then
                curl_to_dir "https://raw.githubusercontent.com/bitwarden/server/master/scripts" "bitwarden.sh" "/root"
                chmod +x /root/bitwarden.sh
                if [ -f /root/bitwarden.sh ]
                then
                    print_text_in_color "$IGreen" "Upgrading Bitwarden..."
                    sleep 2
                    yes no | bash /root/bitwarden.sh updateself
                    yes no | bash /root/bitwarden.sh update
                fi
            elif [ -d "$BITWARDEN_HOME"/bwdata ]
            then
                curl_to_dir "https://raw.githubusercontent.com/bitwarden/server/master/scripts" "bitwarden.sh" "$BITWARDEN_HOME"
                chown "$BITWARDEN_USER":"$BITWARDEN_USER" "$BITWARDEN_HOME"/bitwarden.sh
                chmod +x "$BITWARDEN_HOME"/bitwarden.sh
                if [ -f "$BITWARDEN_HOME"/bitwarden.sh ]
                then
                    print_text_in_color "$IGreen" "Upgrading Bitwarden..."
                    sleep 2
                    yes no | sudo -u "$BITWARDEN_USER" bash "$BITWARDEN_HOME"/bitwarden.sh updateself
                    yes no | sudo -u "$BITWARDEN_USER" bash "$BITWARDEN_HOME"/bitwarden.sh update
                fi
            fi
        fi
    fi
fi

# Start Apache2
start_if_stopped apache2

# Just double check if the DB is started as well
if is_this_installed postgresql-common
then
    if ! pgrep postgres >/dev/null 2>&1
    then
        print_text_in_color "$ICyan" "Starting PostgreSQL..."
        systemctl start postgresql.service
    fi
fi

# If the app isn't installed (maybe because it's incompatible), then at least restore from backup and make sure it's disabled
BACKUP_APPS="$(find "$BACKUP/apps" -maxdepth 1 -mindepth 1 -type d)"
mapfile -t BACKUP_APPS <<< "$BACKUP_APPS"
for app in "${BACKUP_APPS[@]}"
do
    app="${app##"$BACKUP/apps/"}"
    if ! [ -d "$NC_APPS_PATH/$app" ] && [ -d "$BACKUP/apps/$app" ]
    then
            print_text_in_color "$ICyan" "Restoring $app from $BACKUP/apps..."
            rsync -Aaxz "$BACKUP/apps/$app" "$NC_APPS_PATH/"
            bash "$SECURE"
            nextcloud_occ_no_check app:disable "$app"
            # Don't execute the update before all cronjobs are finished
            check_running_cronjobs
            # Execute the update
            nextcloud_occ upgrade
    fi
done

# Update all Nextcloud apps a second time (if the old backup was outdated)
if [ "${CURRENTVERSION%%.*}" -ge "15" ]
then
    # Check for upgrades
    print_text_in_color "$ICyan" "Trying to automatically update all Nextcloud apps again..."
    nextcloud_occ_no_check app:update --all
fi

# Remove header for Nextcloud 14 (already in .htaccess)
if [ -f /etc/apache2/sites-available/"$(hostname -f)".conf ]
then
    if grep -q 'Header always set Referrer-Policy' /etc/apache2/sites-available/"$(hostname -f)".conf
    then
        sed -i '/Header always set Referrer-Policy/d' /etc/apache2/sites-available/"$(hostname -f)".conf
        restart_webserver
    fi
fi

# Fix crontab every 5 minutes instead of 15
if crontab -u www-data -l | grep -q "\*/15  \*  \*  \*  \* php -f $NCPATH/cron.php"
then
    crontab -u www-data -l | grep -v "php -f $NCPATH/cron.php" | crontab -u www-data -
    crontab -u www-data -l | { cat; echo "*/5  *  *  *  * php -f $NCPATH/cron.php > /dev/null 2>&1"; } | crontab -u www-data -
    print_text_in_color "$ICyan" "Nextcloud crontab updated to run every 5 minutes."
fi

# Change owner of $BACKUP folder to root
chown -R root:root "$BACKUP"

# Pretty URLs
print_text_in_color "$ICyan" "Setting RewriteBase to \"/\" in config.php..."
chown -R www-data:www-data "$NCPATH"
nextcloud_occ config:system:set htaccess.RewriteBase --value="/"
nextcloud_occ maintenance:update:htaccess
bash "$SECURE" & spinner_loading

# Create $VMLOGS dir
if [ ! -d "$VMLOGS" ]
then
    mkdir -p "$VMLOGS"
fi

# Make all files in executable again
for executable in $find_executables
do
    chmod +x "$executable"
done

CURRENTVERSION_after=$(nextcloud_occ status | grep "versionstring" | awk '{print $3}')
if [[ "$NCVERSION" == "$CURRENTVERSION_after" ]] || [ -n "$PRERELEASE_VERSION" ]
then
    msg_box "Latest version is: $NCVERSION. Current version is: $CURRENTVERSION_after.

||| UPGRADE SUCCESS! |||

If you notice that some apps are disabled, it's because they are not compatible with the new Nextcloud version.
To recover your old apps, please check $BACKUP/apps and copy them to $NCPATH/apps manually.

Thank you for using T&M Hansson IT's updater!"
    nextcloud_occ status
    # Restart notify push if existing
    if [ -f "$NOTIFY_PUSH_SERVICE_PATH" ]
    then
        systemctl restart notify_push
    fi
    print_text_in_color "$ICyan" "Sending notification about the successful update to all admins..."
    notify_admin_gui \
    "Nextcloud is now updated!" \
    "Your Nextcloud is updated to $CURRENTVERSION_after with the update script in the Nextcloud VM."
    mkdir -p "$VMLOGS"/updates
    rm -f "$VMLOGS"/update.log # old place
    echo "NEXTCLOUD UPDATE success-$(date +"%Y%m%d")" >> "$VMLOGS"/updates/update.log
    # Remove logs from last year to save space
    rm -f "$VMLOGS"/updates/update-"$(date --date='1 year ago' +%Y)"*
    if [ -n "$SNAPSHOT_EXISTS" ]
    then
        check_command lvrename /dev/ubuntu-vg/NcVM-snapshot-pending /dev/ubuntu-vg/NcVM-snapshot
        countdown "Automatically restarting your server in 1 minute since LVM-snapshots are present." "60"
        shutdown -r
    fi
    exit 0
else
    msg_box "Latest version is: $NCVERSION. Current version is: $CURRENTVERSION_after.

||| UPGRADE FAILED! |||

No worries, your files are still backed up at $BACKUP!
Please report this issue to $ISSUES

Maintenance mode is kept on."
    notify_admin_gui \
    "Nextcloud update failed!" \
    "Your Nextcloud update failed, please check the logs at $VMLOGS/update.log"
    nextcloud_occ status
    if [ -n "$SNAPSHOT_EXISTS" ]
    then
        # Kill all "$SCRIPTS/update.sh" processes to make sure that no automatic restart happens after exiting this script
        # shellcheck disable=2009
        PROCESS_IDS_NEW=$(ps aux | grep "$SCRIPTS/update.sh" | grep -v grep | awk '{print $2}')
        if [ -n "$PROCESS_IDS_NEW" ]
        then
            mapfile -t PROCESS_IDS_NEW <<< "$PROCESS_IDS_NEW"
            for process in "${PROCESS_IDS_NEW[@]}"
            do
                print_text_in_color "$ICyan" "Killing the process with PID $process to prevent a potential automatic restart..."
                if ! kill "$process"
                then
                    print_text_in_color "$IRed" "Couldn't kill the process with PID $process..."
                fi
            done
        fi
    fi
    exit 1
fi
