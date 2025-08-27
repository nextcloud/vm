#!/bin/bash

# T&M Hansson IT AB © - 2024, https://www.hanssonit.se/
# Copyright © 2021 Simon Lindner (https://github.com/szaimen)

true
SCRIPT_NAME="Veracrypt"
SCRIPT_EXPLAINER="This script automates formatting, encrypting and mounting drives with Veracrypt."
# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Check if root
root_check

# Show explainer
msg_box "$SCRIPT_EXPLAINER"

if ! is_this_installed veracrypt
then
    if ! yesno_box_yes "Do you want to install $SCRIPT_NAME?"
    then
        exit 1
    fi
    msg_box "Please note that in order to install Veracrypt on your server, \
we need to add a 3rd Party PPA, which theoretically could set your server under risk."
    if ! yesno_box_yes "Do you want to continue nonetheless?"
    then
        exit 1
    fi
    msg_box "We will now install Veracrypt. This can take a long time. Please be patient!"
    add-apt-repository ppa:unit193/encryption -y
    apt-get update -q4 & spinner_loading
    apt-get install veracrypt --no-install-recommends -y
fi

# Discover drive
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

# Get all new drives
mapfile -t CURRENT_DRIVES <<< "$CURRENT_DRIVES"
for drive in "${CURRENT_DRIVES[@]}"
do
    NEW_DRIVES=$(echo "$NEW_DRIVES" | grep -v "^$drive")
done

# Partition menu
args=(whiptail --title "$TITLE" --menu \
"Please select the drive that you would like to format and encrypt with Veracrypt.
$MENU_GUIDE" "$WT_HEIGHT" "$WT_WIDTH" 4)

# Get information that are important
mapfile -t NEW_DRIVES <<< "$NEW_DRIVES"
for drive in "${NEW_DRIVES[@]}"
do
    DRIVE_DESCRIPTION=$(lsblk -o NAME,SIZE,VENDOR,MODEL | grep "^$drive" | awk '{print $2, $3, $4}')
    args+=("/dev/$drive" " $DRIVE_DESCRIPTION")
done

# Show the drive menu
DEVICE=$("${args[@]}" 3>&1 1>&2 2>&3)
if [ -z "$DEVICE" ]
then
    exit 1
fi

# Ask for password
while :
do
    PASSWORD=$(input_box_flow "Please enter the Password that you would like to use for encrypting your drive '$DEVICE'
It should be a strong password.
If you want to cancel, just type in 'exit' and press [ENTER].")
    if [ "$PASSWORD" = "exit" ]
    then
        exit 1
    fi
    if yesno_box_no "Have you saved the password at a safe place?"
    then
        break
    fi
done

# Last info box
if ! yesno_box_no "Warning: Are you really sure, that you want to format the drive '$DEVICE' and encrypt it?
All current files on the drive will be erased!
Select 'Yes' to continue with the process. Select 'No' to cancel."
then
    exit 1
fi

# Inform user
msg_box "We will now format the drive '$DEVICE' and encrypt it with Veracrypt. Please be patient!"

# Wipe drive
dd if=/dev/urandom of="$DEVICE" bs=1M count=2
parted "$DEVICE" mklabel gpt --script
parted "$DEVICE" mkpart primary 0% 100% --script

# Wait so that veracrypt doesn't fail
sleep 1

# Format drive
# https://relentlesscoding.com/posts/encrypt-device-with-veracrypt-from-the-command-line/
if ! echo "$PASSWORD" \
| veracrypt --text --quick \
--non-interactive \
--create "$DEVICE"1 \
--volume-type=normal \
--encryption=AES \
--hash=SHA-512 \
--filesystem=Btrfs \
--stdin > /dev/null
then
    msg_box "Something failed while encrypting with Veracrypt."
    exit 1
fi

# Inform user
msg_box "Formatting and encryption with Veracrypt was successful!"

# Mount it
if ! yesno_box_yes "Do you want to mount the encrypted partition to your server?"
then
    exit 1
fi

# Get PARTUUID
PARTUUID=$(lsblk -o PATH,PARTUUID | grep "^$DEVICE"1 | awk '{print $2}')

# Enter the mountpoint
while :
do
    MOUNT_PATH=$(input_box_flow "Please type in the directory where you want to mount the partition.
One example is: '/mnt/data'
The directory has to start with '/mnt/'
If you want to cancel, type 'exit' and press [ENTER].")
    if [ "$MOUNT_PATH" = "exit" ]
    then
        exit 1
    elif echo "$MOUNT_PATH" | grep -q " "
    then
        msg_box "Please don't use spaces!"
    elif ! echo "$MOUNT_PATH" | grep -q "^/mnt/"
    then
        msg_box "The directory has to stat with '/mnt/'"
    elif grep -q " $MOUNT_PATH " /etc/fstab
    then
        msg_box "The mountpoint already exists in fstab. Please try a different one."
    elif mountpoint -q "$MOUNT_PATH"
    then
        msg_box "The mountpoint is already mounted. Please try a different one."
    elif echo "$MOUNT_PATH" | grep -q "^/mnt/ncdata"
    then
        msg_box "The directory isn't allowed to start with '/mnt/ncdata'"
    elif echo "$MOUNT_PATH" | grep -q "^/mnt/smbshares"
    then
        msg_box "The directory isn't allowed to start with '/mnt/smbshares'"
    else
        mkdir -p "$MOUNT_PATH"
        if ! echo "$PASSWORD" | veracrypt -t -k "" --pim=0 --protect-hidden=no --fs-options=defaults \
"/dev/disk/by-partuuid/$PARTUUID" "$MOUNT_PATH"
        then
            msg_box "Something failed while trying to mount the Volume. Please try again."
        else
            break
        fi
    fi
done

# Create automount script
# Unfortunately the automount via crypttab doesn't work (when using a passphrase-file)
if ! [ -f "$SCRIPTS/veracrypt-automount.sh" ]
then
    cat << AUTOMOUNT > "$SCRIPTS/veracrypt-automount.sh"
#!/bin/bash

# Secure the file
chown root:root "$SCRIPTS/veracrypt-automount.sh"
chmod 700 "$SCRIPTS/veracrypt-automount.sh"

# Reset maintenance mode to disabled upon restart
sed -i "/'maintenance'/s/true/false/" "$NCPATH/config/config.php"

# Veracrypt entries
AUTOMOUNT
fi

# Write to file
cat << AUTOMOUNT >> "$SCRIPTS/veracrypt-automount.sh"
if ! echo '$PASSWORD' | veracrypt -t -k "" --pim=0 --protect-hidden=no --fs-options=defaults \
"/dev/disk/by-partuuid/$PARTUUID" "$MOUNT_PATH"
then
    sed -i "/'maintenance'/s/false/true/" "$NCPATH/config/config.php"
    source /var/scripts/fetch_lib.sh
    nextcloud_occ_no_check maintenance:mode --on
    send_mail "$MOUNT_PATH could not get mounted!" "Please connect the drive and reboot your server! \
The maintenance mode was activated to prevent any issue with Nextcloud. \
You can disable it after the drive is successfully mounted again!"
fi
AUTOMOUNT

# Secure the file
chown root:root "$SCRIPTS/veracrypt-automount.sh"
chmod 700 "$SCRIPTS/veracrypt-automount.sh"

# Test if drive is connected
cat << CONNECTED > "$SCRIPTS/is-drive-connected.sh"
#!/bin/bash

# Secure the file
chown root:root "$SCRIPTS/is-drive-connected.sh"
chmod 700 "$SCRIPTS/is-drive-connected.sh"

# Entries
PARTUUID="\$1"

# Test if drive is connected 
while lsblk "/dev/disk/by-partuuid/\$PARTUUID" &>/dev/null
do
    sleep 1
done

# Continue if not
if grep -q "'maintenance'" "$NCPATH/config/config.php"
then
    sed -i "/'maintenance'/s/false/true/" "$NCPATH/config/config.php"
    source /var/scripts/fetch_lib.sh
else
    source /var/scripts/fetch_lib.sh
    nextcloud_occ_no_check maintenance:mode --on
fi
send_mail "One veracrypt drive is not connected anymore!" "Please connect the drive and reboot your server!
The maintenance mode was activated to prevent any issue with Nextcloud. 
A reboot should fix the issue if the drive is successfully connected again."
CONNECTED

# Secure the file
chown root:root "$SCRIPTS/is-drive-connected.sh"
chmod 700 "$SCRIPTS/is-drive-connected.sh"

# Create crontab and start
crontab -u root -l | { cat; echo "@reboot $SCRIPTS/is-drive-connected.sh '$PARTUUID' >/dev/null"; } | crontab -u root -
nohup bash "$SCRIPTS/is-drive-connected.sh" "$PARTUUID" &>/dev/null &

# Adjust permissions at start up
if ! [ -f "$SCRIPTS/adjust-startup-permissions.sh" ]
then
    cat << PERMISSIONS > "$SCRIPTS/adjust-startup-permissions.sh"
#!/bin/bash

# Secure the file
chown root:root "$SCRIPTS/adjust-startup-permissions.sh"
chmod 700 "$SCRIPTS/adjust-startup-permissions.sh"

# Entries
PERMISSIONS
fi
cat << PERMISSIONS >> "$SCRIPTS/adjust-startup-permissions.sh"
find "$MOUNT_PATH/" -not -path "$MOUNT_PATH/.snapshots/*" \\( ! -perm 770 -o ! -group www-data \
-o ! -user www-data \\) -exec chmod 770 {} \\; \
-exec chown www-data:www-data {} \\;
PERMISSIONS

chown root:root "$SCRIPTS/adjust-startup-permissions.sh"
chmod 700 "$SCRIPTS/adjust-startup-permissions.sh"
crontab -u root -l | grep -v "$SCRIPTS/adjust-startup-permissions.sh" | crontab -u root -
crontab -u root -l | { cat; echo "@reboot $SCRIPTS/adjust-startup-permissions.sh"; } | crontab -u root -

# Delete crontab
crontab -u root -l | grep -v 'veracrypt-automount.sh'  | crontab -u root -
# Create service instead
cat << SERVICE > /etc/systemd/system/veracrypt-automount.service
[Unit]
Description=Mount Veracrypt Devices
After=boot.mount
Before=network.target

[Service]
Type=forking
ExecStart=-/bin/bash $SCRIPTS/veracrypt-automount.sh
TimeoutStopSec=1

[Install]
WantedBy=multi-user.target
SERVICE
systemctl disable veracrypt-automount &>/dev/null
systemctl enable veracrypt-automount

# Adjust permissions
print_text_in_color "$ICyan" "Adjusting permissions..."
chown -R www-data:www-data "$MOUNT_PATH"
chmod -R 770 "$MOUNT_PATH"

# Automatically create snapshots
mkdir -p "$MOUNT_PATH/.snapshots"
if ! [ -f "$SCRIPTS/create-hourly-btrfs-snapshots.sh" ]
then
    cat << SNAPSHOT > "$SCRIPTS/create-hourly-btrfs-snapshots.sh"
#!/bin/bash

# Secure the file
chown root:root "$SCRIPTS/create-hourly-btrfs-snapshots.sh"
chmod 700 "$SCRIPTS/create-hourly-btrfs-snapshots.sh"

# Variables
MAX_SNAPSHOTS=54
CURRENT_DATE=\$(date --date @"\$(date +%s)" +"%Y%m%d_%H%M%S")
SNAPSHOT
fi
    cat << SNAPSHOT >> "$SCRIPTS/create-hourly-btrfs-snapshots.sh"

# $MOUNT_PATH
btrfs subvolume snapshot -r "$MOUNT_PATH/" "$MOUNT_PATH/.snapshots/@\$CURRENT_DATE"
while [ "\$(find "$MOUNT_PATH/.snapshots/" -maxdepth 1 -mindepth 1 -type d -name '@*_*' | wc -l)" -gt "\$MAX_SNAPSHOTS" ]
do
    DELETE="\$(find "$MOUNT_PATH/.snapshots/" -maxdepth 1 -mindepth 1 -type d -name '@*_*' | sort | head -1)"
    btrfs subvolume delete "\$DELETE"
done
SNAPSHOT
    chown root:root "$SCRIPTS/create-hourly-btrfs-snapshots.sh"
    chmod 700 "$SCRIPTS/create-hourly-btrfs-snapshots.sh"
    if yesno_box_yes "Do you want snapshots to get created every 15 min? (Recommended for SSDs!)
If at least one Veracrypt-BTRFS drive is a HDD, you should choose 'No' here to create snapshots every hour!"
    then
        crontab -u root -l | grep -v "$SCRIPTS/create-hourly-btrfs-snapshots.sh" | crontab -u root -
        crontab -u root -l | { cat; echo "*/15 8-17 * * * $SCRIPTS/create-hourly-btrfs-snapshots.sh >/dev/null"; } | crontab -u root -
        crontab -u root -l | { cat; echo "0 18-23,0-7 * * * $SCRIPTS/create-hourly-btrfs-snapshots.sh >/dev/null"; } | crontab -u root -
    else
        crontab -u root -l | grep -v "$SCRIPTS/create-hourly-btrfs-snapshots.sh" | crontab -u root -
        crontab -u root -l | { cat; echo "@hourly $SCRIPTS/create-hourly-btrfs-snapshots.sh >/dev/null"; } | crontab -u root -
    fi
    # Execute monthly scrubs
    if ! [ -f "$SCRIPTS/scrub-btrfs-weekly.sh" ]
    then
        cat << SNAPSHOT > "$SCRIPTS/scrub-btrfs-weekly.sh"
#!/bin/bash

# Secure the file
chown root:root "$SCRIPTS/scrub-btrfs-weekly.sh"
chmod 700 "$SCRIPTS/scrub-btrfs-weekly.sh"

# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh
SNAPSHOT
    fi
    cat << SNAPSHOT >> "$SCRIPTS/scrub-btrfs-weekly.sh"

# $MOUNT_PATH
notify_admin_gui "Starting weekly BTRFS check of $MOUNT_PATH" "Starting BTRFS-scrub of $MOUNT_PATH.
You will be notified again when the scrub is done"
if ! btrfs scrub start -B "$MOUNT_PATH"
then
    notify_admin_gui "Error while performing weekly BTRFS scrub of $MOUNT_PATH!" \
    "Error on $MOUNT_PATH\nPlease look at $VMLOGS/weekly-btrfs-scrub.log for further info!"
else
    notify_admin_gui "Weekly BTRFS scrub successful of $MOUNT_PATH!" \
    "$MOUNT_PATH was successfully tested!\nPlease look at $VMLOGS/weekly-btrfs-scrub.log for further info!"
fi
SNAPSHOT
    chown root:root "$SCRIPTS/scrub-btrfs-weekly.sh"
    chmod 700 "$SCRIPTS/scrub-btrfs-weekly.sh"
    crontab -u root -l | grep -v "$SCRIPTS/scrub-btrfs-weekly.sh" | crontab -u root -
    crontab -u root -l | { cat; echo "0 0 1,16 * * $SCRIPTS/scrub-btrfs-weekly.sh >> $VMLOGS/weekly-btrfs-scrub.log 2>&1"; } | crontab -u root -

# Inform the user
msg_box "Congratulations! The mount was successful.
You can now access the partition here:
$MOUNT_PATH"

# Test if Plex is installed
if is_docker_running && docker ps -a --format "{{.Names}}" | grep -q "^plex$"
then
    # Reconfiguring Plex
    msg_box "Plex Media Server found. We are now adjusting Plex to be able to use the new drive.
This can take a while. Please be patient!"
    print_text_in_color "$ICyan" "Downloading the needed tool to get the current Plex config..."
    docker pull assaflavie/runlike
    echo '#/bin/bash' > /tmp/pms-conf
    docker run --rm -v /var/run/docker.sock:/var/run/docker.sock assaflavie/runlike -p plex >> /tmp/pms-conf
    if ! grep -q "$MOUNT_PATH:$MOUNT_PATH:ro" /tmp/pms-conf
    then
        MOUNT_PATH_SED="${MOUNT_PATH//\//\\/}"
        sed -i "0,/--volume/s// -v $MOUNT_PATH_SED:$MOUNT_PATH_SED:ro \\\\\n&/" /tmp/pms-conf
        docker stop plex
        if ! docker rm plex
        then
            msg_box "Something failed while removing the old container."
            exit 1
        fi
        if ! bash /tmp/pms-conf
        then
            msg_box "Starting the new container failed. You can find the config here: '/tmp/pms-conf'"
            exit 1
        fi
        rm /tmp/pms-conf
        msg_box "Plex was adjusted!"
    else
        rm /tmp/pms-conf
        msg_box "No need to update Plex, since the drive is already mounted to Plex."
    fi
fi

exit
