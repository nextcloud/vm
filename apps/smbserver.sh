#!/bin/bash

# T&M Hansson IT AB © - 2020, https://www.hanssonit.se/
# Copyright © 2020 Simon Lindner (https://github.com/szaimen)

# shellcheck disable=2034,2059
true
SCRIPT_NAME="SMB Server"
SCRIPT_EXPLAINER="This script allows you to create and manage a Linux SMB-server."
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
SMB_CONF="/etc/samba/smb.conf"
HASH_DIRECTORY="/root/.smbserver"
HASH_HISTORY="$HASH_DIRECTORY/hash-history"
SMB_GROUP="smb-users"
PROHIBITED_NAMES=(global homes netlogon profiles printers print$ root ncadmin $SMB_GROUP placeholder_for_last_space)
WEB_GROUP="www-data"
WEB_USER="www-data"
MAX_COUNT=16

# Install whiptail if not already
install_if_not whiptail

# Check MAX_COUNT
if ! [ $MAX_COUNT -gt 0 ]
then
    msg_box "The MAX_COUNT variable has to be a positive integer, greater than 0. Please change it accordingly. Recommended is MAX_COUNT=16, because not all menus work reliably with a higher count."
    exit
fi

# Show explainer
explainer_popup

DIRECTORIES=$(find /mnt -maxdepth 3 -type d -not -path "/mnt/ncdata*" | grep -v "^/mnt$")
if [ -z "$DIRECTORIES" ]
then
    msg_box "No directories found that can be used. Please make sure to mount them in '/mnt'."
    exit 1
fi

# Install all needed tools
install_if_not samba
install_if_not members

# Use SMB3
if ! grep -q SMB3 /etc/samba/smb.conf
then
    sed -i '/\[global\]/a protocol = SMB3' "$SMB_CONF"
fi

# Disable the [homes] share by default only if active
sed -i /^\[homes\]$/s/homes/homes_are_disabled_by_NcVM/ "$SMB_CONF"

# Create a history file for storing password hashes
if ! [ -f "$HASH_HISTORY" ]
then
    mkdir -p "$HASH_DIRECTORY"
    touch "$HASH_HISTORY"
fi
chown -R root:root "$HASH_DIRECTORY"
chmod 600 -R "$HASH_DIRECTORY"

samba_stop() {
print_text_in_color "$ICyan" "Stopping samba..."
service smbd stop
update-rc.d smbd disable
update-rc.d nmbd disable
}

samba_start() {
print_text_in_color "$ICyan" "Starting samba..."
update-rc.d smbd defaults
update-rc.d smbd enable
service smbd restart
update-rc.d nmbd enable
service nmbd restart
}

smb_user_menu() {
args=(whiptail --title "$TITLE - $2" --checklist "$1\n$CHECKLIST_GUIDE" "$WT_HEIGHT" "$WT_WIDTH" 4)
USERS=$(members "$SMB_GROUP")
USERS=($USERS)
for user in "${USERS[@]}"
do
    args+=("$user  " "" OFF)
done
selected_options=$("${args[@]}" 3>&1 1>&2 2>&3)
}

choose_password() {
while :
do
    PASSWORD=$(input_box_flow "$1\nThe password has to be at least 12 digits long and contain at least three of those characters each: 'a-z' 'A-Z' '0-9' and ',.-+#'\nYou can cancel by typing in 'exit'.")
    if [ "$PASSWORD" = "exit" ]
    then
        return 1
    elif [ "${#PASSWORD}" -lt 12 ]
    then
        msg_box "Please enter a password with at least 12 digits."
    elif [[ "$PASSWORD" = *" "* ]]
    then
        msg_box "Please don't use spaces."
    elif [[ "$PASSWORD" = *"\\"* ]]
    then
        msg_box "Please don't use backslashes."
    elif ! [[ "$PASSWORD" =~ [a-z].*[a-z].*[a-z] ]]
    then
        msg_box "The password has to contain at least three of those letters: 'a-z'"
    elif ! [[ "$PASSWORD" =~ [A-Z].*[A-Z].*[A-Z] ]]
    then
        msg_box "The password has to contain at least three of those capital letters: 'A-Z'"
    elif ! [[ "$PASSWORD" =~ [0-9].*[0-9].*[0-9] ]]
    then
        msg_box "The password has to contain at least three of those numbers: '0-9'"
    elif ! [[ "$PASSWORD" =~ [-,\.+\#].*[-,\.+\#].*[-,\.+\#] ]]
    then
        msg_box "The password has to contain at least three of those characters: ',.-+#'"
    elif grep -q $(echo -n "$PASSWORD" | sha256sum | awk '{print $1}') "$HASH_HISTORY"
    then
        msg_box "The password was already used. Please use a different one."
    else
        break
    fi
done
}

choose_username() {
local NEWNAME_TRANSLATED
while :
do
    NEWNAME=$(input_box_flow "$1\nAllowed characters are only 'a-z' 'A-Z' '-' and '0-9'. It has to start with a letter.\nIf you want to cancel, just type in 'exit' to exit.")
    if [[ "$NEWNAME" == *" "* ]]
    then
        msg_box "Please don't use spaces"
    elif ! [[ "$NEWNAME" =~ ^[a-zA-Z][-a-zA-Z0-9]+$ ]]
    then
        msg_box "Allowed characters are only 'a-z' 'A-Z '-' and '0-9'. It has to start with a letter."
    elif [ "$NEWNAME" = "exit" ]
    then
        return 1
    elif id "$NEWNAME" &>/dev/null
    then
        msg_box "The user already exists. Please try again."
    elif grep -q "^$NEWNAME:" /etc/group
    then
        msg_box "There is already a group with this name. Please try another one."
    elif echo "${PROHIBITED_NAMES[@]}" | grep -q "$NEWNAME "
    then
        msg_box "Please don't use this name."
    else
        break
    fi
done
}

add_user() {
local NEWNAME_TRANSLATED
local NEXTCLOUD_USERS
if ! grep -q "^$SMB_GROUP:" /etc/group
then
    groupadd "$SMB_GROUP"
fi
if ! choose_username "Please enter the name of the new SMB-user."
then
    return
fi
if ! choose_password "Please type in the password for the new smb-user $NEWNAME"
then
    return
fi
check_command adduser --disabled-password --force-badname --gecos "" "$NEWNAME"
check_command echo -e "$PASSWORD\n$PASSWORD" | smbpasswd -s -a "$NEWNAME"
echo $(echo -n "$PASSWORD" | sha256sum | awk '{print $1}') >> "$HASH_HISTORY"
check_command usermod -aG "$WEB_USER","$SMB_GROUP" "$NEWNAME"
msg_box "The smb-user $NEWNAME was successfully created."
if ! [ -f $NCPATH/occ ]
then
    unset PASSWORD
    return
elif ! yesno_box_no "Do you want to create a Nextcloud user with the same credentials?"
then
    return
fi
NEWNAME_TRANSLATED=$(echo "$NEWNAME" | tr [:upper:] [:lower:])
NEXTCLOUD_USERS=$(occ_command_no_check user:list | sed 's|^  - ||g' | sed 's|:.*||' | tr [:upper:] [:lower:])
if echo "$NEXTCLOUD_USERS" | grep -q "^$NEWNAME_TRANSLATED$"
then
    msg_box "This Nextcloud user already exists. No chance to add it as a user to Nextcloud."
    return
fi 
OC_PASS="$PASSWORD"
unset PASSWORD
export OC_PASS
check_command su -s /bin/sh www-data -c "php $NCPATH/occ user:add $NEWNAME --password-from-env"
unset OC_PASS
msg_box "The Nextcloud user was successfully created."
}

show_user() {
local CACHE
local USERS
local selected_options=""
local SELECTED_USER
local count
local RESULT=""
local SMB_NAME
local SMB_PATH
local TEST=""
local args=""
USERS=$(members "$SMB_GROUP")
USERS=($USERS)
args=(whiptail --title "$TITLE" --menu "Please choose for which user you want to show all shares." "$WT_HEIGHT" "$WT_WIDTH" 4)
for user in "${USERS[@]}"
do
    args+=("$user  " "")
done
selected_options=$("${args[@]}" 3>&1 1>&2 2>&3)
for user in "${USERS[@]}"
do
    if [[ "$selected_options" == *"$user  "* ]]
    then
        SELECTED_USER="$user"
        break
    fi
done
if [ -z "$SELECTED_USER" ]
then
    return
fi
count=1
args=(whiptail --title "$TITLE" --separate-output --checklist "Please choose which shares of $SELECTED_USER you want to show.\n$CHECKLIST_GUIDE" "$WT_HEIGHT" "$WT_WIDTH" 4)
while [ $count -le $MAX_COUNT ]
do 
    CACHE=$(sed -n "/^#SMB$count-start/,/^#SMB$count-end/p" "$SMB_CONF" | grep -v "^#SMB$count-start" | grep -v "^#SMB$count-end" )
    if echo "$CACHE" | grep "valid users = " | grep -q "$SELECTED_USER, "
    then
        SMB_NAME=$(echo "$CACHE" | grep "^\[.*\]$" | tr -d "[]")
        SMB_PATH=$(echo "$CACHE" | grep "path")
        args+=("$SMB_NAME" "$SMB_PATH" OFF)
        TEST+="$SMB_NAME"
    fi
    count=$((count+1))
done
if [ -z "$TEST" ]
then
    msg_box "No share for $SELECTED_USER created. Please create a share first."
    return
fi
selected_options=""
selected_options=$("${args[@]}" 3>&1 1>&2 2>&3)
selected_options=($selected_options)
for element in "${selected_options[@]}"
do
count=1
    while [ $count -le $MAX_COUNT ]
    do
        CACHE=$(sed -n "/^#SMB$count-start/,/^#SMB$count-end/p" "$SMB_CONF" | grep -v "^#SMB$count-start" | grep -v "^#SMB$count-end")
        if echo "$CACHE" | grep -q "\[$element\]"
        then
            msg_box "The shares of $SELECTED_USER:\n\n$CACHE"
        fi
        count=$((count+1))
    done
done
}

change_password() {
local NEXTCLOUD_USERS
smb_user_menu "Please choose for which user you want to change the password."
for user in "${USERS[@]}"
do
    if [[ "$selected_options" == *"$user  "* ]]
    then
        if ! choose_password "Please type in the new password for $user"
        then
            return
        fi
        check_command echo -e "$PASSWORD\n$PASSWORD" | smbpasswd -s -a "$user"
        echo $(echo -n "$PASSWORD" | sha256sum | awk '{print $1}') >> "$HASH_HISTORY"
        msg_box "The password for $user was successfully changed."
        if ! [ -f $NCPATH/occ ]
        then
            unset PASSWORD
            return
        elif ! yesno_box_no "Do you want to change the password of a Nextcloud account with the same name $user to the same password?\nThis most likely only applies, if you created your Nextcloud users with this script.\nPlease not that this will forcefully log out all devices from this user, so it should only be used in case."
        then
            if ! yesno_box_no "Do you really want to do this? It will forcefully log out all devices from this user $user"
            then
                return
            fi
        fi
        NEXTCLOUD_USERS=$(occ_command_no_check user:list | sed 's|^  - ||g' | sed 's|:.*||')
        if ! echo "$NEXTCLOUD_USERS" | grep -q "^$user$"
        then
            msg_box "This user $user doesn't exist in Nextcloud. No chance to change the password of the Nextcloud account."
            return
        fi 
        OC_PASS="$PASSWORD"
        unset PASSWORD
        export OC_PASS
        check_command su -s /bin/sh www-data -c "php $NCPATH/occ user:resetpassword $user --password-from-env"
        unset OC_PASS
        msg_box "The password for the Nextcloud account $user was successful changed."
    fi
done
}

change_username() {
smb_user_menu "Please choose for which user you want to change the username."
for user in "${USERS[@]}"
do
    if [[ "$selected_options" == *"$user  "* ]]
    then
        if ! choose_username "Please enter the new username for $user"
        then
            return
        fi
        samba_stop
        check_command usermod -l "$NEWNAME" "$user"
        check_command groupmod -n "$NEWNAME" "$user"
        check_command sed -i "/valid users = /s/$user, /$NEWNAME, /" "$SMB_CONF"
        samba_start
        msg_box "The username for $user was successfully changed to $NEWNAME."
        break
    fi
done
}

delete_user() {
smb_user_menu "Please choose which users you want to delete.\nPlease note: we will also delete the home of this user (in the '/home' directory). If you don't want to continue just choose none or cancel."
for user in "${USERS[@]}"
do
    if [[ "$selected_options" == *"$user  "* ]]
    then
        samba_stop
        deluser --remove-home "$user"
        check_command sed -i "/valid users = /s/$user, //" "$SMB_CONF"
        samba_start
        msg_box "$user was successfully deleted."
    fi
done
}

user_menu() {
while :
do
    # User menu
    choice=$(whiptail --title "$TITLE - User Menu" --menu "Choose what you want to do." "$WT_HEIGHT" "$WT_WIDTH" 4 \
    "Add a SMB-user" "" \
    "Show all shares from a user" "" \
    "Change the password of SMB-users" "" \
    "Change a username" "" \
    "Delete SMB-users" "" 3>&1 1>&2 2>&3)

    if [ -n "$choice" ] && [ "$choice" != "Add a SMB-user" ] && [ -z "$(members "$SMB_GROUP")" ]
    then
        msg_box "Please create at least one SMB-user before doing anything else."
    else
        case "$choice" in
            "Add a SMB-user")
                add_user
            ;;
            "Show all shares from a user")
                show_user
            ;;
            "Change the password of SMB-users")
                change_password
            ;;
            "Change a username")
                change_username
            ;;
            "Delete SMB-users")
                delete_user
            ;;
            "")
                break
            ;;
            *)
            ;;
        esac
    fi
done 
}

choose_path() {
if [ -z "$DIRECTORIES" ]
then
    msg_box "No directories found that can be used. Please make sure to mount them in '/mnt'."
    return 1
fi
while :
do
    msg_box "Next step you will need to type in the directoy that you want to use.\nHere you can see a certain list of options that you can type in.\n\n$DIRECTORIES"
    NEWPATH=$(input_box_flow "$1.\nIt has to be a directory beginning with '/mnt/'.\nPlease note, that the owner of the directory will be changed to the Web-user.\nIf you don't know any, and you want to cancel, just type in 'exit' to exit.")
    if [[ "$NEWPATH" = *"\\"* ]]
    then
        msg_box "Please don't use backslashes."
    elif [ "$NEWPATH" = "exit" ]
    then
        return 1
    elif ! echo "$NEWPATH" | grep -q "^/mnt/..*"
    then
        msg_box "The path has to be a directory beginning with '/mnt/'."
    elif echo "$NEWPATH" | grep -q "^/mnt/ncdata"
    then
        msg_box "The path isn't allowed to start with '/mnt/ncdata'."
    elif ! [ -d "$NEWPATH" ]
    then
        msg_box "The path doesn't exist. Please try again with a directory that exists."
    # elif grep -q "path = $NEWPATH$" "$SMB_CONF"
    # then
    #     # TODO: think about if this is really needed.
    #     msg_box "The path is already in use. Please try again."
    else
        break
    fi
done
}

choose_users() {
VALID_USERS=""
smb_user_menu "$1\nPlease select at least one user."
if [ -z "$selected_options" ]
then
    return 1
fi
for user in "${USERS[@]}"
do
    if [[ "$selected_options" == *"$user  "* ]]
    then
        VALID_USERS+="$user, "
    fi
done
}

choose_sharename() {
CACHE=$(grep "\[.*\]" "$SMB_CONF" | tr [:upper:] [:lower:])
while :
do
    NEWNAME=$(input_box_flow "$1\nAllowed characters are only 'a-z' 'A-Z' '.-_' and '0-9'. It has to start with a letter.")
    NEWNAME_TRANSLATED=$(echo "$NEWNAME" | tr [:upper:] [:lower:])
    if ! [[ "$NEWNAME" =~ ^[a-zA-Z][-._a-zA-Z0-9]+$ ]]
    then
        msg_box "Allowed characters are only 'a-z' 'A-Z' '.-_' and '0-9'. It has to start with a letter."
    elif echo "$CACHE" | grep -q "\[$NEWNAME_TRANSLATED\]"
    then
        msg_box "The name is already used. Please try another one."
    elif echo "${PROHIBITED_NAMES[@]}" | grep -q "$NEWNAME_TRANSLATED "
    then
        msg_box "Please don't use this name."
    else
        break
    fi
done
}

choose_writeable() {
if yesno_box_yes "$1"
then
    WRITEABLE="yes"
else
    WRITEABLE="no"
fi
}

create_share() {
local MOUNT_ID
local SHARING
local READONLY
local count
local selected_options
local args
local NC_USER
local SELECTED_USER
local SELECTED_GROUPS
local NC_GROUPS
local GROUP
local USER
local NEWNAME_BACKUP
if ! choose_path "Please type in the path you want to create a share for."
then
    return
elif ! choose_users "Please choose the users you want to share the directory $NEWPATH with."
then
    return
fi
choose_sharename "Please enter the name for the new share."
choose_writeable "Shall the new share be writeable?"
count=1
while [ $count -le $MAX_COUNT ]
do
    if ! grep -q ^\#SMB"$count" "$SMB_CONF"
    then
        chmod -R 770 "$NEWPATH"
        chown -R "$WEB_USER":"$WEB_GROUP" "$NEWPATH"
        samba_stop
        cat >> "$SMB_CONF" <<EOF

#SMB$count-start - Please don't remove or change this line
[$NEWNAME]
    path = $NEWPATH
    writeable = $WRITEABLE
;   browseable = yes
    valid users = $VALID_USERS
    force user = $WEB_USER
    force group = $WEB_GROUP
    create mask = 0770
    directory mask = 0771
    force create mode = 0660
    force directory mode = 0770
    vfs objects = recycle
    recycle:repository = .recycle
    recycle:keeptree = yes
    recycle:versions = yes
#SMB$count-end - Please don't remove or change this line
EOF
        samba_start
        break
    else
        count=$((count+1))
    fi
done
if [ $count -gt $MAX_COUNT ]
then
    msg_box "All slots already used."
    return
fi
msg_box "The share $NEWNAME for $NEWPATH was successfully created."
if ! [ -f $NCPATH/occ ]
then
    return
elif ! yesno_box_no "Do you want to mount the directory to Nextcloud as local external storage?"
then
    return
fi
# Install and enable files_external
if ! is_app_enabled files_external
then
    install_and_enable_app files_external
fi
NEWNAME_BACKUP="$NEWNAME"
if yesno_box_no "Do you want to use a different name for this external storage inside Nextcloud or just use the default $NEWNAME?\nThis time spaces are possible."
then
    while :
    do
        NEWNAME=$(input_box_flow "Please enter the name that will be used inside Nextcloud for this share.\nYou can type in exit to use the default $NEWNAME_BACKUP\nAllowed characters are only 'a-z' 'A-Z' '.-_' and '0-9'and spaces. It has to start with a letter.")
        if ! [[ "$NEWNAME" =~ ^[a-zA-Z][-._a-zA-Z0-9\ ]+$ ]]
        then
            msg_box "Please only use those characters. 'a-z' 'A-Z' '.-_' and '0-9'and spaces. It has to start with a letter."
        elif [ "$NEWNAME" = "exit" ]
        then
            NEWNAME="$NEWNAME_BACKUP"
            break
        else
            break
        fi
    done
fi
if [ "$WRITEABLE" = "yes" ]
then
    if ! yesno_box_yes "Do you want to mount this external storage as writeable in your Nextcloud?"
    then
        READONLY="true"
    else
        READONLY="false"
    fi
elif [ "$WRITEABLE" = "no" ]
then
    if ! yesno_box_no "Do you want to mount this external storage as writeable in your Nextcloud?"
    then
        READONLY="true"
    else
        READONLY="false"
    fi
fi
if yesno_box_yes "Do you want to enable sharing for this external storage?"
then
    SHARING="true"
else
    SHARING="false"
fi
# Groups and Usser Menu
choice=$(whiptail --title "$TITLE" --checklist "You can now choose enable the share for specific users or groups.\nPlease note that you cannot come back to this menu.\n$CHECKLIST_GUIDE" "$WT_HEIGHT" "$WT_WIDTH" 4 \
"Choose some Nextcloud groups" "" ON \
"Choose some Nextcloud users" "" ON 3>&1 1>&2 2>&3)
unset SELECTED_USER
unset SELECTED_GROUPS
if [[ "$choice" == *"Choose some Nextcloud groups"* ]]
then
    args=(whiptail --title "$TITLE" --checklist "Please select which groups shall get access to the share.\n$CHECKLIST_GUIDE" "$WT_HEIGHT" "$WT_WIDTH" 4)
    NC_GROUPS=$(occ_command_no_check group:list | grep ".*:$" | sed 's|^  - ||g' | sed 's|:$||g')
    mapfile -t NC_GROUPS <<< "$NC_GROUPS"
    for GROUP in "${NC_GROUPS[@]}"
    do
         args+=("$GROUP  " "" OFF)
    done
    SELECTED_GROUPS=$("${args[@]}" 3>&1 1>&2 2>&3)
fi
if [[ "$choice" == *"Choose some Nextcloud users"* ]]
then
    args=(whiptail --title "$TITLE" --separate-output --checklist "Please select which users shall get access to the share.\n$CHECKLIST_GUIDE" "$WT_HEIGHT" "$WT_WIDTH" 4)
    NC_USER=$(occ_command_no_check user:list | sed 's|^  - ||g' | sed 's|:.*||')
    mapfile -t NC_USER <<< "$NC_USER"
    for USER in "${NC_USER[@]}"
    do
         args+=("$USER  " "" OFF)
    done
    SELECTED_USER=$("${args[@]}" 3>&1 1>&2 2>&3)
fi
# Create and mount external storage to the admin group [not in smbmount]
MOUNT_ID=$(occ_command files_external:create "$NEWNAME" local null::null -c datadir="$NEWPATH" )
MOUNT_ID=${MOUNT_ID//[!0-9]/}
if [ -z "$SELECTED_GROUPS" ] && [ -z "$SELECTED_USER" ]
then
    occ_command files_external:applicable --add-group=admin "$MOUNT_ID" -q
fi
if [ -n "$SELECTED_GROUPS" ]
then
    occ_command_no_check group:list | grep ".*:$" | sed 's|^  - ||g' | sed 's|:$||' | while read -r NC_GROUPS
    do
        if [[ "$SELECTED_GROUPS" = *"$NC_GROUPS  "* ]]
        then
            occ_command files_external:applicable --add-group="$NC_GROUPS" "$MOUNT_ID" -q
        fi
    done
fi
if [ -n "$SELECTED_USER" ]
then
    occ_command_no_check user:list | sed 's|^  - ||g' | sed 's|:.*||' | while read -r NC_USER
    do
        if [[ "$SELECTED_USER" = *"$NC_USER  "* ]]
        then
            occ_command files_external:applicable --add-user="$NC_USER" "$MOUNT_ID" -q
        fi
    done
fi
occ_command files_external:option "$MOUNT_ID" filesystem_check_changes 1
occ_command files_external:option "$MOUNT_ID" readonly "$READONLY"
occ_command files_external:option "$MOUNT_ID" enable_sharing "$SHARING"

# Inform the user that mounting was successful
msg_box "Your mount $NEWNAME was successful, congratulations!
You are now using the Nextcloud external storage app to access files there.
The Share has been mounted to the Nextcloud admin-group if not specifically changed to users or groups.
You can now access 'https://yourdomain-or-ipaddress/settings/admin/externalstorages' to edit external storages in Nextcloud."
}

show_shares() {
local count
local selected_options
local args
local TEST=""
local SMB_NAME
local SMB_PATH
args=(whiptail --title "$TITLE" --separate-output --checklist "Please select which one you want to show.\n$CHECKLIST_GUIDE" "$WT_HEIGHT" "$WT_WIDTH" 4)
count=1
while [ $count -le $MAX_COUNT ]
do
    CACHE=$(sed -n "/^#SMB$count-start/,/^#SMB$count-end/p" "$SMB_CONF")
    if [ -n "$CACHE" ]
    then
        SMB_NAME=$(echo "$CACHE" | grep "^\[.*\]$" | tr -d "[]")
        SMB_PATH=$(echo "$CACHE" | grep "path")
        args+=("$SMB_NAME" "$SMB_PATH" OFF)
        TEST+="$SMB_NAME"
    fi
    count=$((count+1))
done
if [ -z "$TEST" ]
then
    msg_box "No share created. Please create a share first."
    return
fi
selected_options=$("${args[@]}" 3>&1 1>&2 2>&3)
selected_options=($selected_options)
for element in "${selected_options[@]}"
do
count=1
    while [ $count -le $MAX_COUNT ]
    do
        CACHE=$(sed -n "/^#SMB$count-start/,/^#SMB$count-end/p" "$SMB_CONF" | grep -v "^#SMB$count-start" | grep -v "^#SMB$count-end")
        if echo "$CACHE" | grep -q "\[$element\]"
        then
            msg_box "$CACHE"
        fi
        count=$((count+1))
    done
done
}

edit_share() {
local count
local selected_options
local args
local TEST=""
local SMB_NAME
local SMB_PATH
local SELECTED_SHARE
local STORAGE=""
local CLEAN_STORAGE
local MOUNT_ID
args=(whiptail --title "$TITLE" --menu "Please select which one you want to change." "$WT_HEIGHT" "$WT_WIDTH" 4)
count=1
while [ $count -le $MAX_COUNT ]
do
    CACHE=$(sed -n "/^#SMB$count-start/,/^#SMB$count-end/p" "$SMB_CONF")
    if [ -n "$CACHE" ]
    then
        SMB_NAME=$(echo "$CACHE" | grep "^\[.*\]$" | tr -d "[]")
        SMB_PATH=$(echo "$CACHE" | grep "path")
        args+=("$SMB_NAME" "$SMB_PATH")
        TEST+="$SMB_NAME"
    fi
    count=$((count+1))
done
if [ -z "$TEST" ]
then
    msg_box "No share created. Please create a share first."
    return
fi
SELECTED_SHARE=$("${args[@]}" 3>&1 1>&2 2>&3)
if [ -z "$SELECTED_SHARE" ]
then
    return
fi
count=1
while [ $count -le $MAX_COUNT ]
do
    CACHE=$(sed -n "/^#SMB$count-start/,/^#SMB$count-end/p" "$SMB_CONF")
    if echo "$CACHE" | grep -q "\[$SELECTED_SHARE\]"
    then
        STORAGE="$CACHE"
        break
    fi
    count=$((count+1))
done
CLEAN_STORAGE=$(echo "$STORAGE" | grep -v "\#SMB")
msg_box "Those are the current values.\nIn the next step you will be asked what you want to change.\n\n$CLEAN_STORAGE"
choice=$(whiptail --title "$TITLE" --checklist "Please choose what you want to change for $SELECTED_SHARE\n$CHECKLIST_GUIDE" "$WT_HEIGHT" "$WT_WIDTH" 4 \
"Change Share-name" "" OFF \
"Change path" "" OFF \
"Change valid users" "" OFF \
"Change writeable" "" OFF 3>&1 1>&2 2>&3)

case "$choice" in
    *"Change Share-name"*)
        choose_sharename "Please enter the new name of the share."
        STORAGE=$(echo "$STORAGE" | sed "/^\[.*\]$/s/^\[.*\]$/\[$NEWNAME\]/")
    ;;&
    *"Change path"*)
        if ! choose_path "Please type in the new directory that you want to use for that share."
        then
            return
        fi
        chmod -R 770 "$NEWPATH"
        chown -R "$WEB_USER":"$WEB_GROUP" "$NEWPATH"
        NEWPATH=${NEWPATH//\//\\/}
        STORAGE=$(echo "$STORAGE" | sed "/path = /s/path.*/path = $NEWPATH/")
    ;;&
    *"Change valid users"*)
        if ! choose_users "Please choose the users that shall have access to the share."
        then
            return
        fi
        STORAGE=$(echo "$STORAGE" | sed "/valid users = /s/valid users.*/valid users = $VALID_USERS/")
    ;;&
    *"Change writeable"*)
        choose_writeable "Shall the share be writeable?"
        STORAGE=$(echo "$STORAGE" | sed "/writeable = /s/writeable.*/writeable = $WRITEABLE/")
    ;;&
    "")
        return
    ;;
    *)
    ;;
esac
if [ -z "$STORAGE" ]
then
    msg_box "Something is wrong. Plese try again."
    return
fi
CLEAN_STORAGE=$(echo "$STORAGE" | grep -v "\#SMB")
if ! yesno_box_yes "This is how the share will look like from now on.\nIs everything correct?\n\n$CLEAN_STORAGE"
then
    return
fi
samba_stop
count=1
while [ $count -le $MAX_COUNT ]
do
    CACHE=$(sed -n "/^#SMB$count-start/,/^#SMB$count-end/p" "$SMB_CONF")
    if echo "$CACHE" | grep -q "\[$SELECTED_SHARE\]"
    then
        sed -i "/^#SMB$count-start/,/^#SMB$count-end/d" "$SMB_CONF"
        break
    fi
    count=$((count+1))
done
echo -e "\n$STORAGE" >> "$SMB_CONF"
samba_start
msg_box "Share was changed successfully."
}

delete_share() {
local args
local selected_options
local CACHE
local SMB_NAME
local SMB_PATH
local count
local TEST=""
args=(whiptail --title "$TITLE" --separate-output --checklist "Please select which one you want to delete.\n$CHECKLIST_GUIDE" "$WT_HEIGHT" "$WT_WIDTH" 4)
count=1
while [ $count -le $MAX_COUNT ]
do 
    CACHE=$(sed -n "/^#SMB$count-start/,/^#SMB$count-end/p" "$SMB_CONF")
    if echo "$CACHE" | grep -q "path = "
    then
        SMB_NAME=$(echo "$CACHE" | grep "^\[.*\]$" | tr -d "[]")
        SMB_PATH=$(echo "$CACHE" | grep "path")
        args+=("$SMB_NAME" "$SMB_PATH" OFF)
        TEST+="$SMB_NAME"
    fi
    count=$((count+1))
done
if [ -z "$TEST" ]
then
    msg_box "No share created. Please create a share first."
    return
fi
selected_options=$("${args[@]}" 3>&1 1>&2 2>&3)
selected_options=($selected_options)
for element in "${selected_options[@]}"
do
count=1
    while [ $count -le $MAX_COUNT ]
    do 
        CACHE=$(sed -n "/^#SMB$count-start/,/^#SMB$count-end/p" "$SMB_CONF")
        if echo "$CACHE" | grep -q "\[$element\]"
        then
            samba_stop
            sed -i "/^#SMB$count-start/,/^#SMB$count-end/d" "$SMB_CONF"
            samba_start
            msg_box "$element was succesfully deleted."
            break
        fi
        count=$((count+1))
    done
done
}

share_menu() {
if [ -z "$(members "$SMB_GROUP")" ]
then
    msg_box "Please create at least one SMB-user before creating a share." "Share Menu"
    return
fi
while :
do
    # Share menu
    choice=$(whiptail --title "$TITLE - Share Menu" --menu "Choose what you want to do." "$WT_HEIGHT" "$WT_WIDTH" 4 \
    "Create SMB-share" "" \
    "Show SMB-shares" "" \
    "Edit a SMB-share" "" \
    "Delete SMB-share" "" 3>&1 1>&2 2>&3)

    case "$choice" in
        "Create SMB-share")
            create_share
        ;;
        "Show SMB-shares")
            show_shares
        ;;
        "Edit a SMB-share")
            edit_share
        ;;
        "Delete SMB-share")
            delete_share
        ;;
        "")
            break
        ;;
        *)
        ;;
    esac
done  
}

while :
do
    # Main menu
    choice=$(whiptail --title "$TITLE - Main Menu" --menu "Choose what you want to do." "$WT_HEIGHT" "$WT_WIDTH" 4 \
    "Open the SMB-user-menu" "" \
    "Open the Share-menu" "" 3>&1 1>&2 2>&3)

    case "$choice" in
        "Open the SMB-user-menu")
            user_menu
        ;;
        "Open the Share-menu")
            share_menu
        ;;
        "")
            break
        ;;
        *)
        ;;
    esac
done

exit
