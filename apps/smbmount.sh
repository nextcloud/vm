#!/bin/bash

# T&M Hansson IT AB © - 2024, https://www.hanssonit.se/
# Copyright © 2021 Simon Lindner (https://github.com/szaimen)

true
SCRIPT_NAME="SMB Mount"
SCRIPT_EXPLAINER="This script automates mounting SMB-shares locally in your \
system and adds them automatically as external storage to your Nextcloud."
# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Check if root
root_check

# Variables
MAX_COUNT=16
SMBSHARES="/mnt/smbshares"
SMBSHARES_SED=${SMBSHARES//\//\\/}
SMB_CREDENTIALS="/root/.smbcredentials" 

# Install whiptail if not existing
install_if_not whiptail

# Check MAX_COUNT
if ! [ $MAX_COUNT -gt 0 ]
then
    msg_box "The MAX_COUNT variable has to be a positive integer, greater than 0. Please change it accordingly. \
Recommended is MAX_COUNT=16, because not all menus work reliably with a higher count."
    exit
fi

# Show install_popup
if ! is_this_installed cifs-utils
then
    # Ask for installing
    install_popup "$SCRIPT_NAME"
fi

# Needed for DFS-shares to work
install_if_not keyutils

# Install cifs-utils
install_if_not cifs-utils

# Make sure, that name resolution works
install_if_not winbind
if [ "$(grep "^hosts:" /etc/nsswitch.conf | grep wins)" == "" ]
then
    sed -i '/^hosts/ s/$/ wins/' /etc/nsswitch.conf
fi

# Functions
add_mount() {

local SUBTITLE="Add a SMB-mount"

# Check if mounting slots are available
count=1
while [ $count -le $MAX_COUNT ]
do
    if grep -q "$SMBSHARES/$count " /etc/fstab
    then
        count=$((count+1))
    else
        break
    fi
done
if [ $count -gt $MAX_COUNT ]
then
    msg_box "All $MAX_COUNT slots are occupied. No mounting slots available. Please delete one of the SMB-mounts.
If you really want to mount more, you can simply download the smb-mount script \
directly and edit the variable 'MAX_COUNT' to a higher value than $MAX_COUNT by running:
'curl -sLO https://raw.githubusercontent.com/nextcloud/vm/main/apps/smbmount.sh' # Download the script
'nano smbmount.sh' # Edit MAX_COUNT=$MAX_COUNT to your likings and save the file
'sudo bash smbmount.sh' # Execute the script." "$SUBTITLE"
    return
fi

# Enter SMB-server and Share-name
SERVER_SHARE_NAME=$(input_box_flow "Please enter the server and Share-name like this:
//Server/Share\nor\n//IP-address/Share" "$SUBTITLE")
SERVER_SHARE_NAME=${SERVER_SHARE_NAME// /\\040}

# Enter the SMB-user
SMB_USER=$(input_box_flow "Please enter the username of the SMB-user" "$SUBTITLE")

# Enter the password of the SMB-user
SMB_PASSWORD=$(input_box_flow "Please enter the password of the SMB-user $SMB_USER." "$SUBTITLE")

# Write everything to /etc/fstab, mount and connect external storage
count=1
while  [ $count -le $MAX_COUNT ]
do
    # Check which mounting slot is available
    if ! grep -q "$SMBSHARES/$count " /etc/fstab
    then 
        # Write to /etc/fstab and mount
        echo "$SERVER_SHARE_NAME $SMBSHARES/$count cifs credentials=$SMB_CREDENTIALS/SMB$count,uid=www-data,gid=www-data,file_mode=0770,dir_mode=0770,nounix,noserverino,cache=none,nofail 0 0" >> /etc/fstab
        mkdir -p $SMB_CREDENTIALS
        touch $SMB_CREDENTIALS/SMB$count
        chown -R root:root $SMB_CREDENTIALS
        chmod -R 600 $SMB_CREDENTIALS
        echo "username=$SMB_USER" > $SMB_CREDENTIALS/SMB$count
        echo "password=$SMB_PASSWORD" >> $SMB_CREDENTIALS/SMB$count
        mkdir -p "$SMBSHARES/$count"
        mount "$SMBSHARES/$count"
        
        # Check if mounting was successful
        if ! mountpoint -q $SMBSHARES/$count
        then
            # If not remove this line from fstab
            msg_box "It seems like the mount wasn't successful. It will get deleted now. Please try again.
As a hint:
- you might fix the connection problem by enabling SMB3 on your SMB-server.
- You could also try to use the IP-address of the SMB-server instead of the Server-name, if not already done.
- Please also make sure, that 'ping IP-address' of your SMB-Server from your Nextcloud-instance works." "$SUBTITLE"
            sed -i "/$SMBSHARES_SED\/$count /d" /etc/fstab
            if [ -f $SMB_CREDENTIALS/SMB$count ]
            then
                check_command rm $SMB_CREDENTIALS/SMB$count
            fi
            break
        else
            # Inform the user that mounting was successful
            msg_box "Your mount was successful, congratulations!
It's now accessible in your root directory under $SMBSHARES/$count." "$SUBTITLE"
            # Allow to make it a backup mount
            choice=$(whiptail --title "$TITLE" --menu \
            "How do you want to use your new mount?\n
$MENU_GUIDE\n$RUN_LATER_GUIDE" "$WT_HEIGHT" "$WT_WIDTH" 4 \
"Nextcloud External Storage" "(Mount as Local External storage to Nextcloud)" \
"Backups" "(Use the mount for backing up your Nextcloud VM)" 3>&1 1>&2 2>&3)

            case "$choice" in
                "Nextcloud External Storage")
                    print_text_in_color "$ICyan" "Mounting as Local External storage to Nextcloud..."
                    sleep 1
                ;;
                "Backups")
                    print_text_in_color "$ICyan" "Using for backups..."
                    umount "$SMBSHARES/$count"
                    sed -i "/$SMBSHARES_SED\/$count /d" /etc/fstab
                    echo "$SERVER_SHARE_NAME $SMBSHARES/$count cifs credentials=$SMB_CREDENTIALS/SMB$count,uid=root,gid=root,file_mode=0600,dir_mode=0600,nounix,noserverino,cache=none,nofail 0 0" >> /etc/fstab
                    unset SMB_USER && unset SMB_PASSWORD
                    sleep 1
                    msg_box "The backup mount was successfully created!"
                    break
                ;;
                "")
                    break
                ;;
                *)
                ;;
            esac
            # Check if Nextcloud is existing
            unset SMB_USER && unset SMB_PASSWORD
            NEWNAME="SMB$count"
            if ! [ -f $NCPATH/occ ]
            then
                msg_box "Could not find a valid Nextcloud installation. Hence returning to the main menu."
                break
            fi
            NEWPATH="$SMBSHARES/$count"
            # Install and enable files_external
            if ! is_app_enabled files_external
            then
                install_and_enable_app files_external
            fi
            # Choose the name for the external storage
            NEWNAME_BACKUP="$NEWNAME"
            if yesno_box_yes "Do you want to use a different name for this \
external storage inside Nextcloud or just use the default name $NEWNAME?" "$SUBTITLE"
            then
                while :
                do
                    NEWNAME=$(input_box_flow "Please enter the name that will be used inside Nextcloud for this mount.
You can type in 'exit' and press [ENTER] to use the default $NEWNAME_BACKUP
Allowed characters are only spaces, those four special characters '.-_/' and 'a-z' 'A-Z' '0-9'.
Also, it has to start with a slash '/' or a letter 'a-z' or 'A-Z' to be valid.
Advice: you can declare a directory as the Nextcloud users root storage by naming it '/'."  "$SUBTITLE")
                    if ! echo "$NEWNAME" | grep -q "^[a-zA-Z/]"
                    then
                        msg_box "The name has to start with a slash '/' or a letter 'a-z' or 'A-Z' to be valid." "$SUBTITLE"
                    elif ! [[ "$NEWNAME" =~ ^[-._a-zA-Z0-9\ /]+$ ]]
                    then
                        msg_box "Allowed characters are only spaces, \
those four special characters '.-_/' and 'a-z' 'A-Z' '0-9'." "$SUBTITLE"
                    elif [ "$NEWNAME" = "exit" ]
                    then
                        NEWNAME="$NEWNAME_BACKUP"
                        break
                    else
                        break
                    fi
                done
            fi
            # Choose if readonly
            if ! yesno_box_yes "Do you want to mount this external storage as writeable in your Nextcloud?" "$SUBTITLE"
            then
                READONLY="true"
            else
                READONLY="false"
            fi
            # Choose if sharing shall be enabled
            if [ "$NEWNAME" != "/" ]
            then
                if yesno_box_yes "Do you want to enable sharing for this external storage $NEWNAME?" "$SUBTITLE"
                then
                    SHARING="true"
                else
                    SHARING="false"
                fi
            else
                if yesno_box_no "Do you want to enable sharing for this external storage $NEWNAME?" "$SUBTITLE"
                then
                    SHARING="true"
                else
                    SHARING="false"
                fi
            fi
            # Groups and User Menu
            choice=$(whiptail --title "$TITLE - $SUBTITLE" --checklist \
"You can now choose to enable this external storage $NEWNAME for specific Nextcloud users or groups.
If you select no group and no user, the external storage will be visible to all users of your instance.
Please note that you cannot come back to this menu.
$CHECKLIST_GUIDE\n\n$RUN_LATER_GUIDE" "$WT_HEIGHT" "$WT_WIDTH" 4 \
"Choose some Nextcloud groups" "" ON \
"Choose some Nextcloud users" "" OFF 3>&1 1>&2 2>&3)
            unset SELECTED_USER
            unset SELECTED_GROUPS
            # Select Nextcloud groups
            if [[ "$choice" == *"Choose some Nextcloud groups"* ]]
            then
                args=(whiptail --title "$TITLE - $SUBTITLE" --checklist \
"Please select which Nextcloud groups shall get access to the new external storage $NEWNAME.
If you select no group and no user, the external storage will be visible to all users of your instance.
$CHECKLIST_GUIDE\n\n$RUN_LATER_GUIDE" "$WT_HEIGHT" "$WT_WIDTH" 4)
                NC_GROUPS=$(nextcloud_occ_no_check group:list | grep ".*:$" | sed 's|^  - ||g' | sed 's|:$||g')
                mapfile -t NC_GROUPS <<< "$NC_GROUPS"
                for GROUP in "${NC_GROUPS[@]}"
                do
                    if [ "$GROUP" = "admin" ]
                    then
                        args+=("$GROUP  " "" ON)
                    else
                        args+=("$GROUP  " "" OFF)
                    fi
                done
                SELECTED_GROUPS=$("${args[@]}" 3>&1 1>&2 2>&3)
            fi
            # Select Nextcloud users
            if [[ "$choice" == *"Choose some Nextcloud users"* ]]
            then
                args=(whiptail --title "$TITLE - $SUBTITLE" --separate-output --checklist \
"Please select which Nextcloud users shall get access to the share.
If you select no group and no user, the external storage will be visible to all users of your instance.
$CHECKLIST_GUIDE\n\n$RUN_LATER_GUIDE" "$WT_HEIGHT" "$WT_WIDTH" 4)
                NC_USER=$(nextcloud_occ_no_check user:list | sed 's|^  - ||g' | sed 's|:.*||')
                mapfile -t NC_USER <<< "$NC_USER"
                for USER in "${NC_USER[@]}"
                do
                    args+=("$USER  " "" OFF)
                done
                SELECTED_USER=$("${args[@]}" 3>&1 1>&2 2>&3)
            fi
            # Create and mount external storage to the admin group
            MOUNT_ID=$(nextcloud_occ files_external:create "$NEWNAME" local null::null -c datadir="$NEWPATH" )
            MOUNT_ID=${MOUNT_ID//[!0-9]/}
            # Mount to admin group if no group or user chosen
            if [ -z "$SELECTED_GROUPS" ] && [ -z "$SELECTED_USER" ]
            then
                if ! yesno_box_no "Attention! You haven't selected any Nextcloud group or user.
Is this correct?\nIf you select 'yes', it will be visible to all users of your Nextcloud instance.
If you select 'no', it will be only visible to Nextcloud users in the admin group." "$SUBTITLE"
                then
                    nextcloud_occ files_external:applicable --add-group=admin "$MOUNT_ID" -q
                fi
            fi
            # Mount to chosen Nextcloud groups
            if [ -n "$SELECTED_GROUPS" ]
            then
                nextcloud_occ_no_check group:list | grep ".*:$" | sed 's|^  - ||g' | sed 's|:$||' | while read -r NC_GROUPS
                do
                    if [[ "$SELECTED_GROUPS" = *"$NC_GROUPS  "* ]]
                    then
                        nextcloud_occ files_external:applicable --add-group="$NC_GROUPS" "$MOUNT_ID" -q
                    fi
                done
            fi
            # Mount to chosen Nextcloud users
            if [ -n "$SELECTED_USER" ]
            then
                nextcloud_occ_no_check user:list | sed 's|^  - ||g' | sed 's|:.*||' | while read -r NC_USER
                do
                    if [[ "$SELECTED_USER" = *"$NC_USER  "* ]]
                    then
                        nextcloud_occ files_external:applicable --add-user="$NC_USER" "$MOUNT_ID" -q
                    fi
                done
            fi
            # Enable all other options
            nextcloud_occ files_external:option "$MOUNT_ID" filesystem_check_changes 1
            nextcloud_occ files_external:option "$MOUNT_ID" readonly "$READONLY"
            nextcloud_occ files_external:option "$MOUNT_ID" enable_sharing "$SHARING"

            # Inform the user that mounting was successful
            msg_box "Your mount $NEWNAME was successful, congratulations!
You are now using the Nextcloud external storage app to access files there.
The Share has been mounted to the Nextcloud admin-group if not specifically changed to users or groups.
You can now access 'https://yourdomain-or-ipaddress/settings/admin/externalstorages' \
to edit external storages in Nextcloud."

            # Inform the user that he can set up inotify for this external storage
            if ! yesno_box_no "Do you want to enable inotify for this external storage in Nextcloud?
It is only recommended if the content can get changed externally and \
will let Nextcloud track if this external storage was externally changed.
If you choose 'yes', we will install a needed PHP-plugin, the files_inotify app and create a cronjob for you."
            then
                break
            fi

            # Warn a second time
            if ! yesno_box_no "Are you sure, that you want to enable inotify for this external storage?
Please note, that this will need around 1 KB additional RAM per folder.
We will set the max folder variable to 524288 which will be around \
500 MB of additionally needed RAM if you have so many folders.
If you have more folders, you will need to raise this value manually inside '/etc/sysctl.conf'.
Please also note, that this max folder variable counts for \
all external storages for which the inotify option gets activated.
We please you to do the math yourself if the number is high enough for your setup."
            then
                break
            fi

            # Install the inotify PHP extension
            # https://github.com/icewind1991/files_inotify/blob/main/README.md
            if ! pecl list | grep -q inotify
            then 
                print_text_in_color "$ICyan" "Installing the PHP inotify extension..."
                yes no | pecl install inotify
                local INOTIFY_INSTALL=1
            fi
            # Get installed php version
            check_php
            # Enable Inotify
            if [ ! -f $PHP_MODS_DIR/inotify.ini ]
            then
                touch $PHP_MODS_DIR/inotify.ini
            fi
            if ! grep -qFx extension=inotify.so $PHP_MODS_DIR/inotify.ini
            then
                echo "# PECL inotify" > $PHP_MODS_DIR/inotify.ini
                echo "extension=inotify.so" >> $PHP_MODS_DIR/inotify.ini
                check_command phpenmod -v ALL inotify
            fi

            # Set fs.inotify.max_user_watches to 524288
            # https://unix.stackexchange.com/questions/13751/kernel-inotify-watch-limit-reached
            # https://github.com/guard/listen/wiki/Increasing-the-amount-of-inotify-watchers
            if ! grep -q "fs.inotify.max_user_watches" /etc/sysctl.conf
            then
                print_text_in_color "$ICyan" "Setting the max folder variable to 524288..."
                echo fs.inotify.max_user_watches=524288 | sudo tee -a /etc/sysctl.conf
                sudo sysctl -p
            fi

            # Create syslog for files_inotify
            touch "$VMLOGS"/files_inotify.log
            chown www-data:www-data "$VMLOGS"/files_inotify.log

            # Inform the user
            if [ -n "$INOTIFY_INSTALL" ]
            then
                if ! yesno_box_yes "The inotify PHP extension was successfully installed, \
the max folder variable was set to 524288 and $VMLOGS/files_inotify.log was created.
Just press [ENTER] (on the default 'yes') to install the needed \
files_inotify app and set up the cronjob for this external storage."
                then
                    break
                fi
            fi

            # Install files_inotify
            if ! is_app_installed files_inotify
            then
                # This check is needed to check if the app is compatible with the current NC version
                print_text_in_color "$ICyan" "Installing the files_inotify app..."
                if ! nextcloud_occ_no_check app:install files_inotify
                then
                    # Inform the user if the app couldn't get installed
                    msg_box "It seems like the files_inotify app isn't compatible with the current NC version. Cannot proceed."
                    # Remove the app to be able to install it again in another try
                    nextcloud_occ_no_check app:remove files_inotify
                    break
                fi
            fi
            
            # Make sure that the app is enabled, too
            if ! is_app_enabled files_inotify
            then
                nextcloud_occ_no_check app:enable files_inotify
            fi

            # Download script
            download_script ADDONS notify-crontab
            chmod +x "$SCRIPTS"/notify-crontab.sh
            chown root:root "$SCRIPTS"/notify-crontab.sh

            # Add crontab
            print_text_in_color "$ICyan" "Generating crontab..."
            crontab -u root -l | { cat; echo "@reboot $SCRIPTS/notify-crontab.sh $MOUNT_ID"; } | crontab -u root -

            # Run the command in a subshell and don't exit if the smbmount script exits
            nohup sudo -u www-data php "$NCPATH"/occ files_external:notify -v "$MOUNT_ID" >> $VMLOGS/files_inotify.log &
            
            # Inform the user
            msg_box "Congratulations, everything was successfully installed and setup.

Please note that there are some known issues with this inotify option.
It could happen that it doesn't work as expected.
Please look at this issue for further information:
https://github.com/icewind1991/files_inotify/issues/16"
            break
        fi
    fi
    count=$((count+1))
done
return
}

mount_shares() {

local SUBTITLE="Mount SMB-shares"

# Check if any SMB-share is created
if ! grep -q "$SMBSHARES" /etc/fstab
then
    msg_box "It seems like you have not created any SMB-share." "$SUBTITLE"
    return
fi
count=1
while [ $count -le $MAX_COUNT ]
do
    if grep -q "$SMBSHARES/$count " /etc/fstab
    then
        if mountpoint -q $SMBSHARES/$count
        then
            count=$((count+1))
        else
            break
        fi
    else
        count=$((count+1))
    fi
done
if [ $count -gt $MAX_COUNT ]
then
    msg_box "No existing SMB-mount-entry is unmounted. So nothing to mount." "$SUBTITLE"
    return
fi

args=(whiptail --title "$TITLE - $SUBTITLE" --checklist \
"This option let you mount SMB-shares to connect to network-shares \
from the host-computer or other machines in the local network.
Choose which one you want to mount.
$CHECKLIST_GUIDE\n\n$RUN_LATER_GUIDE" "$WT_HEIGHT" "$WT_WIDTH" 4)
count=1

# Find out which SMB-shares are available
while  [ $count -le $MAX_COUNT ]
do
    if ! mountpoint -q $SMBSHARES/$count && grep -q "$SMBSHARES/$count " /etc/fstab
    then
        args+=("$SMBSHARES/$count " "$(grep "$SMBSHARES/$count " /etc/fstab | awk '{print $1}')" OFF)
    fi
    count=$((count+1))
done

# Let the user choose which SMB-shares he wants to mount
selected_options=$("${args[@]}" 3>&1 1>&2 2>&3)
count=1

# Mount selected SMB-shares
while  [ $count -le $MAX_COUNT ]
do
    if [[ $selected_options == *"$SMBSHARES/$count "* ]]
    then
        mount "$SMBSHARES/$count"
        if ! mountpoint -q $SMBSHARES/$count
        then
            msg_box "It seems like the mount of $SMBSHARES/$count wasn't successful. Please try again." "$SUBTITLE"
        else
            msg_box "Your mount was successful, congratulations!
It is accessible in your root directory in $SMBSHARES/$count
You can use the Nextcloud external storage app to access files there." "$SUBTITLE"
        fi
    fi
    count=$((count+1))
done
return
}

show_all_mounts() {

local SUBTITLE="Show all SMB-mounts"

# If no entry created, nothing to show
if ! grep -q "$SMBSHARES" /etc/fstab
then
    msg_box "You haven't created any SMB-mount. So nothing to show." "$SUBTITLE"
    return
fi

# Find out which SMB-shares are available
args=(whiptail --title "$TITLE - $SUBTITLE" --checklist \
"This option let you show detailed information about your SMB-shares.
Choose which one you want to see.
$CHECKLIST_GUIDE\n\n$RUN_LATER_GUIDE" "$WT_HEIGHT" "$WT_WIDTH" 4)
count=1
while  [ $count -le $MAX_COUNT ]
do
    if grep -q "$SMBSHARES/$count " /etc/fstab
    then
        args+=("$SMBSHARES/$count " "$(grep "$SMBSHARES/$count " /etc/fstab | awk '{print $1}')" OFF)
    fi
    count=$((count+1))
done

# Let the user choose which details he wants to see
selected_options=$("${args[@]}" 3>&1 1>&2 2>&3)

# Show selected Shares
count=1
while  [ $count -le $MAX_COUNT ]
do
    if [[ $selected_options == *"$SMBSHARES/$count "* ]]
    then
        if [ -f $SMB_CREDENTIALS/SMB$count ]
        then
            msg_box "$(grep "$SMBSHARES/$count " /etc/fstab)\n$(cat $SMB_CREDENTIALS/SMB$count)" "$SUBTITLE"
        else
            msg_box "$(grep "$SMBSHARES/$count " /etc/fstab)" "$SUBTITLE"
        fi
    fi
    count=$((count+1))
done
return
}

change_mount() {

local SUBTITLE="Change a SMB-mount"

# If no entry created, nothing to show
if ! grep -q "$SMBSHARES" /etc/fstab
then
    msg_box "You haven't created any SMB-mount. So nothing to change." "$SUBTITLE"
    return
fi

# Find out which SMB-shares are available
args=(whiptail --title "$TITLE - $SUBTITLE" --menu \
"This option let you change the password, the username and/or the network-share of one of your SMB-mounts.
Choose which one you want to show.
$MENU_GUIDE\n\n$RUN_LATER_GUIDE" "$WT_HEIGHT" "$WT_WIDTH" 4)
count=1
while  [ $count -le $MAX_COUNT ]
do
    if grep -q "$SMBSHARES/$count " /etc/fstab
    then
        args+=("$SMBSHARES/$count " "$(grep "$SMBSHARES/$count " /etc/fstab | awk '{print $1}')" )
    fi
    count=$((count+1))
done

# Let the user choose which mount he wants to change
selected_option=$("${args[@]}" 3>&1 1>&2 2>&3)

if [[ "$selected_option" == "" ]]
then
    return
fi

# Get count back from selected_option
count=${selected_option//[!0-9]/}

# Test if SMB-share is still mounted and unmount if yes
if mountpoint -q "$SMBSHARES/$count"
then
    umount "$SMBSHARES/$count"
    was_mounted=yes
    if mountpoint -q "$SMBSHARES/$count"
    then
        msg_box "It seems like the unmount of $SMBSHARES/$count wasn't \
successful while trying to change the mount.\nPlease try again." "$SUBTITLE"
        return
    fi
fi

# Store fstab entry for later in a variable
fstab_entry=$(grep "$SMBSHARES/$count " /etc/fstab)

# Get old password and username
if ! [ -f "$SMB_CREDENTIALS/SMB$count" ]
then
    SERVER_SHARE_NAME=$(echo "$fstab_entry" | awk '{print $1}')
    SMB_USER=${fstab_entry##*username=}
    SMB_USER=${SMB_USER%%,*}
    SMB_PASSWORD=${fstab_entry##*password=}
    SMB_PASSWORD=${SMB_PASSWORD%%,*}
else
    old_credentials=$(cat "$SMB_CREDENTIALS/SMB$count")
    SMB_USER=$(echo "$old_credentials" | grep username=)
    SMB_USER=${SMB_USER##*username=}
    SMB_PASSWORD=$(echo "$old_credentials" | grep password=)
    SMB_PASSWORD=${SMB_PASSWORD##*password=}
fi

# Let the user choose which entries he wants to change
choice=$(whiptail --title "$TITLE - $SUBTITLE" --checklist \
"$fstab_entry\n$old_credentials\nChoose which option you want to change.
$CHECKLIST_GUIDE\n\n$RUN_LATER_GUIDE" "$WT_HEIGHT" "$WT_WIDTH" 4 \
"Password" "(change the password of the SMB-user)" OFF \
"Username" "(change the username of the SMB-user)" OFF \
"Share" "(change the SMB-share to use the same mount directory)" OFF 3>&1 1>&2 2>&3)

case "$choice" in
    *"Share"*)
        # Enter SMB-server and Share-name
        SERVER_SHARE_NAME=$(input_box_flow "Please enter the server and Share-name like this:
//Server/Share\nor\n//IP-address/Share" "$SUBTITLE")
        SERVER_SHARE_NAME=${SERVER_SHARE_NAME// /\\040}
    ;;&
    *"Username"*)
        # Enter the SMB-user
        SMB_USER=$(input_box_flow "Please enter the username of the SMB-user" "$SUBTITLE")
    ;;&
    *"Password"*)
        # Enter the password of the SMB-user
        SMB_PASSWORD=$(input_box_flow "Please enter the password of the SMB-user $SMB_USER." "$SUBTITLE")
    ;;&
    "")
        return
    ;;&
    *)
    ;;
esac

# Remove that line from fstab
selected_option_sed=${selected_option//\//\\/}
sed -i "/$selected_option_sed/d" /etc/fstab
unset old_credentials

# Backup old credentials file
if [ -f "$SMB_CREDENTIALS/SMB$count" ]
then
    mv "$SMB_CREDENTIALS/SMB$count" "$SMB_CREDENTIALS/SMB$count.old"
fi

# Write changed line to /etc/fstab and mount
echo "$SERVER_SHARE_NAME $SMBSHARES/$count cifs credentials=$SMB_CREDENTIALS/SMB$count,uid=www-data,gid=www-data,file_mode=0770,dir_mode=0770,nounix,noserverino,cache=none,nofail 0 0" >> /etc/fstab
mkdir -p $SMB_CREDENTIALS
touch "$SMB_CREDENTIALS/SMB$count"
chown -R root:root $SMB_CREDENTIALS
chmod -R 600 $SMB_CREDENTIALS
echo "username=$SMB_USER" > "$SMB_CREDENTIALS/SMB$count"
echo "password=$SMB_PASSWORD" >> "$SMB_CREDENTIALS/SMB$count"
unset SMB_USER && unset SMB_PASSWORD
mount "$SMBSHARES/$count"

# Check if mounting was successful
if ! mountpoint -q "$SMBSHARES/$count"
then
    # If not remove this line from fstab
    msg_box "It seems like the mount of the changed configuration wasn't successful. It will get \
deleted now. The old config will get restored now. Please try again to change the mount." "$SUBTITLE"
    sed -i "/$selected_option_sed/d" /etc/fstab
    echo "$fstab_entry" >> /etc/fstab
    unset fstab_entry
    if [ -f "$SMB_CREDENTIALS/SMB$count.old" ]
    then
        rm "$SMB_CREDENTIALS/SMB$count"
        mv "$SMB_CREDENTIALS/SMB$count.old" "$SMB_CREDENTIALS/SMB$count"
    fi
    if [[ $was_mounted == yes ]]
    then
        unset was_mounted
        mount "$SMBSHARES/$count"
        if ! mountpoint -q "$SMBSHARES/$count"
        then
            msg_box "Your old configuration couldn't get mounted but is restored to /etc/fstab." "$SUBTITLE"
        fi
    fi
else
    # Remove the backup file
    if [ -f "$SMB_CREDENTIALS/SMB$count.old" ]
    then
        check_command rm "$SMB_CREDENTIALS/SMB$count.old"
    fi
    
    # Inform the user that mounting was successful
    msg_box "Your change of the mount was successful, congratulations!" "$SUBTITLE"
fi

}

unmount_shares() {

local SUBTITLE="Unmount SMB-shares"

# Check if any SMB-shares are available for unmounting
count=1
while [ $count -le $MAX_COUNT ]
do
    if ! mountpoint -q $SMBSHARES/$count
    then
        count=$((count+1))
    else
        break
    fi
done
if [ $count -gt $MAX_COUNT ]
then
    msg_box "You haven't mounted any SMB-mount. So nothing to unmount" "$SUBTITLE"
    return
fi

# Find out which SMB-shares are available
args=(whiptail --title "$TITLE - $SUBTITLE" --checklist \
"This option let you unmount SMB-shares to disconnect network-shares from the \
host-computer or other machines in the local network.\nChoose what you want to do.
$CHECKLIST_GUIDE\n\n$RUN_LATER_GUIDE" "$WT_HEIGHT" "$WT_WIDTH" 4)
count=1
while  [ $count -le $MAX_COUNT ]
do
    if mountpoint -q $SMBSHARES/$count
    then
        args+=("$SMBSHARES/$count " "$(grep "$SMBSHARES/$count " /etc/fstab | awk '{print $1}')" OFF)
    fi
    count=$((count+1))
done

# Let the user select which SMB-shares he wants to unmount
selected_options=$("${args[@]}" 3>&1 1>&2 2>&3)
count=1
while  [ $count -le $MAX_COUNT ]
do
    if [[ $selected_options == *"$SMBSHARES/$count "* ]]
    then
        umount "$SMBSHARES/$count"
        if mountpoint -q $SMBSHARES/$count
        then
            msg_box "It seems like the unmount of $SMBSHARES/$count wasn't successful. Please try again." "$SUBTITLE"
        else
            msg_box "Your unmount of $SMBSHARES/$count was successful!" "$SUBTITLE"
        fi
    fi
    count=$((count+1))
done
return
}

delete_mounts() {

local SUBTITLE="Delete SMB-mounts"

# Check if any SMB-share is available
if ! grep -q "$SMBSHARES" /etc/fstab
then
    msg_box "You haven't created any SMB-mount, nothing to delete." "$SUBTITLE"
    return
fi

# Check which SMB-shares are available
args=(whiptail --title "$TITLE - $SUBTITLE" --checklist \
"This option let you delete SMB-shares to disconnect and remove \
network-shares from the Nextcloud VM.\nChoose what you want to do.
$CHECKLIST_GUIDE\n\n$RUN_LATER_GUIDE" "$WT_HEIGHT" "$WT_WIDTH" 4)
count=1
while  [ $count -le $MAX_COUNT ]
do
    if grep -q "$SMBSHARES/$count " /etc/fstab
    then
        args+=("$SMBSHARES/$count " "$(grep "$SMBSHARES/$count " /etc/fstab | awk '{print $1}')" OFF)
    fi
    count=$((count+1))
done

# Let the user choose which SMB-shares he wants to delete
selected_options=$("${args[@]}" 3>&1 1>&2 2>&3)

# Delete the selected SMB-shares
count=1
while  [ $count -le $MAX_COUNT ]
do
    if [[ $selected_options == *"$SMBSHARES/$count "* ]]
    then
        if mountpoint -q $SMBSHARES/$count
        then
            umount "$SMBSHARES/$count"
            if mountpoint -q $SMBSHARES/$count
            then
                msg_box "It seems like the unmount of $SMBSHARES/$count \
wasn't successful during the deletion. Please try again." "$SUBTITLE"
            else
                sed -i "/$SMBSHARES_SED\/$count /d" /etc/fstab
                if [ -f $SMB_CREDENTIALS/SMB$count ]
                then
                    check_command rm $SMB_CREDENTIALS/SMB$count
                fi
                msg_box "Your deletion of $SMBSHARES/$count was successful!" "$SUBTITLE"
            fi
        else
            sed -i "/$SMBSHARES_SED\/$count /d" /etc/fstab
            if [ -f $SMB_CREDENTIALS/SMB$count ]
            then
                check_command rm $SMB_CREDENTIALS/SMB$count
            fi
            msg_box "Your deletion of $SMBSHARES/$count was successful!" "$SUBTITLE"
        fi
    fi
    count=$((count+1))
done
return
}

# Loop main menu until exited
while :
do
    # Main menu
    choice=$(whiptail --title "$TITLE" --menu \
"This script let you manage SMB-shares to access files from the host-computer or other machines in the local network.
Choose what you want to do.
$MENU_GUIDE\n\n$RUN_LATER_GUIDE" "$WT_HEIGHT" "$WT_WIDTH" 4 \
"Add a SMB-mount" "(and mount/connect it)" \
"Mount SMB-shares" "(connect SMB-shares)" \
"Show all SMB-mounts" "(show detailed information about the SMB-mounts)" \
"Change a SMB-mount" "(change password, username &/or share of a mount)" \
"Unmount SMB-shares" "(disconnect SMB-shares)" \
"Delete SMB-mounts" "(and unmount/disconnect them)" \
"Exit SMB-share" "(exit this script)" 3>&1 1>&2 2>&3)

    case "$choice" in
        "Add a SMB-mount")
            add_mount
        ;;
        "Mount SMB-shares")
            mount_shares
        ;;
        "Show all SMB-mounts")
            show_all_mounts
        ;;
        "Change a SMB-mount")
            change_mount
        ;;
        "Unmount SMB-shares")
            unmount_shares
        ;;
        "Delete SMB-mounts")
            delete_mounts
        ;;
        "Exit SMB-share")
            break
        ;;
        "")
            break
        ;;
        *)
        ;;
    esac
done
exit
