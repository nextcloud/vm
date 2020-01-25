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

# Must be root
root_check

# Configure Nextcloud
choice=$(whiptail --title "Nextcloud Configuration" --checklist "Which settings do you want to configure?\nSelect by pressing the spacebar" "$WT_HEIGHT" "$WT_WIDTH" 4 \
"CookieLifetime" "(Configure forced logout timeout for users using the web GUI)" OFF \
"Share-folder" "(If configured, all Nextcloud shares from other users will be stored in a folder named 'Shared')"
"Disable rich workspaces" "(disable top notes in GUI)" OFF 3>&1 1>&2 2>&3)

case "$choice" in
    *"CookieLifetime"*)
        run_static_script cookielifetime
    ;;&
    *"Share-folder"*)
        clear
        msg_box "This option will make all Nextcloud shares from other users appear in a folder named 'Shared' in the Nextcloud GUI.\n\nIf you don't enable this option, all shares will appear directly in the Nextcloud GUI root folder, which is the default behaviour."
        if [[ "yes" == $(ask_yes_or_no "Do you want to enable this option?") ]]
        then
            occ_command config:system:set share_folder --value="/Shared"
            msg_box "All new Nextcloud shares from other users will appear in the 'Shared' folder from now on."
        fi
    ;;&
    *"Disable rich workspaces"*)
        msg_box "This option will will disable a feature names 'rich workspaces'. It will disable the top notes in GUI."
        if [[ "yes" == $(ask_yes_or_no "Do you want to disable rich workspaces?") ]]
        then
            occ_command config:app:set text workspace_available --value=0
            msg_box "Rich workspaces are now disabled."
        fi
    ;;&
    *)
    ;;
esac

exit
