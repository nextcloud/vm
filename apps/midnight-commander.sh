#!/bin/bash

# T&M Hansson IT AB © - 2020, https://www.hanssonit.se/
# Copyright © 2020 Simon Lindner (https://github.com/szaimen)

# shellcheck disable=2034,2059
true
SCRIPT_NAME="Midnight Commander"
SCRIPT_EXPLAINER="The Midnight Commander is a directory browsing and file manipulation program \
that provides a flexible, powerful, and convenient set of file and directory operations. 
It is capable of running in either a console or an xterm under X11.
Its basic operation is easily mastered by the novice while providing a rich feature set and extensive customization."
# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh || source <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)

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
    apt purge mc -y
    apt autoremove -y
    # Show successful uninstall if applicable
    removal_popup "$SCRIPT_NAME"
fi

# Install mc
check_command apt install mc -y

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
USER_HOMES=$(find /home -mindepth 1 -maxdepth 1 -type d)
mapfile -t USER_HOMES <<< "$USER_HOMES"
USER_HOMES+=(/root)
for user_home in "${USER_HOMES[@]}"
do
    mkdir -p "$user_home/.config/mc"
    cat << MC_INI > "$user_home/.config/mc/ini"
[Colors]
base_color=linux:normal=white,black:marked=yellow,black:input=,green:menu=black:menusel=white:\
menuhot=red,:menuhotsel=black,red:dfocus=white,black:dhotnormal=white,black:\
dhotfocus=white,black:executable=,black:directory=white,black:link=white,black:\
device=white,black:special=white,black:core=,black:stalelink=red,black:editnormal=white,black
MC_INI
done

# Inform the user
msg_box "The dark theme for Midnight Commander was successfully applied."
exit
