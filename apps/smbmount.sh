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
if [ "$(ls -l /etc/fstab | awk '{print $1}')" != "-rw-------" ]
then
    chmod 0600 /etc/fstab
fi

# choose categories
SMB_MOUNT=$(whiptail --title "SMB-Share" --radiolist  "This script let you manage SMB-Shares to access files from the host-computer or other machines in the local network.\nChoose what you want to do.\n\nSelect one with the [ARROW] keys and select with the [SPACE] key. Confirm by pressing [ENTER]" "$WT_HEIGHT" "$WT_WIDTH" 4 \
"add a SMB-Mount" "(and mount/connect it)" ON \
"mount SMB-Shares" "(connect SMB-Shares)" OFF \
"show all SMB-Mounts" "" OFF \
"unmount SMB-Shares" "(disconnect SMB-Shares)" OFF \
"delete SMB-Mounts" "(and unmount/disconnect them)" OFF 3>&1 1>&2 2>&3)

if [ "$SMB_MOUNT" == "add a SMB-Mount" ]
then
    while true
    do
        SERVER_SHARE_NAME=$(whiptail --inputbox "Please Enter the Server and Share-Name like this:\n//Server/Share" "$WT_HEIGHT" "$WT_WIDTH" 3>&1 1>&2 2>&3)
        if [[ "no" == $(ask_yes_or_no "Is this correct? $SERVER_SHARE_NAME") ]]
        then
            msg_box "It seems like your weren't satisfied by the Path you entered. Please try again."
        else
            echo "The Server-Share-Name is: $SERVER_SHARE_NAME"
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
            echo "The SMB-USER is: $SMB_USER"
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
            echo "The SMB-Password of the SMB-User $SMB_USER is: $SMB_PASSWORD"
            break
        fi
    done
    if [ "$(grep /mnt/smbshares/1 /etc/fstab)" == "" ]
    then 
        echo "$SERVER_SHARE_NAME /mnt/smbshares/1 cifs username=$SMB_USER,password=$SMB_PASSWORD,uid=33,gid=33,file_mode=0770,dir_mode=0770,nounix,noserverino 0 0" >> /etc/fstab
        mount /mnt/smbshares/1
    elif [ "$(grep /mnt/smbshares/2 /etc/fstab)" == "" ]
    then
        echo "$SERVER_SHARE_NAME /mnt/smbshares/2 cifs username=$SMB_USER,password=$SMB_PASSWORD,uid=33,gid=33,file_mode=0770,dir_mode=0770,nounix,noserverino 0 0" >> /etc/fstab
        mount /mnt/smbshares/2
    elif [ "$(grep /mnt/smbshares/3 /etc/fstab)" == "" ]
    then
        echo "$SERVER_SHARE_NAME /mnt/smbshares/3 cifs username=$SMB_USER,password=$SMB_PASSWORD,uid=33,gid=33,file_mode=0770,dir_mode=0770,nounix,noserverino 0 0" >> /etc/fstab
        mount /mnt/smbshares/3
    else
        msg_box "No mounting slots available. Please delete one SMB-Share."
    fi
    run_app_script smbmount
elif [ "$SMB_MOUNT" == "mount SMB-Shares" ]
then
    whiptail --title "mount SMB-Shares" --checklist --separate-output "This option let you mount SMB-Shares to connect network-shares from the host-computer or other machines in the local network.\nChoose what you want to do.\n\nSelect or unselect by pressing the spacebar" "$WT_HEIGHT" "$WT_WIDTH" 4 \
    "/mnt/smbshares/1" "$(grep /mnt/smbshares/1 /etc/fstab | awk '{print $1}')" OFF \
    "/mnt/smbshares/2" "$(grep /mnt/smbshares/2 /etc/fstab | awk '{print $1}')" OFF \
    "/mnt/smbshares/3" "$(grep /mnt/smbshares/3 /etc/fstab | awk '{print $1}')" OFF 2>results
    
    while read -r -u 11 choice
    do
        case $choice in
            "/mnt/smbshares/1")
                mount /mnt/smbshare/1
            ;;
            
            "/mnt/smbshares/2")
                mount /mnt/smbshare/2
            ;;
            "/mnt/smbshares/3")
                mount /mnt/smbshare/3
            ;;
            
            *)
            ;;
        esac
    done 11< results
    rm -f results
    run_app_script smbmount
elif [ "$SMB_MOUNT" == "show all SMB-Mounts" ]
then
    msg_box "$(grep /mnt/smbshares /etc/fstab)" 
    run_app_script smbmount
elif [ "$SMB_MOUNT" == "unmount SMB-Shares" ]
then
    whiptail --title "unmount SMB-Shares" --checklist --separate-output "This option let you unmount SMB-Shares to disconnect network-shares from the host-computer or other machines in the local network.\nChoose what you want to do.\n\nSelect or unselect by pressing the spacebar" "$WT_HEIGHT" "$WT_WIDTH" 4 \
    "/mnt/smbshares/1" "$(grep /mnt/smbshares/1 /etc/fstab | awk '{print $1}')" OFF \
    "/mnt/smbshares/2" "$(grep /mnt/smbshares/2 /etc/fstab | awk '{print $1}')" OFF \
    "/mnt/smbshares/3" "$(grep /mnt/smbshares/3 /etc/fstab | awk '{print $1}')" OFF 2>results
    
    while read -r -u 11 choice
    do
        case $choice in
            "/mnt/smbshares/1")
                umount /mnt/smbshare/1 -f
            ;;
            
            "/mnt/smbshares/2")
                umount /mnt/smbshare/2 -f
            ;;
            "/mnt/smbshares/3")
                umount /mnt/smbshare/3 -f
            ;;
            
            *)
            ;;
        esac
    done 11< results
    rm -f results
    run_app_script smbmount
elif [ "$SMB_MOUNT" == "delete SMB-Mounts" ]
then
    whiptail --title "delete SMB-Mounts" --checklist --separate-output "This option let you delete SMB-Shares to disconnect and remove network-shares from the host-computer or other machines in the local network.\nChoose what you want to do.\n\nSelect or unselect by pressing the spacebar" "$WT_HEIGHT" "$WT_WIDTH" 4 \
    "/mnt/smbshares/1" "$(grep /mnt/smbshares/1 /etc/fstab | awk '{print $1}')" OFF \
    "/mnt/smbshares/2" "$(grep /mnt/smbshares/2 /etc/fstab | awk '{print $1}')" OFF \
    "/mnt/smbshares/3" "$(grep /mnt/smbshares/3 /etc/fstab | awk '{print $1}')" OFF 2>results
    
    while read -r -u 11 choice
    do
        case $choice in
            "/mnt/smbshares/1")
                if [[ $(findmnt -M "/mnt/smbshares/1") ]]
                then
                    umount /mnt/smbshare/1 -f
                fi
                sed -i '/mnt/smbshare/1' /etc/fstab
            ;;
            
            "/mnt/smbshares/2")
                if [[ $(findmnt -M "/mnt/smbshares/2") ]]
                then
                    umount /mnt/smbshare/2 -f
                fi
                sed -i '/mnt/smbshare/2' /etc/fstab
            ;;
            "/mnt/smbshares/3")
                if [[ $(findmnt -M "/mnt/smbshares/3") ]]
                then
                    umount /mnt/smbshare/3 -f
                fi
                sed -i '/mnt/smbshare/3' /etc/fstab
            ;;
            
            *)
            ;;
        esac
    done 11< results
    rm -f results
    run_app_script smbmount
else
    sleep 1
fi
