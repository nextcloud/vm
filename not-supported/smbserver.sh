#!/bin/bash

# T&M Hansson IT AB © - 2024, https://www.hanssonit.se/
# Copyright © 2021 Simon Lindner (https://github.com/szaimen)

true
SCRIPT_NAME="SMB Server"
SCRIPT_EXPLAINER="This script allows you to create a SMB-server from your Nextcloud-VM.
It helps you manage all SMB-users and SMB-shares.
As bonus feature you can automatically mount the chosen directories to Nextcloud and \
create Nextcloud users with the same credentials like your SMB-users."
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
print_text_in_color "$ICyan" "Getting all valid mounts. This can take a while..."
DIRECTORIES=$(find /mnt/ -mindepth 1 -maxdepth 2 -type d | grep -v "/mnt/ncdata")
mapfile -t DIRECTORIES <<< "$DIRECTORIES"
for directory in "${DIRECTORIES[@]}"
do
    if mountpoint -q "$directory" && [ "$(stat -c '%a' "$directory")" = "770" ] \
&& [ "$(stat -c '%U' "$directory")" = "$WEB_USER" ] && [ "$(stat -c '%G' "$directory")" = "$WEB_GROUP" ]
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

# Add firewall rules
ufw allow samba comment Samba &>/dev/null

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

# Set netbios name to a fixed name to reach the server always by using nextcloud
if ! grep -q "netbios name =" "$SMB_CONF"
then
    sed -i '/\[global\]/a netbios name = nextcloud' "$SMB_CONF"
else
    sed -i 's|.*netbios name =.*|netbios name = nextcloud|' "$SMB_CONF"
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
    systemctl stop smbd
}

# Samba start function
samba_start() {
    print_text_in_color "$ICyan" "Starting the SMB-server..."
    systemctl start smbd
}

# Get SMB users
get_users() {
    grep "^$1:" /etc/group | cut -d ":" -f 4 | sed 's|,| |g'
}

# Choose from a list of SMB-user
smb_user_menu() {
    args=(whiptail --title "$TITLE - $2" --checklist \
"$1
$CHECKLIST_GUIDE" "$WT_HEIGHT" "$WT_WIDTH" 4)
    USERS=$(get_users "$SMB_GROUP")
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
    check_command su -s /bin/sh "$WEB_USER" -c "php $NCPATH/occ user:add $NEWNAME --password-from-env"
    unset OC_PASS

    # Create files directory for that user
    if ! [ -d "$NCDATA" ]
    then
        msg_box "Something is wrong: $NCDATA does not exist." "$SUBTITLE"
        return
    fi
    mkdir -p "$NCDATA/$NEWNAME/files"
    chown -R "$WEB_USER":"$WEB_GROUP" "$NCDATA/$NEWNAME"
    chmod -R 770 "$NCDATA/$NEWNAME"

    # Inform the user
    msg_box "The new Nextcloud user $NEWNAME was successfully created." "$SUBTITLE"

    # Configure mail address
    msg_box "It is recommended to set a mail address for every Nextcloud user \
so that Nextcloud is able to send mails to them."
    if ! yesno_box_yes "Do you want to add a mail address to this user?"
    then
        return
    fi
    while :
    do
        MAIL_ADDRESS="$(input_box_flow "Please type in the mail-address of the new Nextcloud user $NEWNAME!
This mail-address needs to be valid. Otherwise Nextcloud won't be able to send mails to that user.
If you want to cancel, just type in 'exit' and press [ENTER]." "$SUBTITLE")"
        if [ "$MAIL_ADDRESS" = "exit" ]
        then
            return
        elif ! echo "$MAIL_ADDRESS" | grep -q "@" || echo "$MAIL_ADDRESS" | grep -q " " \
|| echo "$MAIL_ADDRESS" | grep -q "^@" || echo "$MAIL_ADDRESS" | grep -q "@$" 
        then
            msg_box "The mail-address isn't valid. Please try again!"
        else
            nextcloud_occ user:setting "$NEWNAME" settings email "$MAIL_ADDRESS"
            msg_box "Congratulations!\nThe mail-address of $NEWNAME was successfully set to $MAIL_ADDRESS!"
            break
        fi
    done
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
    USERS=$(get_users "$SMB_GROUP")
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
        check_command su -s /bin/sh "$WEB_USER" -c "php $NCPATH/occ user:resetpassword $user --password-from-env"
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

    if [ -n "$choice" ] && [ "$choice" != "Add a SMB-user" ] && [ "$choice" != "Return to the Main Menu" ] && [ -z "$(get_users "$SMB_GROUP")" ]
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
for mount in "${MOUNTS[@]}"
do
    LOCALDIRECTORIES=$(find "$mount" -maxdepth 2 -type d | grep -v '/.snapshots')
    VALID_DIRS+="$(echo -e "$LOCALDIRECTORIES" | grep "^$mount")\n"
done
while :
do
    msg_box "In the following step you will need to type in the directory that you want to use.
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
            if grep " ${mount%/} " /etc/mtab | grep -q btrfs
            then
                BTRFS_ROOT_DIR="$mount"
            else
                BTRFS_ROOT_DIR=""
            fi
            break
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
unset VALID_USERS_AR
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
        VALID_USERS_AR+=("$user")
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
    recycle:repository = .recycle
    recycle:touch = true
    recycle:keeptree = yes
    recycle:versions = yes
    recycle:directory_mode = 0770
EOF
            if [ -n "$BTRFS_ROOT_DIR" ]
            then
                local SHADOW_COPY=", shadow_copy2, btrfs"
                cat >> "$SMB_CONF" <<EOF
    shadow:format = @%Y%m%d_%H%M%S  
    shadow:sort = desc
    shadow:snapdir = $BTRFS_ROOT_DIR.snapshots
    shadow:localtime = yes
EOF
            fi
            echo "    vfs objects = recycle$SHADOW_COPY" >> "$SMB_CONF"
            echo "#SMB$count-end - Please don't remove or change this line" >> "$SMB_CONF"
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
- On Linux in a file manager using this address: 'smb://nextcloud'
- On Windows in the Windows Explorer using this address: '\\\\ nextcloud' (without space)
- On macOS in the Finder (press '[CMD] + [K]') using this address: 'smb://nextcloud'

If connecting using 'nextcloud' as server name doesn't work, \
you can also connect using the IP-address: '$ADDRESS' instead of nextcloud." "$SUBTITLE"

    # Test if NC exists
    if ! [ -f $NCPATH/occ ]
    then
        return
    # Ask if the same directory shall get mounted as external storage to NC
    elif ! yesno_box_yes "Do you want to mount the directory $NEWPATH to Nextcloud as local external storage?" "$SUBTITLE"
    then
        return
    fi

    # Install and enable files_external
    if ! is_app_enabled files_external
    then
        install_and_enable_app files_external
    fi

    # Mount directory as root directory if only one user was chosen
    if [ "${#VALID_USERS_AR[*]}" -eq 1 ] && [ "$WRITEABLE" = "yes" ]
    then
        if yesno_box_yes "Do you want to make $NEWPATH the root folder for ${VALID_USERS_AR[*]}?"
        then
            NEWNAME="/"
        fi
    fi

    # Choose if it shall be writeable in NC
    if [ "$WRITEABLE" = "yes" ]
    then
        READONLY="false"
    elif [ "$WRITEABLE" = "no" ]
    then
        READONLY="true"
    fi

    # Find other attributes
    SHARING="true"
    SELECTED_USER=""
    UNAVAILABLE_USER=""
    # Choose from NC users
    NC_USER=$(nextcloud_occ_no_check user:list | sed 's|^  - ||g' | sed 's|:.*||')
    for user in "${VALID_USERS_AR[@]}"
    do
        if echo "$NC_USER" | grep -q "^$user$"
        then
            SELECTED_USER+="$user  "
        else
            UNAVAILABLE_USER+="$user " 
        fi
    done
    if [ -n "$UNAVAILABLE_USER" ]
    then
        msg_box "Some chosen SMB-users weren't available in Nextcloud:\n$UNAVAILABLE_USER"
        if ! yesno_box_no "Do you want to continue nonetheless?"
        then
            return
        fi
    fi

    # Create and mount external storage
    print_text_in_color "$ICyan" "Mounting the local storage to Nextcloud."
    MOUNT_ID=$(nextcloud_occ files_external:create "$NEWNAME" local null::null -c datadir="$NEWPATH" )
    MOUNT_ID=${MOUNT_ID//[!0-9]/}

    # Mount it to the admin group if no group or user chosen
    if [ -z "$SELECTED_USER" ]
    then
        if [ "$NEWNAME" != "/" ]
        then
            nextcloud_occ files_external:applicable --add-group=admin "$MOUNT_ID" -q
            msg_box "No SMB-user available in Nextcloud, mounted the local storage to the admin group."
        else
            nextcloud_occ files_external:delete "$MOUNT_ID" -y
            msg_box "No SMB-user available in Nextcloud, could not add the storage to Nextcloud!"
            return
        fi
    else
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
    msg_box "Your mount was successful, congratulations!
You are now using the Nextcloud external storage app to access files there.
The Share has been mounted to the Nextcloud admin-group if not specifically changed to users or groups.
You can now access 'https://yourdomain-or-ipaddress/settings/admin/externalstorages' \
to edit external storages in Nextcloud." "$SUBTITLE"

    # Inform the user that he can set up inotify for this external storage
    if ! yesno_box_no "Do you want to enable inotify for this external storage in Nextcloud?
It is only recommended if the content can get changed externally and \
will let Nextcloud track if this external storage was externally changed.
If you choose 'yes', we will install a needed PHP-plugin, the files_inotify app and create a cronjob for you."
    then
        return
    fi

    # Warn a second time
    if ! yesno_box_no "Are you sure, that you want to enable inotify for this external storage?
Please note, that this will need around 1 KB additional RAM per folder.
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
    # https://github.com/icewind1991/files_inotify/blob/main/README.md
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
    chown "$WEB_USER":"$WEB_GROUP" "$VMLOGS"/files_inotify.log

    # Inform the user
    if [ -n "$INOTIFY_INSTALL" ]
    then
        if ! yesno_box_yes "The inotify PHP extension was successfully installed, \
the max folder variable was set to 524288 and $VMLOGS/files_inotify.log was created.
Just press [ENTER] (on the default 'yes') to install the needed \
files_inotify app and set up the cronjob for this external storage."
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
    crontab -u "$WEB_USER" -l | { cat; echo "@reboot sleep 20 && php -f $NCPATH/occ files_external:notify -v $MOUNT_ID >> $VMLOGS/files_inotify.log"; } | crontab -u "$WEB_USER" -

    # Run the command in a subshell and don't exit if the smbmount script exits
    nohup sudo -u "$WEB_USER" php "$NCPATH"/occ files_external:notify -v "$MOUNT_ID" >> $VMLOGS/files_inotify.log &
    
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
            STORAGE=$(echo "$STORAGE" | grep -v "^    shadow:")
            if [ -z "$BTRFS_ROOT_DIR" ]
            then
                STORAGE=$(echo "$STORAGE" | sed "/vfs objects = /s/vfs objects =.*/vfs objects = recycle/")
            else
                STORAGE=$(echo "$STORAGE" | sed "/vfs objects = /s/vfs objects =.*/vfs objects = recycle, shadow_copy2, btrfs/")
                STORAGE=$(echo "$STORAGE" | sed '/vfs objects =/a\ \ \ \ shadow:format = @%Y%m%d_%H%M%S')
                STORAGE=$(echo "$STORAGE" | sed '/vfs objects =/a\ \ \ \ shadow:sort = desc')
                STORAGE=$(echo "$STORAGE" | sed "/vfs objects =/a\ \ \ \ shadow:snapdir = $BTRFS_ROOT_DIR.snapshots")
                STORAGE=$(echo "$STORAGE" | sed '/vfs objects =/a\ \ \ \ shadow:localtime = yes')
            fi
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
        msg_box "Something is wrong. Please try again." "$SUBTITLE"
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
                msg_box "The SMB-share $element was successfully deleted." "$SUBTITLE"
                break
            fi
            count=$((count+1))
        done
    done
}

# SMB-share Menu
share_menu() {
if [ -z "$(get_users "$SMB_GROUP")" ]
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

automatically_empty_recycle_bins() {
    local SUBTITLE="Automatically empty recycle bins"
    local count
    local TEST=""

    # Ask for removal
    if crontab -u root -l | grep -q "$SCRIPTS/recycle-bin-cleanup.sh"
    then
        if yesno_box_yes "It seems like automatic recycle bin cleanup is already configured. Do you want to disable it?" "$SUBTITLE"
        then
            crontab -u root -l | grep -v "$SCRIPTS/recycle-bin-cleanup.sh" | crontab -u root -
            rm -rf "$SCRIPTS/recycle-bin-cleanup.sh"
            msg_box "Automatic recycle bin cleanup was successfully disabled." "$SUBTITLE"
        fi
        return
    fi

    # Ask for installation
    msg_box "Automatic recycle bin cleanup does clean up all recycle bin folders automatically in the background.
It gets executed every day and cleans old files in the recycle bin folders that were deleted more than 2 days ago." "$SUBTITLE"
    if ! yesno_box_yes "Do you want to enable automatic recycle bin cleanup?" "$SUBTITLE"
    then
        return
    fi

    # Adjust some things
    count=1
    while [ $count -le $MAX_COUNT ]
    do
        CACHE=$(sed -n "/^#SMB$count-start/,/^#SMB$count-end/p" "$SMB_CONF")
        if [ -n "$CACHE" ]
        then
            TEST+="SMB$count"
            if ! echo "$CACHE" | grep -q 'recycle:touch'
            then
                CACHE=$(echo "$CACHE" | sed "/recycle:repository/a \ \ \ \ recycle:touch = true")
                sed -i "/^#SMB$count-start/,/^#SMB$count-end/d" "$SMB_CONF"
                echo -e "\n$CACHE" >> "$SMB_CONF"
            fi
        fi
        count=$((count+1))
    done

    # Return if none created
    if [ -z "$TEST" ]
    then
        msg_box "No SMB-share created. Please create a SMB-share first." "$SUBTITLE"
        return
    else
        systemctl restart smbd
    fi

    # Execute
    cat << AUTOMATIC_CLEANUP > "$SCRIPTS/recycle-bin-cleanup.sh"
#!/bin/bash

# Secure the file
chown root:root "$SCRIPTS/recycle-bin-cleanup.sh"
chmod 700 "$SCRIPTS/recycle-bin-cleanup.sh"

count=1
while [ \$count -le $MAX_COUNT ]
do
    CACHE=\$(sed -n "/^#SMB\$count-start/,/^#SMB\$count-end/p" "$SMB_CONF")
    if [ -n "\$CACHE" ]
    then
        SMB_PATH=\$(echo "\$CACHE" | grep "path =" | grep -oP '/.*')
        if [ -d "\$SMB_PATH" ] && [ -d "\$SMB_PATH/.recycle/" ]
        then
            find "\$SMB_PATH/.recycle/" -type f -atime +2 -delete
            find "\$SMB_PATH/.recycle/" -empty -delete
        fi
    fi
    count=\$((count+1))
done
AUTOMATIC_CLEANUP

    # Secure the file
    chown root:root "$SCRIPTS/recycle-bin-cleanup.sh"
    chmod 700 "$SCRIPTS/recycle-bin-cleanup.sh"

    # Add cronjob
    crontab -u root -l | grep -v "$SCRIPTS/recycle-bin-cleanup.sh" | crontab -u root -
    crontab -u root -l | { cat; echo "@daily $SCRIPTS/recycle-bin-cleanup.sh >/dev/null"; } | crontab -u root -

    # Show message
    msg_box "Automatic recycle bin cleanup was successfully configured!" "$SUBTITLE"

    # Allow to adjust Nextcloud to do the same
    if yesno_box_yes "Do you want Nextcloud to delete files in its trashbin that were deleted more than 4 days ago \
and file versions that were created more than 4 days ago, too?" "$SUBTITLE"
    then
        nextcloud_occ config:system:set trashbin_retention_obligation --value="auto, 4"
        nextcloud_occ config:system:set versions_retention_obligation --value="auto, 4"
        msg_box "Nextcloud was successfully configured to delete files in its trashbin that were deleted more than 4 days ago \
and file versions that were created more than 4 days ago!" "$SUBTITLE"
    fi
}

empty_recycle_bins() {
    local count
    local selected_options
    local args
    local TEST=""
    local FOLDER_SIZE
    local SMB_PATH
    local SUBTITLE="Empty recycle bins"

    # Show a list with available SMB-shares
    args=(whiptail --title "$TITLE - $SUBTITLE" --separate-output --checklist \
"Please select which recycle folders you want to empty.
$CHECKLIST_GUIDE" "$WT_HEIGHT" "$WT_WIDTH" 4)
    count=1
    while [ $count -le $MAX_COUNT ]
    do
        CACHE=$(sed -n "/^#SMB$count-start/,/^#SMB$count-end/p" "$SMB_CONF")
        if [ -n "$CACHE" ]
        then
            SMB_PATH="$(echo "$CACHE" | grep "path =" | grep -oP '/.*')/.recycle/"
            if [ -d "$SMB_PATH" ]
            then
                FOLDER_SIZE="$(du -sh "$SMB_PATH" | awk '{print $1}')"
            else
                FOLDER_SIZE=0B
            fi
            args+=("$SMB_PATH" "$FOLDER_SIZE" ON)
            TEST+="$SMB_PATH"
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
    if [ -z "$selected_options" ]
    then
        msg_box "No option selected." "$SUBTITLE"
        return
    fi
    mapfile -t selected_options <<< "$selected_options"
    for element in "${selected_options[@]}"
    do
        print_text_in_color "$ICyan" "Emptying $element"
        if [ -d "$element" ]
        then
            rm -r "$element"
        fi
    done
    msg_box "All selected recycle folders were emptied!
Please note: If you are using BTRFS as file system, it can take up to 54h until the space is released due to automatic snapshots." "$SUBTITLE"

    # Allow to clean up Nextclouds trashbin, too
    if yesno_box_no "Do you want to clean up Nextclouds trashbin, too?
This will run the command 'occ trashbin:cleanup --all-users' for you if you select 'Yes'!" "$SUBTITLE"
    then
        nextcloud_occ trashbin:cleanup --all-users -vvv
        msg_box "The cleanup of Nextclouds trashbin was successful!" "$SUBTITLE"
    fi

    # Allow to clean up Nextclouds versions, too
    if yesno_box_no "Do you want to clean up all file versions in Nextcloud?
This will run the command 'occ versions:cleanup' for you if you select 'Yes'!" "$SUBTITLE"
    then
        nextcloud_occ versions:cleanup -vvv
        msg_box "The cleanup of all file versions in Nextcloud was successful!" "$SUBTITLE"
    fi
}

# SMB-server Main Menu
while :
do
    choice=$(whiptail --title "$TITLE - Main Menu" --menu \
"Choose what you want to do.
$MENU_GUIDE" "$WT_HEIGHT" "$WT_WIDTH" 4 \
"Open the SMB-user Menu" "(manage SMB-users)" \
"Open the SMB-share Menu" "(manage SMB-shares)" \
"Automatically empty recycle bins  " "(Schedule cleanup of recycle folders)" \
"Empty recycle bins" "(Clean up recycle folders)" \
"Exit" "(exit this script)" 3>&1 1>&2 2>&3)

    case "$choice" in
        "Open the SMB-user Menu")
            user_menu
        ;;
        "Open the SMB-share Menu")
            share_menu
        ;;
        "Automatically empty recycle bins  ")
            automatically_empty_recycle_bins
        ;;
        "Empty recycle bins")
            empty_recycle_bins
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
