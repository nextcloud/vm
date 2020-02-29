#!/bin/bash

# T&M Hansson IT AB © - 2020, https://www.hanssonit.se/

# Use local lib file if existant
if [ -f /var/scripts/main/lib.sh ]
then
# shellcheck disable=2034,2059
true
# shellcheck source=lib.sh
source /var/scripts/main/lib.sh
else
# shellcheck disable=2034,2059
true
# shellcheck source=lib.sh
. <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/testing/lib.sh)
fi

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Check if root
root_check

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
# Variables
SMBSHARES="/mnt/smbshares"
SMBSHARES_SED="\/mnt\/smbshares"

# Functions
add_mount() {
# Check if mounting slots are available
if grep -q "$SMBSHARES/1" /etc/fstab && grep -q "$SMBSHARES/2" /etc/fstab && grep -q "$SMBSHARES/3" /etc/fstab
then
    msg_box "All three slots are occupied. No mounting slots available. Please delete one of the SMB-mounts."
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
    SMB_PASSWORD=$(whiptail --inputbox "Please enter the password of the SMB-user $SMB_USER" "$WT_HEIGHT" "$WT_WIDTH" 3>&1 1>&2 2>&3)
    if [[ "no" == $(ask_yes_or_no "Is this correct? $SMB_PASSWORD") ]]
    then
        msg_box "It seems like your weren't satisfied by the password for the SMB-user you entered. Please try again."
    else
        break
    fi
done
# Get the uid and gid of www-data
UsID=$(id www-data | awk '{print $1}')
UsID=${UsID//[!0-9]/}
GrID=$(id www-data | awk '{print $2}')
GrID=${GrID//[!0-9]/}
# Write everything to /etc/fstab, mount and connect external storage
count=1
while  [ $count -le 3 ]
do
    # Check which mounting slot is available
    if ! grep -q "$SMBSHARES/$count" /etc/fstab
    then 
        # Write to /etc/fstab and mount
        echo "$SERVER_SHARE_NAME $SMBSHARES/$count cifs username=$SMB_USER,password=$SMB_PASSWORD,vers=3.0,uid=$UsID,gid=$GrID,file_mode=0770,dir_mode=0770,nounix,noserverino 0 0" >> /etc/fstab
        mkdir -p "$SMBSHARES/$count"
        mount "$SMBSHARES/$count"
        # Check if mounting was successful
        if [[ ! $(findmnt -M "$SMBSHARES/$count") ]]
        then
            # If not remove this line from fstab
            msg_box "It seems like the mount wasn't successful. It will get deleted now. Please try again.\nAs a hint:\n- you might fix the connection problem by enabling SMB3 on your SMB-server.\n- You could also try to use the IP-address of the SMB-server instead of the Server-name, if not already done.\n- Please also make sure, that 'ping IP-address' of your SMB-Server from your Nextcloud-instance works."
            sed -i "/$SMBSHARES_SED\/$count/d" /etc/fstab
            break
        else
            # Install and enable files_external
            if ! is_app_enabled files_external
            then
                install_and_enable_app files_external
            fi
            # Create and mount external storage to the admin group
            MOUNT_ID=$(occ_command files_external:create "SMB$count" local null::null -c datadir="$SMBSHARES/$count" )
            MOUNT_ID=${MOUNT_ID//[!0-9]/}
            occ_command files_external:applicable --add-group=admin "$MOUNT_ID" -q
            # Inform the user that mounting was successfull
            msg_box "Your mount was successful, congratulations!\nIt's now accessible in your root directory under $SMBSHARES/$count.\nYou are now using the Nextcloud external storage app to access files there. The Share has been mounted to the Nextcloud admin-group.\nYou can now access 'https://yourdomain-or-ipaddress/settings/admin/externalstorages' to rename 'SMB$count' to whatever you like or e.g. enable sharing. Afterwards everything will work reliably."
            break
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
args=(whiptail --title "Mount SMB-shares" --checklist "This option let you mount SMB-shares to connect to network-shares from the host-computer or other machines in the local network.\nChoose which one you want to mount.\nIf nothing is shown, then there is nothing to mount.\nSelect or unselect by pressing the spacebar" "$WT_HEIGHT" "$WT_WIDTH" 4)
count=1
# Find out which SMB-shares are available
while  [ $count -le 3 ]
do
    if [[ ! $(findmnt -M "$SMBSHARES/$count") ]] && grep -q "$SMBSHARES/$count" /etc/fstab
    then
        args+=("$SMBSHARES/$count" "$(grep "$SMBSHARES/$count" /etc/fstab | awk '{print $1}')" OFF)
    fi
    count=$((count+1))
done
# Let the user choose which SMB-shares he wants to mount
selected_options=$("${args[@]}" 3>&1 1>&2 2>&3)
count=1
# Mount selected SMB-shares
while  [ $count -le 3 ]
do
    if [[ $selected_options == *"$SMBSHARES/$count"* ]]
    then
        mount "$SMBSHARES/$count"
        if [[ ! $(findmnt -M "$SMBSHARES/$count") ]]
        then
            msg_box "It seems like the mount of $SMBSHARES/$count wasn't successful. Please try again."
        else
            msg_box "Your mount was successfull, congratulations!\n It is accessible in your root directory in $SMBSHARES/$count\nYou can use the Nextcloud external storage app to access files there."
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
args=(whiptail --title "List SMB-shares" --checklist "This option let you show detailed information about your SMB-shares.\nChoose which one you want to show.\nSelect or unselect by pressing the spacebar" "$WT_HEIGHT" "$WT_WIDTH" 4)
count=1
while  [ $count -le 3 ]
do
    if grep -q "$SMBSHARES/$count" /etc/fstab
    then
        args+=("$SMBSHARES/$count" "$(grep "$SMBSHARES/$count" /etc/fstab | awk '{print $1}')" OFF)
    fi
    count=$((count+1))
done
# Let the user choose which details he wants to see
selected_options=$("${args[@]}" 3>&1 1>&2 2>&3)
# Show selected Shares
count=1
while  [ $count -le 3 ]
do
    if [[ $selected_options == *"$SMBSHARES/$count"* ]]
    then
        msg_box "$(grep "$SMBSHARES/$count" /etc/fstab)"
    fi
    count=$((count+1))
done
return
}

unmount_shares() {
# Check if any SMB-shares are available for unmounting
if [[ ! $(findmnt -M "$SMBSHARES/1") ]] && [[ ! $(findmnt -M "$SMBSHARES/2") ]] && [[ ! $(findmnt -M "$SMBSHARES/3") ]]
then
    msg_box "You haven't mounted any SMB-mount. So nothing to unmount"
    return
fi
# Find out which SMB-shares are available
args=(whiptail --title "Unmount SMB-shares" --checklist "This option let you unmount SMB-shares to disconnect network-shares from the host-computer or other machines in the local network.\nChoose what you want to do.\nSelect or unselect by pressing the spacebar" "$WT_HEIGHT" "$WT_WIDTH" 4)
count=1
while  [ $count -le 3 ]
do
    if [[ $(findmnt -M "$SMBSHARES/$count") ]]
    then
        args+=("$SMBSHARES/$count" "$(grep "$SMBSHARES/$count" /etc/fstab | awk '{print $1}')" OFF)
    fi
    count=$((count+1))
done
# Let the user select which SMB-shares he wants to unmount
selected_options=$("${args[@]}" 3>&1 1>&2 2>&3)
count=1
while  [ $count -le 3 ]
do
    if [[ $selected_options == *"$SMBSHARES/$count"* ]]
    then
        umount "$SMBSHARES/$count" -f
        if [[ $(findmnt -M "$SMBSHARES/$count") ]]
        then
            msg_box "It seems like the unmount of $SMBSHARES/$count wasn't successful. Please try again."
        else
            msg_box "Your unmount of $SMBSHARES/$count was successfull!"
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
while  [ $count -le 3 ]
do
    if grep -q "$SMBSHARES/$count" /etc/fstab
    then
        args+=("$SMBSHARES/$count" "$(grep "$SMBSHARES/$count" /etc/fstab | awk '{print $1}')" OFF)
    fi
    count=$((count+1))
done
# Let the user choose which SMB-shares he wants to delete
selected_options=$("${args[@]}" 3>&1 1>&2 2>&3)
# Delete the selected SMB-shares
count=1
while  [ $count -le 3 ]
do
    if [[ $selected_options == *"$SMBSHARES/$count"* ]]
    then
        if [[ $(findmnt -M "$SMBSHARES/$count") ]]
        then
            umount "$SMBSHARES/$count" -f
        fi
        sed -i "/$SMBSHARES_SED\/$count/d" /etc/fstab
        if [[ $(findmnt -M "$SMBSHARES/$count") ]] || grep -q "$SMBSHARES/$count" /etc/fstab
        then
            msg_box "Something went wrong during deletion of $SMBSHARES/$count. Please try again."
        else
            msg_box "Your deletion of $SMBSHARES/$count was successfull!"
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
