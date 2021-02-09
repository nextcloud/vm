#!/bin/bash

# T&M Hansson IT AB © - 2021, https://www.hanssonit.se/
# Copyright © 2021 Simon Lindner (https://github.com/szaimen)

true
SCRIPT_NAME="Restore Backup"
SCRIPT_EXPLAINER="This script allows to restore Nextcloud and other important data that are \
stored on the system partition on different installations than the borg-backup was initially made."
# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh || source <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Check if root
root_check

# Check prerequisites
# install whiptail if not already installed
install_if_not whiptail
print_text_in_color "$ICyan" "Checking prerequisites..."
# Check if Restoring is possible
if [ ! -f "$NCPATH/occ" ]
then
    msg_box "It seems like the default Nextcloud is not installed in $NCPATH.\nThis is not supported."
    exit 1
fi
# Check if activate-tls exists
if [ ! -f /var/scripts/activate-tls.sh ]
then
    msg_box "It seems like you have already run the activate-tls.sh script.\nThis is not supported. Please start all over again with a new NcVM."
    exit 1
fi
# Check webserveruser
WEBUNAME=$(ls -l "$NCPATH"/occ | awk '{print \$4}')
if [ "$WEBUNAME" != "www-data" ]
then 
    msg_box "It seems like the webserveruser is not www-data.\nThis is not supported."
    exit 1
fi
# Check OS_ID
if [ "$(lsb_release -is)" != "Ubuntu" ]
then
    msg_box "This script is only meant to run on Ubuntu.\nThis is not supported"
    exit 1
fi
# Check if datadirectory is mnt-ncdata
if [ "$(nextcloud_occ config:system:get datadirectory)" != "$NCDATA" ]
then   
    msg_box "It seems like the default NCDATA-path is not /mnt/ncdata.\nThis is not supported."
    exit 1
fi
# Check if dbtype is pgsql
if [ "$(nextcloud_occ config:system:get dbtype)" != "pgsql" ]
then
    msg_box "It seems like the default dbtype is not postgresql.\nThis is not supported."
    exit 1
fi
# Check if dbname is nextcloud_db
if [ "\$(occ config:system:get dbname)" != "nextcloud_db" ]
then
    msg_box "It seems like the default dbname is not nextcloud_db.\nThis is not supported."
    exit 1
fi
# Check if dbuser is ncadmin
if [ "$(occ config:system:get dbuser)" != "$NCUSER" ]
then
    msg_box "It seems like the default dbuser is not ncadmin.\nThis is not supported."
    exit 1
fi
# Check if apache2 is installed
if ! installed apache2
then
    msg_box "It seems like your webserver is not apache2.\nThis is not supported."
    exit 1
fi
# Check if pending snapshot is existing and cancel the setup in this case.
if does_snapshot_exist "NcVM-snapshot-pending"
then
    msg_box "It seems to be currently running a backup or update.
Cannot restore the backup now. Please try again later."
    exit 1
elif does_snapshot_exist "NcVM-startup"
then
    msg_box "Please run the update script once before you can continue."
    exit 1
fi
# Check if snapshot exists
if ! does_snapshot_exist "NcVM-snapshot"
then
    msg_box "Unfortunately NcVM-snapshot doesn't exist, hence you are not able to restore the system."
    exit 1
elif ! does_snapshot_exist "NcVM-reserved"
then
    msg_box "Unfortunately NcVM-reserved doesn't exist, hence you are not able to restore the system."
    exit 1
fi
# Check if /mnt/ncdata is mounted
if grep -q " /mnt/ncdata " /etc/mtab
then
    msg_box "The '/mnt/ncdata' directory is mounted and not existing on the root drive.
This is currently not supported."
    exit 1
fi
# The same with the /home directory
if grep -q " /home " /etc/mtab
then
    msg_box "The '/home' directory is mounted and not existing on the root drive.
This is currently not supported."
    exit 1
fi

# Ask for execution
msg_box "$SCRIPT_EXPLAINER"
if ! yesno_box_yes "Do you want to restore your server from backup?"
then
    exit 1
fi

# Mount drive
msg_box "Please disconnect your drive for now and connect it again AFTER you hit OK.
Otherwise we will not be able to detect it."
CURRENT_DRIVES=$(lsblk -o KNAME,TYPE | grep disk | awk '{print $1}')
count=0
while [ "$count" -lt 60 ]
do
    print_text_in_color "$ICyan" "Please connect your drive now."
    sleep 5 & spinner_loading
    echo ""
    NEW_DRIVES=$(lsblk -o KNAME,TYPE | grep disk | awk '{print $1}')
    if [ "$CURRENT_DRIVES" = "$NEW_DRIVES" ]
    then
        count=$((count+5))
    else
        msg_box "A new drive was found. We will continue with the mounting now.
Please leave it connected."
        break
    fi
done

# Exit if no new drive was found
if [ "$count" -ge 60 ]
then
    msg_box "No new drive found within 60 seconds.
Please run this option again if you want to try again."
    exit 1
fi

# Wait until the drive has spin up
countdown "Waiting for the drive to spin up..." 15

# Get all new drives
mapfile -t CURRENT_DRIVES <<< "$CURRENT_DRIVES"
for drive in "${CURRENT_DRIVES[@]}"
do
    NEW_DRIVES=$(echo "$NEW_DRIVES" | grep -v "^$drive$")
done

# Partition menu
args=(whiptail --title "$TITLE" --menu \
"Please select the partition that you would like to mount.
$MENU_GUIDE" "$WT_HEIGHT" "$WT_WIDTH" 4)

# Get information that are important to show the partition menu
mapfile -t NEW_DRIVES <<< "$NEW_DRIVES"
for drive in "${NEW_DRIVES[@]}"
do
    DRIVE_DESCRIPTION=$(lsblk -o NAME,VENDOR,MODEL | grep "^$drive" | awk '{print $2, $3}')
    PARTITION_STATS=$(lsblk -o KNAME,FSTYPE,SIZE,UUID,LABEL | grep "^$drive" | grep -v "^$drive ")
    unset PARTITIONS
    mapfile -t PARTITIONS <<< "$(echo "$PARTITION_STATS" | awk '{print $1}')"
    for partition in "${PARTITIONS[@]}"
    do
        STATS=$(echo "$PARTITION_STATS" | grep "^$partition ")
        FSTYPE=$(echo "$STATS" | awk '{print $2}')
        if [ "$FSTYPE" != "ntfs" ]
        then
            continue
        fi
        SIZE=$(echo "$STATS" | awk '{print $3}')
        UUID=$(echo "$STATS" | awk '{print $4}')
        if [ -z "$UUID" ]
        then
            continue
        fi
        LABEL=$(echo "$STATS" | awk '{print $5,$6,$7,$8,$9,$10,$11,$12}' | sed 's| |_|g' |  sed -r 's|[_]+$||')
        if ! grep -q "$UUID" /etc/fstab
        then
            args+=("$UUID" "$LABEL $DRIVE_DESCRIPTION $SIZE $FSTYPE")
            UUIDS+="$UUID"
        else
            msg_box "The partition
$UUID $LABEL $DRIVE_DESCRIPTION $SIZE $FSTYPE
is already existing.\n
If you want to remove it, run the following two commands:
sudo sed -i '/$UUID/d' /etc/fstab
sudo reboot"
        fi
    done
done

# Check if at least one drive was found
if [ -z "$UUIDS" ] 
then
    msg_box "No drive found that can get mounted.
Most likely none is NTFS formatted."
    exit 1
fi

# Show the partition menu
UUID=$("${args[@]}" 3>&1 1>&2 2>&3)
if [ -z "$UUID" ]
then
    exit 1
fi

# Mount the drive
DRIVE_MOUNT="/tmp/backupdrive"
mkdir -p "$DRIVE_MOUNT"
if mountpoint -q "$DRIVE_MOUNT"
then
    umount "$DRIVE_MOUNT"
fi
if ! mount UUID="$UUID" "$DRIVE_MOUNT"
then
    msg_box "Could not mount the selected drive. Something is wrong."
    exit 1
fi

# Find borg repository
print_text_in_color "$ICyan" "Searching for the borg repository. Please be patient!\n(This will take max 60s)"
BORG_REPOS=$(timeout 60 find "$DRIVE_MOUNT/" -type f -name config)
if [ -z "$BORG_REPOS" ]
then
    msg_box "No borg repository found. Are you sure that drive contains one?\nCannot proceed!"
    umount "$DRIVE_MOUNT"
    exit 1
fi
print_text_in_color "$IGreen" "Found:\n$BORG_REPOS" 
print_text_in_color "$ICyan" "Checking if the found borg repositories are valid..."
sleep 2
mapfile -t BORG_REPOS <<< "$BORG_REPOS"
for repository in "${BORG_REPOS[@]}"
do
    if grep -q "\[repository\]" "$repository"
    then
        VALID_REPOS+=("$repository")
    fi
done
if [ -z "${VALID_REPOS[*]}" ]
then
    msg_box "No valid borg repository found.\nCannot proceed!"
    umount "$DRIVE_MOUNT"
    exit 1
fi

# Repo menu
args=(whiptail --title "$TITLE" --menu \
"Please select the borg repository that you would like to use.
$MENU_GUIDE" "$WT_HEIGHT" "$WT_WIDTH" 4)
for repository in "${VALID_REPOS[@]}"
do
    args+=("$repository" "")
done

# Show the repo menu
BORG_REPO=$("${args[@]}" 3>&1 1>&2 2>&3)
if [ -z "$BORG_REPO" ]
then
    umount "$DRIVE_MOUNT"
    exit 1
fi

# Install borg
print_text_in_color "$ICyan" "Installing borgbackup..."
install_if_not borgbackup

# Enter password
while :
do
    PASSPHRASE=$(input_box_flow "Please enter the passphrase that was used to encrypt your borg backup.
    If you want to cancel, type in 'exit' and press '[ENTER]'.")
    if [ "$PASSPHRASE" = "exit" ]
    then
        umount "$DRIVE_MOUNT"
        exit 1
    fi
    export BORG_PASSPHRASE="$PASSPHRASE"
    if ! borg list "$BORG_REPO"
    then
        msg_box "It seems like the passphrase was wrong. Please try again!"
    else
        break
    fi
done

# Get latest Backup archive
BORG_ARCHIVE=$(borg list "$BORG_REPO" | grep "NcVM-system-partition" | awk '{print $1}' | sort -r | head -1)
print_text_in_color "$ICyan" "Using the latest borg archive $BORG_ARCHIVE..."

# Test borg archive
msg_box "We will now check if extracting of the backup works.
This can take much time, though."
if yesno_box_yes "Do you want to do this?"
then
    mkdir -p /tmp/borgextract
    cd /tmp/borgextract
    if ! borg extract --dry-run --list "$BORG_REPO::$BORG_ARCHIVE"
    then
        msg_box "Some errors were reported while checking the archive extracting.\nCannot proceed."
        umount "$DRIVE_MOUNT"
        exit 1
    fi
fi

# Ask if proceed
if ! yesno_box_no "Do you want to restore your backup?
This is the last step where you can cancel!"
then
    exit 1
fi

# Create snapshot to be able to restore the system to previous state
if ! lvremove /dev/ubuntu-vg/NcVM-reserved -y
then
    msg_box "Could not remove NcVM-reserved snapshot. Please reboot your system!"
    umount "$DRIVE_MOUNT"
    exit 1
fi
if ! lvcreate --size 30G --snapshot --name "NcVM-reserved" /dev/ubuntu-vg/ubuntu-lv
then
    msg_box "Could not create NcVM-reserved snapshot. Please reboot your system!"
    umount "$DRIVE_MOUNT"
    exit 1
fi

# Mount borg backup
BORG_MOUNT=/tmp/borg
SYSTEM_DIR="$BORG_MOUNT/system"
mkdir -p "$BORG_MOUNT"
if ! borg mount "$BORG_REPO::$BORG_ARCHIVE" "$BORG_MOUNT"
then
    msg_box "Could not mount the borg archive.\nCannot proceed."
    umount "$DRIVE_MOUNT"
    exit 1
fi

if ! [ -f "$SYSTEM_DIR/$SCRIPTS/nextclouddb.sql" ]
then
    msg_box "Could not find database dump. this is not supported."
    umount "$BORG_MOUNT"
    umount "$DRIVE_MOUNT"
    exit 1
fi

# Maintenance mode
nextcloud_occ_no_check maintenance:mode --on

# Stop apache
systemctl stop apache2

# Delete ncdata and ncpath before restoring
rm -rf "$NCPATH"
rm -rf "$NCDATA"

# Important folders
IMPORTANT_FOLDERS=(home/plex home/bitwarden_rs "$SCRIPTS" mnt media "$NCPATH" root/.smbcredentials)
for directory in "${IMPORTANT_FOLDERS[@]}"
do
    mkdir -p "/$directory"
    directory=$(echo "$directory" | sed 's|^/||')
    INCLUDE_DIRS+=(--include="$directory/***")
done

# Important files
IMPORTANT_FILES=(var/lib/samba/private/passdb.tdb var/lib/samba/private/secrets.tdb etc/samba/smb.conf)
for file in "${IMPORTANT_FILES[@]}"
do
    FILE=$(echo "$file" | rev | cut -d '/' -f 1 | rev)
    mkdir -p "$(echo "/$file" | sed "s|/$FILE$||")"
    INCLUDE_FILES+=(--include="$file")
done

# Restore files
# Rsync include/exclude patterns: https://stackoverflow.com/a/48010623
rsync --archive --human-readable --one-file-system --progress \
"${INCLUDE_DIRS[@]}" "${INCLUDE_FILES[@]}" --exclude='*' "$SYSTEM_DIR/" /

# Database
print_text_in_color "$ICyan" "Restoring the database..."
DB_PASSWORD=$(grep "dbpassword" "$SYSTEM_DIR/$NCPATH/config/config.php" | awk '{print $3}' | sed "s/[',]//g")
sudo -Hiu postgres psql nextcloud_db -c "ALTER USER ncadmin WITH PASSWORD '$DB_PASSWORD'"
sudo -Hiu postgres psql -c "DROP DATABASE nextcloud_db;"
sudo -Hiu postgres psql -c "CREATE DATABASE nextcloud_db WITH OWNER ncadmin TEMPLATE template0 ENCODING \"UTF8\";"
sudo -Hiu postgres psql nextcloud_db < "$SYSTEM_DIR/$SCRIPTS/nextclouddb.sql"

# NTFS
if grep -q " ntfs-3g " "$SYSTEM_DIR/etc/fstab"
then
    grep " ntfs-3g " "$SYSTEM_DIR/etc/fstab" >> /etc/fstab
fi

# Dislocker
if grep -q " fuse.dislocker " "$SYSTEM_DIR/etc/fstab"
then
    print_text_in_color "$ICyan" "Installing dislocker..."
    install_if_not dislocker
    grep " fuse.dislocker " "$SYSTEM_DIR/etc/fstab" >> /etc/fstab
fi

# Cifs-utils
if grep -q " cifs " "$SYSTEM_DIR/etc/fstab"
then
    # Install all tools
    print_text_in_color "$ICyan" "Installing cifs-utils..."
    install_if_not keyutils
    install_if_not cifs-utils
    install_if_not winbind
    if [ "$(grep "^hosts:" /etc/nsswitch.conf | grep wins)" == "" ]
    then
        sed -i '/^hosts/ s/$/ wins/' /etc/nsswitch.conf
    fi
    grep " cifs " "$SYSTEM_DIR/etc/fstab" >> /etc/fstab
fi

# Veracrypt
if [ -f "$SYSTEM_DIR/$SCRIPTS/veracrypt-automount.sh" ]
then
    print_text_in_color "$ICyan" "Installing veracrypt... This can take a long time!"
    add-apt-repository ppa:unit193/encryption -y
    apt update -q4 & spinner_loading
    apt install veracrypt --no-install-recommends -y
    # No need to copy the file since it is already synced via rsync
fi

# SMB-server
if grep -q "^smb-users:" "$SYSTEM_DIR/etc/group"
then
    SMB_USERS=$(grep "^smb-users:" "$SYSTEM_DIR/etc/group" | cut -d ":" -f 4 | sed 's|,| |g')
    read -r -a SMB_USERS <<< "$SMB_USERS"
    for user in "${SMB_USERS[@]}"
    do
        adduser --no-create-home --quiet --disabled-login --force-badname --gecos "" "$user" &>/dev/null
        usermod --append --groups "smb-users","www-data" "$user"
    done
    install_if_not samba
    # No need to sync files since they are already synced via rsync
fi

# Previewgenerator
if grep -q 'Movie' "$SYSTEM_DIR/$NCPATH/config/config.php"
then
    install_if_not ffmpeg
fi
if grep -q 'Photoshop\|SVG\|TIFF' "$SYSTEM_DIR/$NCPATH/config/config.php"
then
    install_if_not php-imagick 
    install_if_not libmagickcore-6.q16-3-extra
fi

# Restore old redis password
REDIS_PASS=$(grep \'password\' "$SYSTEM_DIR/$NCPATH/config/config.php" | awk '{print $3}' | sed "s/[',]//g")
sed -i "s|^requirepass.*|requirepass $REDIS_PASS|g" /etc/redis/redis.conf
# Flush redis
redis-cli -s /var/run/redis/redis-server.sock -c FLUSHALL

# Start web server
systemctl start apache2

# Disable maintenance mode
nextcloud_occ_no_check maintenance:mode --off

# Update the system data-fingerprint
nextcloud_occ_no_check maintenance:data-fingerprint

# repairing the Database, if it got corupted
nextcloud_occ_no_check maintenance:repair 

# Appending the new local IP-address to trusted Domains
print_text_in_color "$ICyan" "Appending the new Ip-Address to trusted Domains..."
IP_ADDR=$(hostname -I | awk '{print $1}' | sed 's/ //')
i=0
while [ "$i" -le 10 ]
do
    if [ "$(nextcloud_occ_no_check config:system:get trusted_domains "$i")" = "" ]
    then
        nextcloud_occ_no_check config:system:set trusted_domains "$i" --value="$IP_ADDR"
        break
    else
        i=$((i+1))
    fi
done

# Import old crontabs
grep -v '^#' "$SYSTEM_DIR/var/spool/cron/crontabs/root" | crontab -u root -
grep -v '^#' "$SYSTEM_DIR/var/spool/cron/crontabs/www-data" | crontab -u www-data -

# Umount the backup drive
umount "$BORG_MOUNT"
umount "$DRIVE_MOUNT"

# Test Nextcloud automatically
if ! nextcloud_occ_no_check -V
then
    msg_box "Something failed while restoring Nextcloud.\nPlease try again!"
    exit 1
fi

# Connect all drives
while :
do
    msg_box "Restore completed!
Nextcloud and the the most important files and configurations were restored!\n
Please connect all external drives that were connected to the old server now!"
    if yesno_box_no "Did you connect all drives?"
    then
        break
    fi
fi
# Mount all drives
print_text_in_color "$ICyan" "Mounting all drives..."
mount -a -v
if [ -f "$SCRIPTS/veracrypt-automount.sh" ]
then
    bash "$SCRIPTS/veracrypt-automount.sh"
fi

# Test Nextcloud manually
msg_box "The time has come to login to your Nextcloud in a Browser \
by opening 'https://$IP_ADDR' to check if Nextcloud works as expected.
(e.g. check the Nextcloud logs and try out all installed apps).
If yes, just press '[ENTER]'."

# Last popup
msg_box "Restore completed!\n
You can now simply reinstall all apps and addons that were installed on your server before!\n
Those need to get installed (if they were installed on the old server before):
Geoblocking, Disk Monitoring, Fail2Ban, ClamAV, SMTP Mail, DDclient, Activate TLS, OnlyOffice, High-Performance \
backend for Talk, Bitwarden RS, Pi-hole, PiVPN, Plex Media Server, Remotedesktop and Midnight Commander.\n
Note:
Bitwarden RS and Plex Media Server files were restored (if they were installed before) but the containers need to get \
installed again to make them run with the restored files."
