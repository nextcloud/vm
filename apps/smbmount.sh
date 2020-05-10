#!/bin/bash

# T&M Hansson IT AB © - 2020, https://www.hanssonit.se/

# shellcheck disable=2034,2059
true
# shellcheck source=lib.sh
. <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)

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

# Check MAX_COUNT
if ! [ $MAX_COUNT -gt 0 ]
then
    msg_box "The MAX_COUNT variable has to be a positive integer, greater than 0. Please change it accordingly. Recommended is MAX_COUNT=16, because not all menus work reliably with a higher count."
    exit
fi

# Install cifs-utils
install_if_not cifs-utils

# Make sure, that name resolution works
install_if_not winbind
if [ "$(grep "^hosts:" /etc/nsswitch.conf | grep wins)" == "" ]
then
    sed -i '/^hosts/ s/$/ wins/' /etc/nsswitch.conf
fi

# Secure fstab
if [ "$(stat -c %a /etc/fstab)" != "600" ]
then
    chmod 600 /etc/fstab
fi
if [ "$(stat -c %G /etc/fstab)" != "root" ] || [ "$(stat -c %U /etc/fstab)" != "root" ]
then
    chown root:root /etc/fstab
fi

# Functions
add_mount() {

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
    msg_box "All $MAX_COUNT slots are occupied. No mounting slots available. Please delete one of the SMB-mounts.\nIf you really want to mount more, you can simply download the smb-mount script directly and edit the variable 'MAX_COUNT' to a higher value than $MAX_COUNT by running:\n'curl -sLO https://raw.githubusercontent.com/nextcloud/vm/master/apps/smbmount.sh /var/scripts'\n'sudo nano /var/scripts/smbmount.sh' # Edit MAX_COUNT=$MAX_COUNT to your likings and save the file\n'sudo bash /var/scripts/smbmount.sh' # Execute the script."
    return
fi

# Enter SMB-server and Share-name
while true
do
    SERVER_SHARE_NAME=$(whiptail --inputbox "Please enter the server and Share-name like this:\n//Server/Share\nor\n//IP-address/Share" "$WT_HEIGHT" "$WT_WIDTH" 3>&1 1>&2 2>&3)
    if [[ "no" == $(ask_yes_or_no "Is this correct? $SERVER_SHARE_NAME") ]]
    then
        msg_box "It seems like your weren't satisfied by the PATH you entered. Please try again."
    else
        SERVER_SHARE_NAME=${SERVER_SHARE_NAME// /\\040}
        break
    fi
done

# Enter the SMB-user
while true
do
    SMB_USER=$(whiptail --inputbox "Please enter the username of the SMB-user" "$WT_HEIGHT" "$WT_WIDTH" 3>&1 1>&2 2>&3)
    if [[ "no" == $(ask_yes_or_no "Is this correct? $SMB_USER") ]]
    then
        msg_box "It seems like your weren't satisfied by the SMB-user you entered. Please try again."
    else
        break
    fi
done

# Enter the password of the SMB-user
while true
do
    SMB_PASSWORD=$(whiptail --inputbox "Please enter the password of the SMB-user $SMB_USER.\nPlease note, that comma as a character in the password is not supported." "$WT_HEIGHT" "$WT_WIDTH" 3>&1 1>&2 2>&3)
    if [[ "no" == $(ask_yes_or_no "Is this correct? $SMB_PASSWORD") ]]
    then
        msg_box "It seems like your weren't satisfied by the password for the SMB-user you entered. Please try again."
    else
        break
    fi
done

# Write everything to /etc/fstab, mount and connect external storage
count=1
while  [ $count -le $MAX_COUNT ]
do
    # Check which mounting slot is available
    if ! grep -q "$SMBSHARES/$count " /etc/fstab
    then 
        # Write to /etc/fstab and mount
        echo "$SERVER_SHARE_NAME $SMBSHARES/$count cifs credentials=$SMB_CREDENTIALS/SMB$count,vers=3.0,uid=www-data,gid=www-data,file_mode=0770,dir_mode=0770,nounix,noserverino 0 0" >> /etc/fstab
        mkdir -p $SMB_CREDENTIALS
        touch $SMB_CREDENTIALS/SMB$count
        chown -R root:root $SMB_CREDENTIALS
        chmod -R 600 $SMB_CREDENTIALS
        echo "username=$SMB_USER" > $SMB_CREDENTIALS/SMB$count
        echo "password=$SMB_PASSWORD" >> $SMB_CREDENTIALS/SMB$count
        unset SMB_USER && unset SMB_PASSWORD
        mkdir -p "$SMBSHARES/$count"
        mount "$SMBSHARES/$count"
        
        # Check if mounting was successful
        if ! mountpoint -q $SMBSHARES/$count
        then
            # If not remove this line from fstab
            msg_box "It seems like the mount wasn't successful. It will get deleted now. Please try again.\nAs a hint:\n- you might fix the connection problem by enabling SMB3 on your SMB-server.\n- You could also try to use the IP-address of the SMB-server instead of the Server-name, if not already done.\n- Please also make sure, that 'ping IP-address' of your SMB-Server from your Nextcloud-instance works."
            sed -i "/$SMBSHARES_SED\/$count /d" /etc/fstab
            if [ -f $SMB_CREDENTIALS/SMB$count ]
            then
                check_command rm $SMB_CREDENTIALS/SMB$count
            fi
            break
        else
            # Check if Nextcloud is existing
            if [ -f $NCPATH/occ ]
            then
                # Install and enable files_external
                if ! is_app_enabled files_external
                then
                    install_and_enable_app files_external
                fi

                # Create and mount external storage to the admin group
                MOUNT_ID=$(occ_command_no_check files_external:create "SMB$count" local null::null -c datadir="$SMBSHARES/$count" )
                MOUNT_ID=${MOUNT_ID//[!0-9]/}
                occ_command_no_check files_external:applicable --add-group=admin "$MOUNT_ID" -q
                occ_command_no_check files_external:option "$MOUNT_ID" filesystem_check_changes 1

                # Inform the user that mounting was successful
                msg_box "Your mount was successful, congratulations!\nIt's now accessible in your root directory under $SMBSHARES/$count.\nYou are now using the Nextcloud external storage app to access files there. The Share has been mounted to the Nextcloud admin-group.\nYou can now access 'https://yourdomain-or-ipaddress/settings/admin/externalstorages' to rename 'SMB$count' to whatever you like or e.g. enable sharing."
                break
            else
                # Inform the user that mounting was successful
                msg_box "Your mount was successful, congratulations!\nIt's now accessible in your root directory under $SMBSHARES/$count."
                break
            fi
        fi
    fi
    count=$((count+1))
done
return
}

mount_shares() {

# Check if any SMB-share is created
if ! grep -q "$SMBSHARES" /etc/fstab
then
    msg_box "It seems like you have not created any SMB-share."
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
    msg_box "No existing SMB-mount-entry is unmounted. So nothing to mount."
    return
fi

args=(whiptail --title "Mount SMB-shares" --checklist "This option let you mount SMB-shares to connect to network-shares from the host-computer or other machines in the local network.\nChoose which one you want to mount.\nSelect or unselect by pressing the spacebar" "$WT_HEIGHT" "$WT_WIDTH" 4)
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
            msg_box "It seems like the mount of $SMBSHARES/$count wasn't successful. Please try again."
        else
            msg_box "Your mount was successful, congratulations!\n It is accessible in your root directory in $SMBSHARES/$count\nYou can use the Nextcloud external storage app to access files there."
        fi
    fi
    count=$((count+1))
done
return
}

show_all_mounts() {

# If no entry created, nothing to show
if ! grep -q "$SMBSHARES" /etc/fstab
then
    msg_box "You haven't created any SMB-mount. So nothing to show."
    return
fi

# Find out which SMB-shares are available
args=(whiptail --title "List SMB-shares" --checklist "This option let you show detailed information about your SMB-shares.\nChoose which one you want to change.\nSelect or unselect by pressing the spacebar" "$WT_HEIGHT" "$WT_WIDTH" 4)
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
            msg_box "$(grep "$SMBSHARES/$count " /etc/fstab)\n$(cat $SMB_CREDENTIALS/SMB$count)"
        else
            msg_box "$(grep "$SMBSHARES/$count " /etc/fstab)"
        fi
    fi
    count=$((count+1))
done
return
}

change_mount() {

# If no entry created, nothing to show
if ! grep -q "$SMBSHARES" /etc/fstab
then
    msg_box "You haven't created any SMB-mount. So nothing to change."
    return
fi

# Find out which SMB-shares are available
args=(whiptail --title "Change a SMB-mount" --radiolist "This option let you change the password, the username and/or the network-share of one of your SMB-mounts.\nChoose which one you want to show.\nSelect one with the [ARROW] keys and select with the [SPACE] key. Confirm by pressing [ENTER]" "$WT_HEIGHT" "$WT_WIDTH" 4)
count=1
while  [ $count -le $MAX_COUNT ]
do
    if grep -q "$SMBSHARES/$count " /etc/fstab
    then
        args+=("$SMBSHARES/$count " "$(grep "$SMBSHARES/$count " /etc/fstab | awk '{print $1}')" OFF)
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
        msg_box "It seems like the unmount of $SMBSHARES/$count wasn't successful while trying to change the mount. Please try again."
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
choice=$(whiptail --title "Change a SMB-mount" --checklist "$fstab_entry\n$old_credentials\nChoose which option you want to change.\nSelect or unselect by pressing the spacebar" "$WT_HEIGHT" "$WT_WIDTH" 4 \
"Password" "(change the password of the SMB-user)" OFF \
"Username" "(change the username of the SMB-user)" OFF \
"Share" "(change the SMB-share to use the same mount directory)" OFF 3>&1 1>&2 2>&3)

case "$choice" in
    *"Share"*)
        clear
        # Enter SMB-server and Share-name
        while true
        do
            SERVER_SHARE_NAME=$(whiptail --inputbox "Please enter the server and Share-name like this:\n//Server/Share\nor\n//IP-address/Share" "$WT_HEIGHT" "$WT_WIDTH" 3>&1 1>&2 2>&3)
            if [[ "no" == $(ask_yes_or_no "Is this correct? $SERVER_SHARE_NAME") ]]
            then
                msg_box "It seems like your weren't satisfied by the PATH you entered. Please try again."
            else
                SERVER_SHARE_NAME=${SERVER_SHARE_NAME// /\\040}
                break
            fi
        done
    ;;&
    *"Username"*)
        clear
        # Enter the SMB-user
        while true
        do
            SMB_USER=$(whiptail --inputbox "Please enter the username of the SMB-user" "$WT_HEIGHT" "$WT_WIDTH" 3>&1 1>&2 2>&3)
            if [[ "no" == $(ask_yes_or_no "Is this correct? $SMB_USER") ]]
            then
                msg_box "It seems like your weren't satisfied by the SMB-user you entered. Please try again."
            else
                break
            fi
        done
    ;;&
    *"Password"*)
        clear
        # Enter the password of the SMB-user
        while true
        do
            SMB_PASSWORD=$(whiptail --inputbox "Please enter the password of the SMB-user $SMB_USER.\nPlease note, that comma as a character in the password is not supported." "$WT_HEIGHT" "$WT_WIDTH" 3>&1 1>&2 2>&3)
            if [[ "no" == $(ask_yes_or_no "Is this correct? $SMB_PASSWORD") ]]
            then
                msg_box "It seems like your weren't satisfied by the password for the SMB-user you entered. Please try again."
            else
                break
            fi
        done
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
echo "$SERVER_SHARE_NAME $SMBSHARES/$count cifs credentials=$SMB_CREDENTIALS/SMB$count,vers=3.0,uid=www-data,gid=www-data,file_mode=0770,dir_mode=0770,nounix,noserverino 0 0" >> /etc/fstab
mkdir -p $SMB_CREDENTIALS
touch $SMB_CREDENTIALS/SMB$count
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
    msg_box "It seems like the mount of the changed configuration wasn't successful. It will get deleted now. The old config will get restored now. Please try again to change the mount."
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
            msg_box "Your old configuration couldn't get mounted but is restored to /etc/fstab."
        fi
    fi
else
    # Remove the backup file
    if [ -f "$SMB_CREDENTIALS/SMB$count.old" ]
    then
        check_command rm "$SMB_CREDENTIALS/SMB$count.old"
    fi
    
    # Inform the user that mounting was successful
    msg_box "Your change of the mount was successful, congratulations!"
fi

}

unmount_shares() {

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
    msg_box "You haven't mounted any SMB-mount. So nothing to unmount"
    return
fi

# Find out which SMB-shares are available
args=(whiptail --title "Unmount SMB-shares" --checklist "This option let you unmount SMB-shares to disconnect network-shares from the host-computer or other machines in the local network.\nChoose what you want to do.\nSelect or unselect by pressing the spacebar" "$WT_HEIGHT" "$WT_WIDTH" 4)
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
            msg_box "It seems like the unmount of $SMBSHARES/$count wasn't successful. Please try again."
        else
            msg_box "Your unmount of $SMBSHARES/$count was successful!"
        fi
    fi
    count=$((count+1))
done
return
}

delete_mounts() {

# Check if any SMB-share is available
if ! grep -q "$SMBSHARES" /etc/fstab
then
    msg_box "You haven't created any SMB-mount, nothing to delete."
    return
fi

# Check which SMB-shares are available
args=(whiptail --title "Delete SMB-mounts" --checklist "This option let you delete SMB-shares to disconnect and remove network-shares from the Nextcloud VM.\nChoose what you want to do.\nSelect or unselect by pressing the spacebar" "$WT_HEIGHT" "$WT_WIDTH" 4)
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
                msg_box "It seems like the unmount of $SMBSHARES/$count wasn't successful during the deletion. Please try again."
            else
                sed -i "/$SMBSHARES_SED\/$count /d" /etc/fstab
                if [ -f $SMB_CREDENTIALS/SMB$count ]
                then
                    check_command rm $SMB_CREDENTIALS/SMB$count
                fi
                msg_box "Your deletion of $SMBSHARES/$count was successful!"
            fi
        else
            sed -i "/$SMBSHARES_SED\/$count /d" /etc/fstab
            if [ -f $SMB_CREDENTIALS/SMB$count ]
            then
                check_command rm $SMB_CREDENTIALS/SMB$count
            fi
            msg_box "Your deletion of $SMBSHARES/$count was successful!"
        fi
    fi
    count=$((count+1))
done
return
}

# Loop main menu until exited
while true
do
    # Main menu
    choice=$(whiptail --title "SMB-share" --radiolist "This script let you manage SMB-shares to access files from the host-computer or other machines in the local network.\nChoose what you want to do.\nSelect one with the [ARROW] keys and select with the [SPACE] key. Confirm by pressing [ENTER]" "$WT_HEIGHT" "$WT_WIDTH" 4 \
    "Add a SMB-mount" "(and mount/connect it)" ON \
    "Mount SMB-shares" "(connect SMB-shares)" OFF \
    "Show all SMB-mounts" "(show detailed information about the SMB-mounts)" OFF \
    "Change a SMB-mount" "(change password, username &/or share of a mount)" OFF \
    "Unmount SMB-shares" "(disconnect SMB-shares)" OFF \
    "Delete SMB-mounts" "(and unmount/disconnect them)" OFF \
    "Exit SMB-share" "(exit this script)" OFF 3>&1 1>&2 2>&3)

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
