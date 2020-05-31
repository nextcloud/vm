#!/bin/bash

# T&M Hansson IT AB © - 2020, https://www.hanssonit.se/

# shellcheck disable=2034,2059
true
# shellcheck source=lib.sh
NC_UPDATE=1 . <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)
unset NC_UPDATE

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Must be root
root_check

# Configure Nextcloud
choice=$(whiptail --title "Nextcloud Configuration" --checklist "Which settings do you want to configure?\nSelect by pressing the spacebar\nYou can view this menu later by running 'sudo bash $SCRIPTS/menu.sh'" "$WT_HEIGHT" "$WT_WIDTH" 4 \
"CookieLifetime" "(Configure forced logout timeout for users using the web GUI)" OFF \
"Share-folder" "(Shares from other users will appear in a folder named 'Shared')" OFF \
"Disable workspaces" "(disable top notes in GUI)" OFF \
"Disable user flows" "(Disable user settings for Nextcloud Flow)" OFF 3>&1 1>&2 2>&3)

case "$choice" in
    *"CookieLifetime"*)
        run_script STATIC cookielifetime
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
    *"Disable workspaces"*)
        msg_box "This option will will disable a feature named 'rich workspaces'. It will disable the top notes in GUI."
        if [[ "yes" == $(ask_yes_or_no "Do you want to disable rich workspaces?") ]]
        then
            # Check if text is enabled
            if ! is_app_enabled text
                then
                msg_box "The text app isn't enabled - unable to disable rich workspaces."
                sleep 1
            else
                # Disable workspaces
                occ_command config:app:set text workspace_available --value=0
                msg_box "Rich workspaces are now disabled."
            fi
        fi
    ;;&
    *"Disable user flows"*)
        # Greater than 18.0.3 is 18.0.4 which is required
        if version_gt "$CURRENTVERSION" "18.0.3"
        then
            msg_box "This option will disable the with Nextcloud 18 introduced user flows. It will disable the user flow settings. Admin flows will continue to work."
            if [[ "yes" == $(ask_yes_or_no "Do you want to disable user flows?") ]]
            then
                occ_command config:app:set workflowengine user_scope_disabled --value yes
                msg_box "User flow settings are now disabled."
            fi
        else
            msg_box "'Disable user flows' is only available on Nextcloud 18.0.4 and above.\nPlease upgrade by running 'sudo bash /var/scripts/update.sh'"
            sleep 1
        fi
    ;;&
    *)
    ;;
esac
exit
