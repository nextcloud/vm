#!/bin/bash

# T&M Hansson IT AB © - 2019, https://www.hanssonit.se/

# shellcheck disable=2034,2059
true
# shellcheck source=lib.sh
. <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)

print_text_in_color "$ICyan" "Configuring Cookie Lifetime timeout..."

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Check if root
root_check

# install cifs-utils and secure fstab
apt update
install_if_not cifs-utils
chmod 0600 /etc/fstab

# choose categories
SMB_MOUNT=$(whiptail --title "SMB-Share" --radiolist  "This script let you manage SMB-Shares to access files from the host-computer or other machines in the local network.\nChoose what you want to do.\n\nSelect one with the [ARROW] keys and select with the [SPACE] key. Confirm by pressing [ENTER]" "$WT_HEIGHT" "$WT_WIDTH" 4 \
"add a SMB-Mount" "(and mount/connect it)" ON \
"mount SMB-Shares" "(connect SMB-Shares)" OFF \
"show all SMB-Mounts" "" OFF \
"unmount SMB-Shares" "(disconnect SMB-Shares)" OFF \
"delete SMB-Mounts" "(and unmount/disconnect them)" OFF 3>&1 1>&2 2>&3)

if [ "$SMB_MOUNT" == "add a SMB-Mount" ]
then
    run_app_script smbmount
elif [ "$SMB_MOUNT" == "mount SMB-Shares" ]
then
    run_app_script smbmount
elif [ "$SMB_MOUNT" == "show all SMB-Mounts" ]
then
    grep /mnt/smbshares /etc/fstab
    run_app_script smbmount
elif [ "$SMB_MOUNT" == "unmount SMB-Shares" ]
then
    whiptail --title "unmount SMB-Shares" --checklist --separate-output "This option let you unmount SMB-Shares to disconnect network-shares from the host-computer or other machines in the local network.\nChoose what you want to do.\n\nSelect or unselect by pressing the spacebar" "$WT_HEIGHT" "$WT_WIDTH" 4 \
    "mount 1" "$(grep /mnt/smbshares/1 /etc/fstab | awk '{print $1}')" OFF \
    "mount 2" "$(grep /mnt/smbshares/2 /etc/fstab | awk '{print $2}')" OFF \
    "mount 3" "$(grep /mnt/smbshares/3 /etc/fstab | awk '{print $3}')" OFF 2>results
    
    while read -r -u 11 choice
    do
        case $choice in
            "mount 1")
                umount /mnt/smbshare/1 -f
            ;;
            
            "mount 2")
                umount /mnt/smbshare/2 -f
            ;;
            "mount 3")
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
    whiptail --title "delete SMB-Shares" --checklist --separate-output "This option let you delete SMB-Shares to disconnect and remove network-shares from the host-computer or other machines in the local network.\nChoose what you want to do.\n\nSelect or unselect by pressing the spacebar" "$WT_HEIGHT" "$WT_WIDTH" 4 \
    "mount 1" "$(grep /mnt/smbshares/1 /etc/fstab | awk '{print $1}')" OFF \
    "mount 2" "$(grep /mnt/smbshares/2 /etc/fstab | awk '{print $2}')" OFF \
    "mount 3" "$(grep /mnt/smbshares/3 /etc/fstab | awk '{print $3}')" OFF 2>results
    
    while read -r -u 11 choice
    do
        case $choice in
            "mount 1")
                umount /mnt/smbshare/1 -f
                sed -i '/mnt/smbshare/1' /etc/fstab
            ;;
            
            "mount 2")
                umount /mnt/smbshare/2 -f
                sed -i '/mnt/smbshare/2' /etc/fstab
            ;;
            "mount 3")
                umount /mnt/smbshare/3 -f
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
