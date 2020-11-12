#!/bin/bash

# T&M Hansson IT AB © - 2020, https://www.hanssonit.se/
# Copyright © 2020 Simon Lindner (https://github.com/szaimen)

true
SCRIPT_NAME="SMB Server"
SCRIPT_EXPLAINER="This script allows you to create a SMB-server from your Nextcloud-VM.
It helps you manage all SMB-users and SMB-shares.
As bonus feature you can automatically mount the chosen directories to Nextcloud and \
create Nextcloud users with the same credentials like your SMB-users."
# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh || source <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Check if root
root_check

# Variables
SMB_CONF="/etc/samba/smb.conf"
SMB_GROUP="smb-users"
PROHIBITED_NAMES=(global homes netlogon profiles printers print$ root ncadmin "$SMB_GROUP" plex pi-hole placeholder_for_last_space)
WEB_GROUP="www-data"
WEB_USER="www-data"
MAX_COUNT=16

# Install whiptail if not already
install_if_not whiptail

# Check MAX_COUNT
if ! [ $MAX_COUNT -gt 0 ]
then
    msg_box "The MAX_COUNT variable has to be a positive integer, greater than 0. Please change it accordingly. \
    Recommended is MAX_COUNT=16, because not all menus work reliably with a higher count."
    exit
fi

# Show install_popup
if ! is_this_installed samba
then
    # Ask for installing
    install_popup "$SCRIPT_NAME"
fi

# Find mounts
DIRECTORIES=$(find /mnt/ -mindepth 1 -maxdepth 2 -type d | grep -v "/mnt/ncdata")
mapfile -t DIRECTORIES <<< "$DIRECTORIES"
for directory in "${DIRECTORIES[@]}"
do
    if mountpoint -q "$directory"
    then
        MOUNTS+=("$directory/")
    fi
done
if [ -z "${MOUNTS[*]}" ]
then
    msg_box "No usable drive found. You have to mount a new drive in /mnt."
    exit 1
fi

# Install all needed tools
install_if_not samba
install_if_not members

# Use SMB3
if ! grep -q "^protocol" "$SMB_CONF"
then
    sed -i '/\[global\]/a protocol = SMB3' "$SMB_CONF"
else
    sed -i 's|^protocol =.*|protocol = SMB3|' "$SMB_CONF"
fi

# Hide SMB-shares from SMB-users that have no read permission
if ! grep -q "access based share enum" "$SMB_CONF"
then
    sed -i '/\[global\]/a access based share enum = yes' "$SMB_CONF"
else
    sed -i 's|.*access based share enum =.*|access based share enum = yes|' "$SMB_CONF"
fi

# Activate encrypted transfer if AES-NI is enabled (passwords are encrypted by default)
install_if_not cpuid
if cpuid | grep " AES" | grep -q true
then
    if ! grep -q "^smb encrypt =" "$SMB_CONF"
    then
        sed -i '/\[global\]/a smb encrypt = desired' "$SMB_CONF"
    else
        sed -i 's|^smb encrypt =.*|smb encrypt = desired|' "$SMB_CONF"
    fi
fi

# Disable the [homes] share by default only if active
if grep -q "^\[homes\]" "$SMB_CONF"
then
    msg_box "We will disable the SMB-users home-shares since they are not existing."
    sed -i 's|^\[homes\]|\;\[homes\]|' "$SMB_CONF"
fi

# Samba stop function
samba_stop() {
    print_text_in_color "$ICyan" "Stopping the SMB-server..."
    service smbd stop
    update-rc.d smbd disable
    update-rc.d nmbd disable
}

# Samba start function
samba_start() {
    print_text_in_color "$ICyan" "Starting the SMB-server..."
    update-rc.d smbd defaults
    update-rc.d smbd enable
    service smbd restart
    update-rc.d nmbd enable
    service nmbd restart
}

# Choose from a list of SMB-user
smb_user_menu() {
    args=(whiptail --title "$TITLE - $2" --checklist \
"$1
$CHECKLIST_GUIDE" "$WT_HEIGHT" "$WT_WIDTH" 4)
    USERS=$(members "$SMB_GROUP")
    read -r -a USERS <<< "$USERS"
    for user in "${USERS[@]}"
    do
        args+=("$user  " "" OFF)
    done
    selected_options=$("${args[@]}" 3>&1 1>&2 2>&3)
}

# Choose a correct password
choose_password() {
while :
do
    PASSWORD=$(input_box_flow "$1
You can cancel by typing in 'exit' and pressing [ENTER]." "$2")
    if [ "$PASSWORD" = "exit" ]
    then
        return 1
    elif [[ "$PASSWORD" = *" "* ]]
    then
        msg_box "Please don't use spaces." "$2"
    elif [[ "$PASSWORD" = *"\\"* ]]
    then
        msg_box "Please don't use backslashes." "$2"
    else
        break
    fi
done
}

# Choose a correct username
choose_username() {
local NEWNAME_TRANSLATED
while :
do
    NEWNAME=$(input_box_flow "$1\nAllowed characters are only 'a-z' 'A-Z' '-' and '0-9'.
Also, the username needs to start with a letter to be valid.
If you want to cancel, just type in 'exit' and press [ENTER]." "$2")
    if [[ "$NEWNAME" == *" "* ]]
    then
        msg_box "Please don't use spaces." "$2"
    elif ! [[ "$NEWNAME" =~ ^[a-zA-Z][-a-zA-Z0-9]+$ ]]
    then
        msg_box "Allowed characters are only 'a-z' 'A-Z '-' and '0-9'.
Also, the username needs to start with a letter to be valid." "$2"
    elif [ "$NEWNAME" = "exit" ]
    then
        return 1
    elif id "$NEWNAME" &>/dev/null
    then
        msg_box "The user already exists. Please try again." "$2"
    elif grep -q "^$NEWNAME:" /etc/group
    then
        msg_box "There is already a group with this name. Please try another one." "$2"
    elif echo "${PROHIBITED_NAMES[@]}" | grep -q "$NEWNAME "
    then
        msg_box "Please don't use this name." "$2"
    else
        break
    fi
done
}

# Add a SMB-user
add_user() {
    local NEWNAME_TRANSLATED
    local NEXTCLOUD_USERS
    local HASH
    local SUBTITLE="Add a SMB-user"

    # Add the SMB-group as soon as trying to create a SMB-user
    if ! grep -q "^$SMB_GROUP:" /etc/group
    then
        groupadd "$SMB_GROUP"
    fi

    # Choose the username
    if ! choose_username "Please enter the name of the new SMB-user." "$SUBTITLE"
    then
        return
    fi

    # Choose the password
    if ! choose_password "Please type in the password for the new smb-user $NEWNAME" "$SUBTITLE"
    then
        return
    fi

    # Create the user if everything is correct
    check_command adduser --no-create-home --quiet --disabled-login --force-badname --gecos "" "$NEWNAME"
    check_command echo -e "$PASSWORD\n$PASSWORD" | smbpasswd -s -a "$NEWNAME"

    # Modify the groups of the SMB-user
    check_command usermod --append --groups "$SMB_GROUP","$WEB_GROUP" "$NEWNAME"

    # Inform the user
    msg_box "The smb-user $NEWNAME was successfully created.
    
If this is the first SMB-user, that you have created, you should be able to create a new SMB-share now by \
returning to the Main Menu of this script and choosing from there 'SMB-share Menu' -> 'create a SMB-share'.
Suggested is though, creating all needed SMB-users first." "$SUBTITLE"

    # Test if NC exists
    if ! [ -f $NCPATH/occ ]
    then
        unset PASSWORD
        return
    # If NC exists, offer to create a NC  user
    elif ! yesno_box_no "Do you want to create a Nextcloud user with the same credentials?
Please note that this option could be a security risk, if the chosen password was too simple." "$SUBTITLE"
    then
        return
    fi

    # Check if the user already exists
    NEWNAME_TRANSLATED=$(echo "$NEWNAME" | tr "[:upper:]" "[:lower:]")
    NEXTCLOUD_USERS=$(nextcloud_occ_no_check user:list | sed 's|^  - ||g' | sed 's|:.*||' | tr "[:upper:]" "[:lower:]")
    if echo "$NEXTCLOUD_USERS" | grep -q "^$NEWNAME_TRANSLATED$"
    then
        msg_box "This Nextcloud user already exists. No chance to add it as a user to Nextcloud." "$SUBTITLE"
        return
    fi 

    # Create the NC user, if it not already exists
    OC_PASS="$PASSWORD"
    unset PASSWORD
    export OC_PASS
    check_command su -s /bin/sh www-data -c "php $NCPATH/occ user:add $NEWNAME --password-from-env"
    unset OC_PASS

    # Inform the user
    msg_box "The new Nextcloud user $NEWNAME was successfully created." "$SUBTITLE"
}

# Show all SMB-shares from a SMB-user
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
    local args
    unset args
    USERS=$(members "$SMB_GROUP")
    read -r -a USERS <<< "$USERS"
    local SUBTITLE="Show all SMB-shares from a SMB-user"

    # Choose from a list of SMB-users
    args=(whiptail --title "$TITLE - $SUBTITLE" --menu \
"Please choose for which SMB-user you want to show all SMB-shares.
$MENU_GUIDE" "$WT_HEIGHT" "$WT_WIDTH" 4)
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

    # Return if none chosen
    if [ -z "$SELECTED_USER" ]
    then
        return
    fi

    # Show if list with SMB-shares of the chosen SMB-user
    count=1
    args=(whiptail --title "$TITLE - $SUBTITLE" --separate-output --checklist \
"Please choose which shares of $SELECTED_USER you want to show.
$CHECKLIST_GUIDE" "$WT_HEIGHT" "$WT_WIDTH" 4)
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

    # Return if no share for that user created
    if [ -z "$TEST" ]
    then
        msg_box "No share for $SELECTED_USER created. Please create a share first." "$SUBTITLE"
        return
    fi

    # Show a msg_box with each SMB-share that was selected
    unset selected_options
    selected_options=$("${args[@]}" 3>&1 1>&2 2>&3)
    mapfile -t selected_options <<< "$selected_options"
    for element in "${selected_options[@]}"
    do
    count=1
        while [ $count -le $MAX_COUNT ]
        do
            CACHE=$(sed -n "/^#SMB$count-start/,/^#SMB$count-end/p" "$SMB_CONF" | grep -v "^#SMB$count-start" | grep -v "^#SMB$count-end")
            if echo "$CACHE" | grep -q "\[$element\]"
            then
                msg_box "The shares of $SELECTED_USER:\n\n$CACHE" "$SUBTITLE"
            fi
            count=$((count+1))
        done
    done
}

# Change the password of SMB-users
change_password() {
local NEXTCLOUD_USERS
local HASH
local SUBTITLE="Change the password of SMB-users"

# Show a list with SMB-users
smb_user_menu "Please choose for which user you want to change the password." "$SUBTITLE"
for user in "${USERS[@]}"
do
    if [[ "${selected_options[*]}" == *"$user  "* ]]
    then
        # Type in the new password of the chosen SMB-user
        if ! choose_password "Please type in the new password for $user" "$SUBTITLE"
        then
            continue
        fi

        # Change it to the new one if correct
        check_command echo -e "$PASSWORD\n$PASSWORD" | smbpasswd -s -a "$user"
        HASH="$(echo -n "$PASSWORD" | sha256sum | awk '{print $1}')"
        echo "$HASH" >> "$HASH_HISTORY"

        # Inform the user
        msg_box "The password for $user was successfully changed." "$SUBTITLE"
        if ! [ -f $NCPATH/occ ]
        then
            unset PASSWORD
            continue
        # Offer the possibility to change the password of the same NC user, if existing, too
        elif yesno_box_no "Do you want to change the password of a Nextcloud account with the same name $user \
to the same password?\nThis most likely only applies, if you created your Nextcloud users with this script.
Please not that this will forcefully log out all devices from this user, so it should only be used in case." "$SUBTITLE"
        then
            # Warn about consequences
            if ! yesno_box_no "Do you really want to do this? It will \
forcefully log out all devices from this Nextcloud user $user" "$SUBTITLE"
            then
                continue
            fi
        else
            continue
        fi

        # Check if a NC account with the same name exists
        NEXTCLOUD_USERS=$(nextcloud_occ_no_check user:list | sed 's|^  - ||g' | sed 's|:.*||')
        if ! echo "$NEXTCLOUD_USERS" | grep -q "^$user$"
        then
            msg_box "There doesn't exist any user with this name $user in Nextcloud. \
No chance to change the password of the Nextcloud account." "$SUBTITLE"
            continue
        fi 

        # Change the password of the NC account if existing
        OC_PASS="$PASSWORD"
        unset PASSWORD
        export OC_PASS
        check_command su -s /bin/sh www-data -c "php $NCPATH/occ user:resetpassword $user --password-from-env"
        unset OC_PASS

        # Inform the user
        msg_box "The password for the Nextcloud account $user was successful changed." "$SUBTITLE"
    fi
done
}

# Change the username of a SMB-user
change_username() {
local SUBTITLE="Change the username of a SMB-user"
# Show a list with SMB-user
smb_user_menu "Please choose for which SMB-user you want to change the username." "$SUBTITLE"
for user in "${USERS[@]}"
do
    if [[ "${selected_options[*]}" == *"$user  "* ]]
    then
        # Ask for a new username for the chosen SMB-user
        if ! choose_username "Please enter the new username for $user" "$SUBTITLE"
        then
            continue
        fi

        # Apply it if everything correct
        samba_stop
        check_command usermod -l "$NEWNAME" "$user"
        check_command groupmod -n "$NEWNAME" "$user"
        check_command sed -i "/valid users = /s/$user, /$NEWNAME, /" "$SMB_CONF"
        samba_start

        # Inform the user
        msg_box "The username for $user was successfully changed to $NEWNAME." "$SUBTITLE"
        continue
    fi
done
}

# Delete SMB-users
delete_user() {
local SUBTITLE="Delete SMB-users"
# Show a list with SMB-user
smb_user_menu "Please choose which SMB-users you want to delete." "$SUBTITLE"
for user in "${USERS[@]}"
do
    if [[ "${selected_options[*]}" == *"$user  "* ]]
    then
        # Delete all chosen SMB-user
        samba_stop
        check_command deluser --quiet "$user"
        check_command sed -i "/valid users = /s/$user, //" "$SMB_CONF"
        samba_start

        # Inform the user
        msg_box "$user was successfully deleted." "$SUBTITLE"
    fi
done
}

# User menu
user_menu() {
while :
do
    choice=$(whiptail --title "$TITLE - SMB-user Menu" --menu \
"Choose what you want to do.
$MENU_GUIDE" "$WT_HEIGHT" "$WT_WIDTH" 4 \
"Add a SMB-user" "" \
"Show all SMB-shares from a SMB-user" "" \
"Change the password of SMB-users" "" \
"Change the username of SMB-users" "" \
"Delete SMB-users" "" \
"Return to the Main Menu" "" 3>&1 1>&2 2>&3)

    if [ -n "$choice" ] && [ "$choice" != "Add a SMB-user" ] && [ "$choice" != "Return to the Main Menu" ] && [ -z "$(members "$SMB_GROUP")" ]
    then
        msg_box "Please create at least one SMB-user before doing anything else."
    else
        case "$choice" in
            "Add a SMB-user")
                add_user
            ;;
            "Show all SMB-shares from a SMB-user")
                show_user
            ;;
            "Change the password of SMB-users")
                change_password
            ;;
            "Change the username of SMB-users")
                change_username
            ;;
            "Delete SMB-users")
                delete_user
            ;;
            "Return to the Main Menu")
                break
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

# Choose the path for a SMB-share
choose_path() {
local VALID_DIRS
local VALID
local mount
local LOCALDIRECTORIES

# Find usable directories
LOCALDIRECTORIES=$(find /mnt/ -mindepth 1 -maxdepth 3 -type d | grep -v "/mnt/ncdata")
for mount in "${MOUNTS[@]}"
do
    VALID_DIRS+="$mount\n"
    VALID_DIRS+="$(echo -e "$LOCALDIRECTORIES" | grep "^$mount")\n"
done
while :
do
    msg_box "In the following step you will need to type in the directoy that you want to use.
Here you can see a certain list of options that you can type in.\n\n$VALID_DIRS" "$2"
    
    # Type in the new path
    NEWPATH=$(input_box_flow "$1.Please note, that the owner of the directory will be changed to the Web-user.
If you don't know any, and you want to cancel, just type in 'exit' and press [ENTER]." "$2")
    unset VALID
    for mount in "${MOUNTS[@]}"
    do
        if echo "$NEWPATH" | grep -q "^$mount"
        then
            VALID=1
        fi
    done
    if [ "$NEWPATH" = "exit" ]
    then
        return 1
    elif [ -z "$VALID" ]
    then
        msg_box "This path isn't valid. Please try a different one. It has to be a directory on a mount." "$2"
    elif ! [ -d "$NEWPATH" ]
    then
        if yesno_box_no "The path doesn't exist. Do you want to create it?" "$2"
        then
            check_command mkdir -p "$NEWPATH"
            break
        fi
    else
        break
    fi
done
}

# Define valid SMB-users
choose_users() {
VALID_USERS=""
smb_user_menu "$1\nPlease select at least one SMB-user." "$2"
if [ -z "${selected_options[*]}" ]
then
    return 1
fi
for user in "${USERS[@]}"
do
    if [[ "${selected_options[*]}" == *"$user  "* ]]
    then
        VALID_USERS+="$user, "
    fi
done
}

# Choose a sharename
choose_sharename() {
CACHE=$(grep "\[.*\]" "$SMB_CONF" | tr "[:upper:]" "[:lower:]")
while :
do
    # Type in the new sharename
    NEWNAME=$(input_box_flow "$1\nAllowed characters are only those three special characters \
'.-_' and 'a-z' 'A-Z' '0-9'.\nAlso, the sharename needs to start with a letter 'a-z' or 'A-Z' to be valid.
If you want to cancel, just type in 'exit' and press [ENTER]." "$2")
    NEWNAME_TRANSLATED=$(echo "$NEWNAME" | tr "[:upper:]" "[:lower:]")
    if [[ "$NEWNAME" = *" "* ]]
    then
        msg_box "Please don't use spaces." "$2"
    elif ! echo "$NEWNAME" | grep -q "^[a-zA-Z]"
    then
        msg_box "The sharename has to start with a letter 'a-z' or 'A-Z' to be valid." "$2"
    elif [ "$NEWNAME" = "exit" ]
    then
        return 1
    elif ! [[ "$NEWNAME" =~ ^[-._a-zA-Z0-9]+$ ]]
    then
        msg_box "Allowed characters are only those three special characters '.-_' and 'a-z' 'A-Z' '0-9'." "$2"
    elif echo "$CACHE" | grep -q "\[$NEWNAME_TRANSLATED\]"
    then
        msg_box "This sharename is already used. Please try another one." "$2"
    elif echo "${PROHIBITED_NAMES[@]}" | grep -q "$NEWNAME_TRANSLATED "
    then
        msg_box "Please don't use this name." "$2"
    else
        break
    fi
done
}

# Choose if the share shall be writeable
choose_writeable() {
if yesno_box_yes "$1" "$2"
then
    WRITEABLE="yes"
else
    WRITEABLE="no"
fi
}

# Create a SMB-share
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
    local SUBTITLE="Create a SMB-share"

    # Choose the path
    if ! choose_path "Please type in the path you want to create a SMB-share for." "$SUBTITLE"
    then
        return
    fi

    # Choose a sharename
    if ! choose_sharename "Please enter a name for the new SMB-share $NEWPATH." "$SUBTITLE"
    then
        return
    fi

    # Choose the valid SMB-users
    if ! choose_users "Please choose the SMB-users you want to share the new SMB-share $NEWNAME with." "$SUBTITLE"
    then
        return
    fi

    # Choose if it shall be writeable
    choose_writeable "Shall the new SMB-share $NEWNAME be writeable?" "$SUBTITLE"

    # Apply that setting for an empty space
    count=1
    while [ $count -le $MAX_COUNT ]
    do
        if ! grep -q ^\#SMB"$count" "$SMB_CONF"
        then
            # Correct the ACL
            chmod -R 770 "$NEWPATH"
            if [ "$(stat -c %a "$NEWPATH")" != "770" ]
            then
                msg_box "Something went wrong. Couldn't set the correct mod permissions for the location." "$SUBTITLE"
                return 1
            fi
            chown -R "$WEB_USER":"$WEB_GROUP" "$NEWPATH"
            if [ "$(stat -c %G "$NEWPATH")" != "$WEB_GROUP" ] || [ "$(stat -c %U "$NEWPATH")" != "$WEB_USER" ]
            then
                msg_box "Something went wrong. Couldn't set the correct own permissions for the location." "$SUBTITLE"
                return 1
            fi
            
            # Write all settings to SMB-conf
            samba_stop
            cat >> "$SMB_CONF" <<EOF

#SMB$count-start - Please don't remove or change this line
[$NEWNAME]
    path = $NEWPATH
    writeable = $WRITEABLE
    valid users = $VALID_USERS
    force user = $WEB_USER
    force group = $WEB_GROUP
    create mask = 0770
    directory mask = 0770
    force create mode = 0770
    force directory mode = 0770
    vfs objects = recycle
    recycle:repository = .recycle
    recycle:keeptree = yes
    recycle:versions = yes
    recycle:directory_mode = 0770
#SMB$count-end - Please don't remove or change this line
EOF
            samba_start
            break
        else
            count=$((count+1))
        fi
    done

    # Test if all slots are used
    if [ $count -gt $MAX_COUNT ]
    then
        msg_box "All slots are already used." "$SUBTITLE"
        return
    fi

    # Inform the user
    msg_box "The SMB-share $NEWNAME for $NEWPATH was successfully created.

You should be able to connect with the credentials of the chosen SMB-user(s) to the SMB-server now
to see all for the specific SMB-user available SMB-shares:
- On Linux in a file manager using this address: 'smb://$ADDRESS'
- On Windows in the Windows Explorer using this address: '\\\\$ADDRESS'
- On macOS in the Finder (press 'cmd + K') using this address: 'smb://$ADDRESS'" "$SUBTITLE"

    # Test if NC exists
    if ! [ -f $NCPATH/occ ]
    then
        return
    # Ask if the same directory shall get mounted as external storage to NC
    elif ! yesno_box_no "Do you want to mount the directory $NEWPATH to Nextcloud as local external storage?" "$SUBTITLE"
    then
        return
    fi

    # Install and enable files_external
    if ! is_app_enabled files_external
    then
        install_and_enable_app files_external
    fi

    # Safe NEWNAME in a backup variable
    NEWNAME_BACKUP="$NEWNAME"

    # Ask if the default name can be used
    if yesno_box_no "Do you want to use a different name for this external storage inside Nextcloud or \
just use the default sharename $NEWNAME?\nThis time spaces are possible." "$SUBTITLE"
    then
        while :
        do
            # Type in the new mountname that will be used in NC
            NEWNAME=$(input_box_flow "Please enter the name that will be used inside Nextcloud for this path $NEWPATH.
You can type in 'exit' and press [ENTER] to use the default $NEWNAME_BACKUP
Allowed characters are only spaces, those four special characters '.-_/' and 'a-z' 'A-Z' '0-9'.
Also, it has to start with a slash '/' or a letter 'a-z' or 'A-Z' to be valid.
Advice: you can declare a directory as the Nextcloud users root storage by naming it '/'."  "$SUBTITLE")
            if ! echo "$NEWNAME" | grep -q "^[a-zA-Z/]"
            then
                msg_box "The name has to start with a slash '/' or a letter 'a-z' or 'A-Z' to be valid." "$SUBTITLE"
            elif ! [[ "$NEWNAME" =~ ^[-._a-zA-Z0-9\ /]+$ ]]
            then
                msg_box "Allowed characters are only spaces, those \
four special characters '.-_/' and 'a-z' 'A-Z' '0-9'." "$SUBTITLE"
            elif [ "$NEWNAME" = "exit" ]
            then
                NEWNAME="$NEWNAME_BACKUP"
                break
            else
                break
            fi
        done
    fi

    # Choose if it shall be writeable in NC
    if [ "$WRITEABLE" = "yes" ]
    then
        if ! yesno_box_yes "Do you want to mount this new \
external storage $NEWNAME as writeable in your Nextcloud?" "$SUBTITLE"
        then
            READONLY="true"
        else
            READONLY="false"
        fi
    elif [ "$WRITEABLE" = "no" ]
    then
        if ! yesno_box_no "Do you want to mount this new \
external storage $NEWNAME as writeable in your Nextcloud?" "$SUBTITLE"
        then
            READONLY="true"
        else
            READONLY="false"
        fi
    fi

    # Choose if sharing shall get enabled for that mount
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

    # Select NC groups and/or users
    choice=$(whiptail --title "$TITLE - $SUBTITLE" --checklist \
"You can now choose to enable the this external storage $NEWNAME for specific Nextcloud users or groups.
If you select no group and no user, the external storage will be visible to all users of your instance.
Please note that you cannot come back to this menu.
$CHECKLIST_GUIDE" "$WT_HEIGHT" "$WT_WIDTH" 4 \
"Choose some Nextcloud groups" "" ON \
"Choose some Nextcloud users" "" OFF 3>&1 1>&2 2>&3)
    unset SELECTED_USER
    unset SELECTED_GROUPS

    # Choose from NC groups
    if [[ "$choice" == *"Choose some Nextcloud groups"* ]]
    then
        args=(whiptail --title "$TITLE - $SUBTITLE" --checklist \
"Please select which Nextcloud groups shall get access to the new external storage $NEWNAME.
If you select no group and no user, the external storage will be visible to all users of your instance.
$CHECKLIST_GUIDE" "$WT_HEIGHT" "$WT_WIDTH" 4)
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

    # Choose from NC users
    if [[ "$choice" == *"Choose some Nextcloud users"* ]]
    then
        args=(whiptail --title "$TITLE - $SUBTITLE" --separate-output --checklist \
"Please select which Nextcloud users shall get access to the new external storage $NEWNAME.
If you select no group and no user, the external storage will be visible to all users of your instance.
$CHECKLIST_GUIDE" "$WT_HEIGHT" "$WT_WIDTH" 4)
        NC_USER=$(nextcloud_occ_no_check user:list | sed 's|^  - ||g' | sed 's|:.*||')
        mapfile -t NC_USER <<< "$NC_USER"
        for USER in "${NC_USER[@]}"
        do
            args+=("$USER  " "" OFF)
        done
        SELECTED_USER=$("${args[@]}" 3>&1 1>&2 2>&3)
    fi

    # Create and mount external storage
    MOUNT_ID=$(nextcloud_occ files_external:create "$NEWNAME" local null::null -c datadir="$NEWPATH" )
    MOUNT_ID=${MOUNT_ID//[!0-9]/}

    # Mount it to the admin group if no group or user chosen
    if [ -z "$SELECTED_GROUPS" ] && [ -z "$SELECTED_USER" ]
    then
        if ! yesno_box_no "Attention! You haven't selected any Nextcloud group or user.
Is this correct?\nIf you select 'yes', it will be visible to all users of your Nextcloud instance.
If you select 'no', it will be only visible to Nextcloud users in the admin group." "$SUBTITLE"
        then
            nextcloud_occ files_external:applicable --add-group=admin "$MOUNT_ID" -q
        fi
    fi

    # Mount it to selected groups
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

    # Mount it to selected users
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

    # Set up all other settings
    nextcloud_occ files_external:option "$MOUNT_ID" filesystem_check_changes 1
    nextcloud_occ files_external:option "$MOUNT_ID" readonly "$READONLY"
    nextcloud_occ files_external:option "$MOUNT_ID" enable_sharing "$SHARING"

    # Inform the user that mounting was successful
    msg_box "Your mount $NEWNAME was successful, congratulations!
You are now using the Nextcloud external storage app to access files there.
The Share has been mounted to the Nextcloud admin-group if not specifically changed to users or groups.
You can now access 'https://yourdomain-or-ipaddress/settings/admin/externalstorages' \
to edit external storages in Nextcloud." "$SUBTITLE"

    # Inform the user that he can setup inotify for this external storage
    if ! yesno_box_no "Do you want to enable inotify for this external storage in Nextcloud?
It is only recommended if the content can get changed externally and \
will let Nextcloud track if this external storage was externally changed.
If you choose 'yes', we will install a needed PHP-plugin, the files_inotify app and create a cronjob for you."
    then
        return
    fi

    # Warn a second time
    if ! yesno_box_no "Are you sure, that you want to enable inotify for this external storage?
Please note, that this will need around 1 KB additonal RAM per folder.
We will set the max folder variable to 524288 which will be around 500 MB \
of additionally needed RAM if you have so many folders.
If you have more folders, you will need to raise this value manually inside '/etc/sysctl.conf'.
Please also note, that this max folder variable counts for all \
external storages for which the inotify option gets activated.
We please you to do the math yourself if the number is high enough for your setup."
    then
        return
    fi

    # Install the inotify PHP extension
    # https://github.com/icewind1991/files_inotify/blob/master/README.md
    if ! pecl list | grep -q inotify
    then 
        print_text_in_color "$ICyan" "Installing the PHP inotify extension..."
        yes no | pecl install inotify
        local INOTIFY_INSTALL=1
    fi
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
files_inotify app and setup the cronjob for this external storage."
        then
            return
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
            return
        fi
    fi
    
    # Make sure that the app is enabled, too
    if ! is_app_enabled files_inotify
    then
        nextcloud_occ_no_check app:enable files_inotify
    fi

    # Add crontab for this external storage
    print_text_in_color "$ICyan" "Generating crontab..."
    crontab -u www-data -l | { cat; echo "@reboot sleep 20 && php -f $NCPATH/occ files_external:notify -v $MOUNT_ID >> $VMLOGS/files_inotify.log"; } | crontab -u www-data -

    # Run the command in a subshell and don't exit if the smbmount script exits
    nohup sudo -u www-data php "$NCPATH"/occ files_external:notify -v "$MOUNT_ID" >> $VMLOGS/files_inotify.log &
    
    # Inform the user
    msg_box "Congratulations, everything was successfully installed and setup.

Please note that there are some known issues with this inotify option.
It could happen that it doesn't work as expected.
Please look at this issue for further information:
https://github.com/icewind1991/files_inotify/issues/16"
}

# Show SMB-shares
show_shares() {
    local count
    local selected_options
    local args
    local TEST=""
    local SMB_NAME
    local SMB_PATH
    local SUBTITLE="Show SMB-shares"

    # Show a list with available SMB-shares
    args=(whiptail --title "$TITLE - $SUBTITLE" --separate-output --checklist \
"Please select which SMB-shares you want to show.
$CHECKLIST_GUIDE" "$WT_HEIGHT" "$WT_WIDTH" 4)
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

    # Return if none created
    if [ -z "$TEST" ]
    then
        msg_box "No SMB-share created. Please create a SMB-share first." "$SUBTITLE"
        return
    fi

    # Show selected shares
    selected_options=$("${args[@]}" 3>&1 1>&2 2>&3)
    mapfile -t selected_options <<< "$selected_options"
    for element in "${selected_options[@]}"
    do
    count=1
        while [ $count -le $MAX_COUNT ]
        do
            CACHE=$(sed -n "/^#SMB$count-start/,/^#SMB$count-end/p" "$SMB_CONF" | grep -v "^#SMB$count-start" | grep -v "^#SMB$count-end")
            if echo "$CACHE" | grep -q "\[$element\]"
            then
                msg_box "$CACHE" "$SUBTITLE"
            fi
            count=$((count+1))
        done
    done
}

# Edit a SMB-share
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
    local SUBTITLE="Edit a SMB-share"

    # Show a list of SMB-shares
    args=(whiptail --title "$TITLE - $SUBTITLE" --menu \
"Please select which SMB-share you want to change.
$MENU_GUIDE" "$WT_HEIGHT" "$WT_WIDTH" 4)
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

    # Return if no share created
    if [ -z "$TEST" ]
    then
        msg_box "No SMB-shares created. Please create a SMB-share first." "$SUBTITLE"
        return
    fi

    # Return if none selected
    SELECTED_SHARE=$("${args[@]}" 3>&1 1>&2 2>&3)
    if [ -z "$SELECTED_SHARE" ]
    then
        return
    fi

    # Save the current settings of the selected share in a variable
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

    # Show the current settings
    CLEAN_STORAGE=$(echo "$STORAGE" | grep -v "\#SMB")
    msg_box "Those are the current values for that SMB-share.
In the next step you will be asked what you want to change.\n\n$CLEAN_STORAGE" "$SUBTITLE"

    # Show a list of options that can get changed for the selected SMB-share
    choice=$(whiptail --title "$TITLE - $SUBTITLE" --checklist \
"Please choose which options you want to change for $SELECTED_SHARE
$CHECKLIST_GUIDE" "$WT_HEIGHT" "$WT_WIDTH" 4 \
"Change the sharename" "(Change the name of the SMB-share)" OFF \
"Change the path" "(Change the path of the SMB-share)" OFF \
"Change valid SMB-users" "(Change which users have access to the SMB-share)" OFF \
"Change writeable mode" "(Change if the SMB-share is writeable)" OFF 3>&1 1>&2 2>&3)

    # Execute the chosen options
    case "$choice" in
        *"Change the sharename"*)
            if ! choose_sharename "Please enter the new name of the share." "$SUBTITLE"
            then
                return
            fi
            STORAGE=$(echo "$STORAGE" | sed "/^\[.*\]$/s/^\[.*\]$/\[$NEWNAME\]/")
        ;;&
        *"Change the path"*)
            if ! choose_path "Please type in the new directory that \
you want to use for that SMB-share $SELECTED_SHARE." "$SUBTITLE"
            then
                return
            fi
            chmod -R 770 "$NEWPATH"
            chown -R "$WEB_USER":"$WEB_GROUP" "$NEWPATH"
            NEWPATH=${NEWPATH//\//\\/}
            STORAGE=$(echo "$STORAGE" | sed "/path = /s/path.*/path = $NEWPATH/")
        ;;&
        *"Change valid SMB-users"*)
            if ! choose_users "Please choose the SMB-users \
that shall have access to the share $SELECTED_SHARE." "$SUBTITLE"
            then
                return
            fi
            STORAGE=$(echo "$STORAGE" | sed "/valid users = /s/valid users.*/valid users = $VALID_USERS/")
        ;;&
        *"Change writeable mode"*)
            choose_writeable "Shall the SMB-share $SELECTED_SHARE be writeable?" "$SUBTITLE"
            STORAGE=$(echo "$STORAGE" | sed "/writeable = /s/writeable.*/writeable = $WRITEABLE/")
        ;;&
        "")
            return
        ;;
        *)
        ;;
    esac

    # Return if the STORAGE variable is empty now
    if [ -z "$STORAGE" ]
    then
        msg_box "Something is wrong. Plese try again." "$SUBTITLE"
        return
    fi

    # Show how the SMB-share will look after applying all changed options and let decide if the user wants to continue
    CLEAN_STORAGE=$(echo "$STORAGE" | grep -v "\#SMB")
    if ! yesno_box_yes "This is how the SMB-share $SELECTED_SHARE will look like from now on.
Is everything correct?\n\n$CLEAN_STORAGE" "$SUBTITLE"
    then
        return
    fi

    # Apply the changed options to the SMB-share
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

    # Inform the user
    msg_box "The SMB-share $SELECTED_SHARE was changed successfully." "$SUBTITLE"
}

# Delete SMB-shares
delete_share() {
    local args
    local selected_options
    local CACHE
    local SMB_NAME
    local SMB_PATH
    local count
    local TEST=""
    local SUBTITLE="Delete SMB-shares"

    # Choose which SMB-share shall get deleted
    args=(whiptail --title "$TITLE - $SUBTITLE" --separate-output --checklist \
"Please select which SMB-shares you want to delete.
$CHECKLIST_GUIDE" "$WT_HEIGHT" "$WT_WIDTH" 4)
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

    # Return if no SMB-share was created
    if [ -z "$TEST" ]
    then
        msg_box "No SMB-share created. Please create a SMB-share first." "$SUBTITLE"
        return
    fi

    # Deleted all selected SMB-shares
    selected_options=$("${args[@]}" 3>&1 1>&2 2>&3)
    mapfile -t selected_options <<< "$selected_options"
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
                msg_box "The SMB-share $element was succesfully deleted." "$SUBTITLE"
                break
            fi
            count=$((count+1))
        done
    done
}

# SMB-share Menu
share_menu() {
if [ -z "$(members "$SMB_GROUP")" ]
then
    msg_box "Please create at least one SMB-user before creating a share." "SMB-share Menu"
    return
fi
while :
do
    choice=$(whiptail --title "$TITLE - SMB-share Menu" --menu \
"Choose what you want to do.
$MENU_GUIDE" "$WT_HEIGHT" "$WT_WIDTH" 4 \
"Create a SMB-share" "" \
"Show SMB-shares" "" \
"Edit a SMB-share" "" \
"Delete SMB-shares" "" \
"Return to the Main Menu" "" 3>&1 1>&2 2>&3)

    case "$choice" in
        "Create a SMB-share")
            create_share
        ;;
        "Show SMB-shares")
            show_shares
        ;;
        "Edit a SMB-share")
            edit_share
        ;;
        "Delete SMB-shares")
            delete_share
        ;;
        "Return to the Main Menu")
            break
        ;;
        "")
            break
        ;;
        *)
        ;;
    esac
done  
}

# SMB-server Main Menu
while :
do
    choice=$(whiptail --title "$TITLE - Main Menu" --menu \
"Choose what you want to do.
$MENU_GUIDE" "$WT_HEIGHT" "$WT_WIDTH" 4 \
"Open the SMB-user Menu" "(manage SMB-users)" \
"Open the SMB-share Menu  " "(manage SMB-shares)" \
"Exit" "(exit this script)" 3>&1 1>&2 2>&3)

    case "$choice" in
        "Open the SMB-user Menu")
            user_menu
        ;;
        "Open the SMB-share Menu  ")
            share_menu
        ;;
        "Exit")
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
