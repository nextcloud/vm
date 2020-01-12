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

# install cifs-utils
install_if_not cifs-utils

# secure fstab
if [ "$(stat -c %a /etc/fstab)" != "600" ]
then
    chmod 600 /etc/fstab
fi

# functions
add_mount() {
# check if mounting slots are available
if grep -q /mnt/smbshares/1 /etc/fstab && grep -q /mnt/smbshares/2 /etc/fstab && grep -q /mnt/smbshares/3 /etc/fstab
then
    msg_box "No mounting slots available. Please delete one SMB-Mount."
    return
fi
# enter smb-server and share name
while true
do
    SERVER_SHARE_NAME=$(whiptail --inputbox "Please Enter the Server and Share-Name like this:\n//Server/Share" "$WT_HEIGHT" "$WT_WIDTH" 3>&1 1>&2 2>&3)
    if [[ "no" == $(ask_yes_or_no "Is this correct? $SERVER_SHARE_NAME") ]]
    then
        msg_box "It seems like your weren't satisfied by the PATH you entered. Please try again."
    else
        SERVER_SHARE_NAME=${SERVER_SHARE_NAME// /\\040}
        break
    fi
done
# enter smb-user
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
#enter the password of the smb-user
while true
do
    SMB_PASSWORD=$(whiptail --inputbox "Please enter the password of the SMB-user $SMB_USER" "$WT_HEIGHT" "$WT_WIDTH" 3>&1 1>&2 2>&3)
    if [[ "no" == $(ask_yes_or_no "Is this correct? $SMB_PASSWORD") ]]
    then
        msg_box "It seems like your weren't satisfied by the password for the SMB-User you entered. Please try again."
    else
        break
    fi
done
# write everything to /etc/fstab, mount and connect external storage
count=1
while  [ $count -le 3 ]
do
    # check which mounting slot is available
    if ! grep -q "/mnt/smbshares/$count" /etc/fstab
    then 
        # write to /etc/fstab and mount
        echo "$SERVER_SHARE_NAME /mnt/smbshares/$count cifs username=$SMB_USER,password=$SMB_PASSWORD,vers=3,uid=33,gid=33,file_mode=0770,dir_mode=0770,nounix,noserverino 0 0" >> /etc/fstab
        mkdir -p /mnt/smbshares/$count
        mount /mnt/smbshares/$count
        # check if mounting was successful
        if [[ ! $(findmnt -M "/mnt/smbshares/$count") ]]
        then
            # if not remove this line from fstab
            msg_box "It seems like the mount wasn't successful. It will get deleted now. Please try again."
            sed -i "/\/mnt\/smbshares\/$count/d" /etc/fstab
            break
        else
            # Install and enable files_extrnal
            install_and_enable_app files_external
            # create and mount external storage to the admin group
            MOUNT_ID=$(occ_command files_external:create "SMB$count" local null::null -c datadir="/mnt/smbshares/$count" )
            MOUNT_ID=${MOUNT_ID//[!0-9]/}
            occ_command files_external:applicable --add-group=admin "$MOUNT_ID" -q
            # inform the user that mounting was successfull
            msg_box "Your mount was successfull, congratulations!\n It is accessible in your root directory in /mnt/smbshares/$count.\nYou can now use the Nextcloud external storage app to access files there."
            break
        fi
    fi
    count=$((count+1))
done
return
}

mount_shares() {
# check if any smb-share is created
if ! grep -q /mnt/smbshares /etc/fstab
then
    msg_box "It seems like you have not created any SMB-Share."
    return
fi
args=(whiptail --title "mount SMB-Shares" --checklist --separate-output "This option let you mount SMB-Shares to connect network-shares from the host-computer or other machines in the local network.\nChoose what you want to do.\nIf nothing is shown, then there is nothing to mount.\nSelect or unselect by pressing the spacebar" "$WT_HEIGHT" "$WT_WIDTH" 4)
count=1
# find out which smb-share are available
while  [ $count -le 3 ]
do
    if [[ ! $(findmnt -M "/mnt/smbshares/$count") ]] && grep -q "/mnt/smbshares/$count" /etc/fstab
    then
        args+=("/mnt/smbshares/$count" "$(grep "/mnt/smbshares/$count" /etc/fstab | awk '{print $1}')" OFF)
    fi
    count=$((count+1))
done
# let the user choose which shares he wants to mount
selected_options=$("${args[@]}" 3>&1 1>&2 2>&3)
count=1
# mount selected shares
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
# if no entry created nothing to show
if ! grep -q /mnt/smbshares /etc/fstab
then
    msg_box "You haven't created any SMB-Mount. So nothing to show."
    return
fi
# find out which smb-shares are available
args=(whiptail --title "list SMB-Shares" --checklist "This option let you show detailed information about your SMB-Shares.\nChoose what you want to show.\nSelect or unselect by pressing the spacebar" "$WT_HEIGHT" "$WT_WIDTH" 4)
count=1
while  [ $count -le 3 ]
do
    if grep -q "/mnt/smbshares/$count" /etc/fstab
    then
        args+=("/mnt/smbshares/$count" "$(grep "/mnt/smbshares/$count" /etc/fstab | awk '{print $1}')" OFF)
    fi
    count=$((count+1))
done
# let the user choose which details he wants to see
selected_options=$("${args[@]}" 3>&1 1>&2 2>&3)
# show selected shares
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
# check if any smb-shares are available for unmounting
if [[ ! $(findmnt -M "/mnt/smbshares/1") ]] && [[ ! $(findmnt -M "/mnt/smbshares/2") ]] && [[ ! $(findmnt -M "/mnt/smbshares/3") ]]
then
    msg_box "You haven't mounted any smb-mount. So nothing to unmount"
    return
fi
# find out which shares are available
args=(whiptail --title "unmount SMB-Shares" --checklist "This option let you unmount SMB-Shares to disconnect network-shares from the host-computer or other machines in the local network.\nChoose what you want to do.\nSelect or unselect by pressing the spacebar" "$WT_HEIGHT" "$WT_WIDTH" 4)
count=1
while  [ $count -le 3 ]
do
    if [[ $(findmnt -M "/mnt/smbshares/$count") ]]
    then
        args+=("/mnt/smbshares/$count" "$(grep "/mnt/smbshares/$count" /etc/fstab | awk '{print $1}')" OFF)
    fi
    count=$((count+1))
done
# let the user select which shares he wants to unmount
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
# check if any smb-share available
if ! grep -q /mnt/smbshares /etc/fstab
then
    msg_box "You haven't created any SMB-Mount, nothing to delete."
    return
fi
# check which smb-shares are available
args=(whiptail --title "delete SMB-Mounts" --checklist --separate-output "This option let you delete SMB-Shares to disconnect and remove network-shares from the host-computer or other machines in the local network.\nChoose what you want to do.\nSelect or unselect by pressing the spacebar" "$WT_HEIGHT" "$WT_WIDTH" 4)
count=1
while  [ $count -le 3 ]
do
    if grep -q "/mnt/smbshares/$count" /etc/fstab
    then
        args+=("/mnt/smbshares/$count" "$(grep "/mnt/smbshares/$count" /etc/fstab | awk '{print $1}')" OFF)
    fi
    count=$((count+1))
done
# let the user choose which shares he wants to delete
selected_options=$("${args[@]}" 3>&1 1>&2 2>&3)
# delete the selected shares
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

# loop main menu until exited
while true
do
    # main menu
    SMB_MOUNT=$(whiptail --title "SMB-Share" --radiolist  "This script let you manage SMB-Shares to access files from the host-computer or other machines in the local network.\nChoose what you want to do.\nSelect one with the [ARROW] keys and select with the [SPACE] key. Confirm by pressing [ENTER]" "$WT_HEIGHT" "$WT_WIDTH" 4 \
    "add a SMB-Mount" "(and mount/connect it)" ON \
    "mount SMB-Shares" "(connect SMB-Shares)" OFF \
    "show all SMB-Mounts" "" OFF \
    "unmount SMB-Shares" "(disconnect SMB-Shares)" OFF \
    "delete SMB-Mounts" "(and unmount/disconnect them)" OFF 3>&1 1>&2 2>&3)

    if [ "$SMB_MOUNT" == "add a SMB-Mount" ]
    then
        add_mount
    elif [ "$SMB_MOUNT" == "mount SMB-Shares" ]
    then
        mount_shares
    elif [ "$SMB_MOUNT" == "show all SMB-Mounts" ]
    then
        show_all_mounts
    elif [ "$SMB_MOUNT" == "unmount SMB-Shares" ]
    then
        unmount_shares
    elif [ "$SMB_MOUNT" == "delete SMB-Mounts" ]
    then
        delete_mounts
    else
        break
    fi
done
exit
