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

# Install cifs-utils
install_if_not cifs-utils

# Secure fstab
if [ "$(stat -c %a /etc/fstab)" != "600" ]
then
    chmod 600 /etc/fstab
fi

# Functions
add_mount() {
# Check if mounting slots are available
if grep -q /mnt/smbshares/1 /etc/fstab && grep -q /mnt/smbshares/2 /etc/fstab && grep -q /mnt/smbshares/3 /etc/fstab
then
    msg_box "All three slots are occupied. No mounting slots available. Please delete one of the SMB-mounts."
    return
fi
# Enter SMB-server and Share-name
while true
do
    SERVER_SHARE_NAME=$(whiptail --inputbox "Please Enter the server and Share-name like this:\n//Server/Share" "$WT_HEIGHT" "$WT_WIDTH" 3>&1 1>&2 2>&3)
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
    if ! grep -q "/mnt/smbshares/$count" /etc/fstab
    then 
        # Write to /etc/fstab and mount
        echo "$SERVER_SHARE_NAME /mnt/smbshares/$count cifs username=$SMB_USER,password=$SMB_PASSWORD,vers=3,uid=$UsID,gid=$GrID,file_mode=0770,dir_mode=0770,nounix,noserverino 0 0" >> /etc/fstab
        mkdir -p /mnt/smbshares/$count
        mount /mnt/smbshares/$count
        # Check if mounting was successful
        if [[ ! $(findmnt -M "/mnt/smbshares/$count") ]]
        then
            # If not remove this line from fstab
            msg_box "It seems like the mount wasn't successful. It will get deleted now. Please try again.\nAs a hint: you might fix the connection problem by enabling SMB3 on your SMB-server."
            sed -i "/\/mnt\/smbshares\/$count/d" /etc/fstab
            break
        else
            # Install and enable files_external
            install_and_enable_app files_external
            # Create and mount external storage to the admin group
            MOUNT_ID=$(occ_command files_external:create "SMB$count" local null::null -c datadir="/mnt/smbshares/$count" )
            MOUNT_ID=${MOUNT_ID//[!0-9]/}
            occ_command files_external:applicable --add-group=admin "$MOUNT_ID" -q
            # Inform the user that mounting was successfull
            msg_box "Your mount was successfull, congratulations!\n It is accessible in your root directory in /mnt/smbshares/$count.\nYou can now use the Nextcloud external storage app to access files there."
            break
        fi
    fi
    count=$((count+1))
done
return
}

mount_shares() {
# Check if any SMB-share is created
if ! grep -q /mnt/smbshares /etc/fstab
then
    msg_box "It seems like you have not created any SMB-share."
    return
fi
args=(whiptail --title "mount SMB-shares" --checklist --separate-output "This option let you mount SMB-shares to connect network-shares from the host-computer or other machines in the local network.\nChoose what you want to do.\nIf nothing is shown, then there is nothing to mount.\nSelect or unselect by pressing the spacebar" "$WT_HEIGHT" "$WT_WIDTH" 4)
count=1
# Find out which SMB-shares are available
while  [ $count -le 3 ]
do
    if [[ ! $(findmnt -M "/mnt/smbshares/$count") ]] && grep -q "/mnt/smbshares/$count" /etc/fstab
    then
        args+=("/mnt/smbshares/$count" "$(grep "/mnt/smbshares/$count" /etc/fstab | awk '{print $1}')" OFF)
    fi
    count=$((count+1))
done
# Let the user choose which SMB-shares he wants to mount
selected_options=$("${args[@]}" 3>&1 1>&2 2>&3)
count=1
# Mount selected SMB-shares
while  [ $count -le 3 ]
do
    if [[ $selected_options == *"/mnt/smbshares/$count"* ]]
    then
        mount "/mnt/smbshares/$count"
        if [[ ! $(findmnt -M "/mnt/smbshares/$count") ]]
        then
            msg_box "It seems like the mount of /mnt/smbshares/$count wasn't successful. Please try again."
        else
            msg_box "Your mount was successfull, congratulations!\n It is accessible in your root directory in /mnt/smbshares/$count\nYou can now use the Nextcloud external storage app to access files there."
        fi
    fi
    count=$((count+1))
done
return
}

show_all_mounts() {
# If no entry created, nothing to show
if ! grep -q /mnt/smbshares /etc/fstab
then
    msg_box "You haven't created any SMB-mount. So nothing to show."
    return
fi
# Find out which SMB-shares are available
args=(whiptail --title "list SMB-shares" --checklist "This option let you show detailed information about your SMB-shares.\nChoose what you want to show.\nSelect or unselect by pressing the spacebar" "$WT_HEIGHT" "$WT_WIDTH" 4)
count=1
while  [ $count -le 3 ]
do
    if grep -q "/mnt/smbshares/$count" /etc/fstab
    then
        args+=("/mnt/smbshares/$count" "$(grep "/mnt/smbshares/$count" /etc/fstab | awk '{print $1}')" OFF)
    fi
    count=$((count+1))
done
# Let the user choose which details he wants to see
selected_options=$("${args[@]}" 3>&1 1>&2 2>&3)
# Show selected Shares
count=1
while  [ $count -le 3 ]
do
    if [[ $selected_options == *"/mnt/smbshares/$count"* ]]
    then
        msg_box "$(grep "/mnt/smbshares/$count" /etc/fstab)"
    fi
    count=$((count+1))
done
return
}

unmount_shares() {
# Check if any SMB-shares are available for unmounting
if [[ ! $(findmnt -M "/mnt/smbshares/1") ]] && [[ ! $(findmnt -M "/mnt/smbshares/2") ]] && [[ ! $(findmnt -M "/mnt/smbshares/3") ]]
then
    msg_box "You haven't mounted any SMB-mount. So nothing to unmount"
    return
fi
# Find out which SMB-shares are available
args=(whiptail --title "unmount SMB-shares" --checklist "This option let you unmount SMB-shares to disconnect network-shares from the host-computer or other machines in the local network.\nChoose what you want to do.\nSelect or unselect by pressing the spacebar" "$WT_HEIGHT" "$WT_WIDTH" 4)
count=1
while  [ $count -le 3 ]
do
    if [[ $(findmnt -M "/mnt/smbshares/$count") ]]
    then
        args+=("/mnt/smbshares/$count" "$(grep "/mnt/smbshares/$count" /etc/fstab | awk '{print $1}')" OFF)
    fi
    count=$((count+1))
done
# Let the user select which SMB-shares he wants to unmount
selected_options=$("${args[@]}" 3>&1 1>&2 2>&3)
count=1
while  [ $count -le 3 ]
do
    if [[ $selected_options == *"/mnt/smbshares/$count"* ]]
    then
        umount "/mnt/smbshares/$count" -f
        if [[ $(findmnt -M "/mnt/smbshares/$count") ]]
        then
            msg_box "It seems like the unmount of /mnt/smbshares/$count wasn't successful. Please try again."
        else
            msg_box "Your unmount of /mnt/smbshares/$count was successfull!"
        fi
    fi
    count=$((count+1))
done
return
}

delete_mounts() {
# Check if any SMB-share is available
if ! grep -q /mnt/smbshares /etc/fstab
then
    msg_box "You haven't created any SMB-mount, nothing to delete."
    return
fi
# Check which SMB-shares are available
args=(whiptail --title "delete SMB-mounts" --checklist --separate-output "This option let you delete SMB-shares to disconnect and remove network-shares from the Nextcloud VM.\nChoose what you want to do.\nSelect or unselect by pressing the spacebar" "$WT_HEIGHT" "$WT_WIDTH" 4)
count=1
while  [ $count -le 3 ]
do
    if grep -q "/mnt/smbshares/$count" /etc/fstab
    then
        args+=("/mnt/smbshares/$count" "$(grep "/mnt/smbshares/$count" /etc/fstab | awk '{print $1}')" OFF)
    fi
    count=$((count+1))
done
# Let the user choose which SMB-shares he wants to delete
selected_options=$("${args[@]}" 3>&1 1>&2 2>&3)
# Delete the selected SMB-shares
count=1
while  [ $count -le 3 ]
do
    if [[ $selected_options == *"/mnt/smbshares/$count"* ]]
    then
        if [[ $(findmnt -M "/mnt/smbshares/$count") ]]
        then
            umount "/mnt/smbshares/$count" -f
        fi
        sed -i "/\/mnt\/smbshares\/$count/d" /etc/fstab
        if [[ $(findmnt -M "/mnt/smbshares/$count") ]] || grep -q "/mnt/smbshares/$count" /etc/fstab
        then
            msg_box "Something went wrong during deletion of /mnt/smbshares/$count. Please try again."
        else
            msg_box "Your deletion of /mnt/smbshares/$count was successfull!"
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
    SMB_MOUNT=$(whiptail --title "SMB-share" --radiolist  "This script let you manage SMB-shares to access files from the host-computer or other machines in the local network.\nChoose what you want to do.\nSelect one with the [ARROW] keys and select with the [SPACE] key. Confirm by pressing [ENTER]" "$WT_HEIGHT" "$WT_WIDTH" 4 \
    "add a SMB-mount" "(and mount/connect it)" ON \
    "mount SMB-shares" "(connect SMB-shares)" OFF \
    "show all SMB-mounts" "(show detailed information about the SMB-mounts)" OFF \
    "unmount SMB-shares" "(disconnect SMB-shares)" OFF \
    "delete SMB-mounts" "(and unmount/disconnect them)" OFF 3>&1 1>&2 2>&3)

    if [ "$SMB_MOUNT" == "add a SMB-mount" ]
    then
        add_mount
    elif [ "$SMB_MOUNT" == "mount SMB-shares" ]
    then
        mount_shares
    elif [ "$SMB_MOUNT" == "show all SMB-mounts" ]
    then
        show_all_mounts
    elif [ "$SMB_MOUNT" == "unmount SMB-shares" ]
    then
        unmount_shares
    elif [ "$SMB_MOUNT" == "delete SMB-mounts" ]
    then
        delete_mounts
    else
        break
    fi
done
exit
