#!/bin/bash

# T&M Hansson IT AB © - 2024, https://www.hanssonit.se/
# Copyright © 2021 Simon Lindner (https://github.com/szaimen)

true
SCRIPT_NAME="Midnight Commander"
SCRIPT_EXPLAINER="The Midnight Commander is a directory browsing and file manipulation program \
that provides a flexible, powerful, and convenient set of file and directory operations. 
It is capable of running in either a console or an xterm under X11.
Its basic operation is easily mastered by the novice while providing a rich feature set and extensive customization."
# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Check if root
root_check

# Check if webmin is already installed
if ! is_this_installed mc
then
    # Ask for installing
    install_popup "$SCRIPT_NAME"
else
    # Ask for removal or reinstallation
    reinstall_remove_menu "$SCRIPT_NAME"
    # Removal
    apt-get purge mc -y
    apt-get autoremove -y
    # Show successful uninstall if applicable
    removal_popup "$SCRIPT_NAME"
fi

# Install mc
install_if_not mc

# Show successful installation
msg_box "Midnight Commander was successfully installed.
You can launch it by running 'mc' in the CLI."

# Allow to install a dark theme
if ! yesno_box_yes "Do you want to install a dark theme for Midnight Commander?"
then
    exit
fi

# Install dark theme
print_text_in_color "$ICyan" "Installing dark theme for Midnight Commander..."
if [ -z "$UNIXUSER" ]
then
    USERS=(root)
else
    USERS=("$UNIXUSER" root)
fi
for user in "${USERS[@]}"
do
    if [ "$user" = root ]
    then
        MC_PATH=/root/.config/mc
    else
        MC_PATH=/home/$user/.config/mc
    fi
    sudo -u "$user" mkdir -p "$MC_PATH"
    cat << MC_INI > "$MC_PATH/ini"
[Colors]
base_color=linux:normal=white,black:marked=yellow,black:input=,green:menu=black:menusel=white:\
menuhot=red,:menuhotsel=black,red:dfocus=white,black:dhotnormal=white,black:\
dhotfocus=white,black:executable=,black:directory=white,black:link=white,black:\
device=white,black:special=white,black:core=,black:stalelink=red,black:editnormal=white,black
MC_INI
    chown "$user":"$user" "$MC_PATH/ini"
done

# Inform the user
msg_box "The dark theme for Midnight Commander was successfully applied."
exit
