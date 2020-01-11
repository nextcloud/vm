#!/bin/bash

# T&M Hansson IT AB © - 2019, https://www.hanssonit.se/

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

# choose categories
SMB_MOUNT=$(whiptail --title "SMB-Share" --radiolist  "This script let you manage SMB-Shares to access files from the host-computer or other machines in the local network.\nChoose what you want to do.\nSelect one with the [ARROW] keys and select with the [SPACE] key. Confirm by pressing [ENTER]" "$WT_HEIGHT" "$WT_WIDTH" 4 \
"add a SMB-Mount" "(and mount/connect it)" ON \
"mount SMB-Shares" "(connect SMB-Shares)" OFF \
"show all SMB-Mounts" "" OFF \
"unmount SMB-Shares" "(disconnect SMB-Shares)" OFF \
"delete SMB-Mounts" "(and unmount/disconnect them)" OFF 3>&1 1>&2 2>&3)

if [ "$SMB_MOUNT" == "add a SMB-Mount" ]
then
    if [ "$(grep /mnt/smbshares/1 /etc/fstab)" != "" ] && [ "$(grep /mnt/smbshares/2 /etc/fstab)" != "" ] && [ "$(grep /mnt/smbshares/3 /etc/fstab)" != "" ]
    then
        msg_box "No mounting slots available. Please delete one SMB-Mount."
        run_app_script smbmount
    fi
    while true
    do
        SERVER_SHARE_NAME=$(whiptail --inputbox "Please Enter the Server and Share-Name like this:\n//Server/Share" "$WT_HEIGHT" "$WT_WIDTH" 3>&1 1>&2 2>&3)
        if [[ "no" == $(ask_yes_or_no "Is this correct? $SERVER_SHARE_NAME") ]]
        then
            msg_box "It seems like your weren't satisfied by the Path you entered. Please try again."
        else
            SERVER_SHARE_NAME=${SERVER_SHARE_NAME// /\\040}
            break
        fi
    done
    while true
    do
        SMB_USER=$(whiptail --inputbox "Please Enter the username of the SMB-USER" "$WT_HEIGHT" "$WT_WIDTH" 3>&1 1>&2 2>&3)
        if [[ "no" == $(ask_yes_or_no "Is this correct? $SMB_USER") ]]
        then
            msg_box "It seems like your weren't satisfied by the SMB-User you entered. Please try again."
        else
            break
        fi
    done
        while true
    do
        SMB_PASSWORD=$(whiptail --inputbox "Please Enter the password of the SMB-User $SMB_USER" "$WT_HEIGHT" "$WT_WIDTH" 3>&1 1>&2 2>&3)
        if [[ "no" == $(ask_yes_or_no "Is this correct? $SMB_PASSWORD") ]]
        then
            msg_box "It seems like your weren't satisfied by the password for the SMB-User you entered. Please try again."
        else
            break
        fi
    done
    count=1
    while  [ $count -le 3 ]
    do
        if [ "$(grep "/mnt/smbshares/$count" /etc/fstab)" == "" ]
        then 
            echo "$SERVER_SHARE_NAME /mnt/smbshares/$count cifs username=$SMB_USER,password=$SMB_PASSWORD,vers=3,uid=33,gid=33,file_mode=0770,dir_mode=0770,nounix,noserverino 0 0" >> /etc/fstab
            mkdir -p /mnt/smbshares/$count
            mount /mnt/smbshares/$count
            if [[ ! $(findmnt -M "/mnt/smbshares/$count") ]]
            then
                msg_box "It seems like the mount wasn't successful. It will get deleted now. Please try again."
                sed -i "/\/mnt\/smbshares\/$count/d" /etc/fstab
                break
            else
                occ_command app:list >> NcAppsList
                if [ $(grep -n 'files_external' NcAppsList | cut -d : -f 1) -gt $(grep -n 'Disabled' NcAppsList | cut -d : -f 1) ]
                then
                    occ_command app:enable files_external
                fi
                rm NcAppsList
                MOUNT_ID=$(occ_command files_external:create "SMB$count" local null::null -c datadir="/mnt/smbshares/$count" )
                MOUNT_ID=${MOUNT_ID//[!0-9]/}
                occ_command files_external:applicable --add-group=admin "$MOUNT_ID" -q
                msg_box "Your mount was successfull, congratulations!\n It is accessible in your root directory in /mnt/smbshares/$count.\nYou can now use the Nextcloud external storage app to access files there."
                break
            fi
        fi
        count=$(( $count + 1))
    done
    run_app_script smbmount
elif [ "$SMB_MOUNT" == "mount SMB-Shares" ]
then
    if [ "$(grep /mnt/smbshares /etc/fstab)" == "" ]
    then
        msg_box "It seems like you have not created any SMB-Share."
        run_app_script smbmount
    fi
    args=(whiptail --title "mount SMB-Shares" --checklist --separate-output "This option let you mount SMB-Shares to connect network-shares from the host-computer or other machines in the local network.\nChoose what you want to do.\nIf nothing is shown, then there is nothing to mount.\nSelect or unselect by pressing the spacebar" "$WT_HEIGHT" "$WT_WIDTH" 4)
    count=1
    while  [ $count -le 3 ]
    do
        if [[ ! $(findmnt -M "/mnt/smbshares/$count") ]] && [ "$(grep "/mnt/smbshares/$count" /etc/fstab)" != "" ]
        then
            args+=("/mnt/smbshares/$count" "$(grep "/mnt/smbshares/$count" /etc/fstab | awk '{print $1}')" OFF)
        fi
        count=$(( $count + 1))
    done
    selected_options=$("${args[@]}" 3>&1 1>&2 2>&3)
    count=1
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
        count=$(( $count + 1))
    done
    run_app_script smbmount
elif [ "$SMB_MOUNT" == "show all SMB-Mounts" ]
then
    if [ "$(grep /mnt/smbshares /etc/fstab)" == "" ]
    then
        msg_box "You haven't created any SMB-Mount. So nothing to show."
        run_app_script smbmount
    fi
    msg_box "$(grep /mnt/smbshares /etc/fstab)" 
    run_app_script smbmount
elif [ "$SMB_MOUNT" == "unmount SMB-Shares" ]
then
    if [[ ! $(findmnt -M "/mnt/smbshares/1") ]] && [[ ! $(findmnt -M "/mnt/smbshares/2") ]] && [[ ! $(findmnt -M "/mnt/smbshares/3") ]]
    then
        msg_box "You haven't mounted any smb-mount. So nothing to unmount"
        run_app_script smbmount
    fi
    args=(whiptail --title "unmount SMB-Shares" --checklist "This option let you unmount SMB-Shares to disconnect network-shares from the host-computer or other machines in the local network.\nChoose what you want to do.\nSelect or unselect by pressing the spacebar" "$WT_HEIGHT" "$WT_WIDTH" 4)
    count=1
    while  [ $count -le 3 ]
    do
        if [[ $(findmnt -M "/mnt/smbshares/$count") ]]
        then
            args+=("/mnt/smbshares/$count" "$(grep "/mnt/smbshares/$count" /etc/fstab | awk '{print $1}')" OFF)
        fi
        count=$(( $count + 1))
    done
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
        count=$(( $count + 1))
    done
    run_app_script smbmount
elif [ "$SMB_MOUNT" == "delete SMB-Mounts" ]
then
    if [ "$(grep /mnt/smbshares /etc/fstab)" == "" ]
    then
        msg_box "You haven't created any SMB-Mount. So nothing to delete."
        run_app_script smbmount
    fi
    args=(whiptail --title "delete SMB-Mounts" --checklist --separate-output "This option let you delete SMB-Shares to disconnect and remove network-shares from the host-computer or other machines in the local network.\nChoose what you want to do.\nSelect or unselect by pressing the spacebar" "$WT_HEIGHT" "$WT_WIDTH" 4)
    count=1
    while  [ $count -le 3 ]
    do
        if [ "$(grep "/mnt/smbshares/$count" /etc/fstab)" != "" ]
        then
            args+=("/mnt/smbshares/$count" "$(grep "/mnt/smbshares/$count" /etc/fstab | awk '{print $1}')" OFF)
        fi
        count=$(( $count + 1))
    done
    selected_options=$("${args[@]}" 3>&1 1>&2 2>&3)
    if [[ $selected_options == *"/mnt/smbshares/1"* ]]
    then
        if [[ $(findmnt -M "/mnt/smbshares/1") ]]
        then
            umount /mnt/smbshares/1 -f
        fi
        sed -i '/\/mnt\/smbshares\/1/d' /etc/fstab
        if [[ $(findmnt -M "/mnt/smbshares/1") ]] || [ "$(grep /mnt/smbshares/1 /etc/fstab)" != "" ]
        then
            msg_box "Something went wrong during deletion of /mnt/smbshares/1. Please try again."
        else
            msg_box "Your deletion of /mnt/smbshares/1 was successfull!"
        fi
    fi
    if [[ $selected_options == *"/mnt/smbshares/2"* ]]
    then
        if [[ $(findmnt -M "/mnt/smbshares/2") ]]
        then
            umount /mnt/smbshares/2 -f
        fi
        sed -i '/\/mnt\/smbshares\/2/d' /etc/fstab
        if [[ $(findmnt -M "/mnt/smbshares/2") ]] || [ "$(grep /mnt/smbshares/2 /etc/fstab)" != "" ]
        then
            msg_box "Something went wrong during deletion of /mnt/smbshares/2. Please try again."
        else
            msg_box "Your deletion of /mnt/smbshares/2 was successfull!"
        fi
    fi
    if [[ $selected_options == *"/mnt/smbshares/3"* ]]
    then
        if [[ $(findmnt -M "/mnt/smbshares/3") ]]
        then
            umount /mnt/smbshares/3 -f
        fi
        sed -i '/\/mnt\/smbshares\/3/d' /etc/fstab
        if [[ $(findmnt -M "/mnt/smbshares/3") ]] || [ "$(grep /mnt/smbshares/3 /etc/fstab)" != "" ]
        then
            msg_box "Something went wrong during deletion of /mnt/smbshares/3. Please try again."
        else
            msg_box "Your deletion of /mnt/smbshares/3 was successfull!"
        fi
    fi
    run_app_script smbmount
else
    sleep 1
fi
