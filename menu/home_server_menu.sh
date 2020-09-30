#!/bin/bash

# T&M Hansson IT AB © - 2020, https://www.hanssonit.se/

# shellcheck disable=2034,2059
true
SCRIPT_NAME="Home Server Menu"
# shellcheck source=lib.sh
. <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Must be root
root_check

# Main menu
choice=$(whiptail --title "$TITLE" --checklist \
"This menu is filled with options especially meant for Home servers.

Please note that because some options are very new, it is possible, that you find bugs.
While testing everything worked, though.

Choose which one you want to execute.
$CHECKLIST_GUIDE\n\n$RUN_LATER_GUIDE" "$WT_HEIGHT" "$WT_WIDTH" 4 \
"PLEX Media Server" "(Multimedia server application)" OFF \
"SMB-server" "(Create and manage a SMB-server on OS level)" OFF 3>&1 1>&2 2>&3)

case "$choice" in
    *"PLEX Media Server"*)
        print_text_in_color "$ICyan" "Downloading the PLEX Media Server script..."
        run_script HOME_SERVER plexmediaserver
    ;;&
    *"SMB-server"*)
        print_text_in_color "$ICyan" "Downloading the SMB Server script..."
        run_script HOME_SERVER smbserver
    ;;&
    *)
    ;;
esac
exit
