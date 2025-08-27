#!/bin/bash

# T&M Hansson IT AB © - 2024, https://www.hanssonit.se/

true
SCRIPT_NAME="Nextcloud Configuration Menu"
# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh

# Get all needed variables from the library
nc_update

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Must be root
root_check

# Set the startup switch
if [ -f "$SCRIPTS/nextcloud-startup-script.sh" ]
then
    STARTUP_SWITCH="ON"
else
    STARTUP_SWITCH="OFF"
fi

# Configure Nextcloud
choice=$(whiptail --title "$TITLE" --checklist \
"Which settings do you want to configure?
$CHECKLIST_GUIDE\n\n$RUN_LATER_GUIDE" "$WT_HEIGHT" "$WT_WIDTH" 4 \
"CookieLifetime" "(Configure forced logout timeout for users using the web GUI)" OFF \
"Share-folder" "(Shares from other users will appear in a folder named 'Shared')" OFF \
"Disable workspaces" "(Disable top notes in GUI)" OFF \
"Disable user flows" "(Disable user settings for Nextcloud Flow)" OFF \
"Check 0-Byte files" "(Check if files are 0-byte (empty/corrupted))" OFF \
"Update mimetype list" "(Update Nextclouds internal mimetype database)" OFF \
"Enable logrotate" "(Use logrotate to keep more Nextcloud logs)" OFF 3>&1 1>&2 2>&3)

case "$choice" in
    *"CookieLifetime"*)
        print_text_in_color "$ICyan" "Downloading the CookieLifetime script..."
        run_script ADDONS cookielifetime
    ;;&
    *"Share-folder"*)
        SUBTITLE="Share-folder"
        msg_box "This option will make all Nextcloud shares from \
other users appear in a folder named 'Shared' in the Nextcloud GUI.

If you don't enable this option, all shares will appear directly in \
the Nextcloud GUI root folder, which is the default behavior." "$SUBTITLE"
        if yesno_box_yes "Do you want to enable this option?" "$SUBTITLE"
        then
            nextcloud_occ config:system:set share_folder --value="/Shared"
            msg_box "All new Nextcloud shares from other \
users will appear in the 'Shared' folder from now on." "$SUBTITLE"
        fi
    ;;&
    *"Disable workspaces"*)
        SUBTITLE="Disable workspaces"
        msg_box "This option will will disable a feature named 'rich workspaces'. \
It will disable the top notes in GUI." "$SUBTITLE"
        if yesno_box_yes "Do you want to disable rich workspaces?" "$SUBTITLE"
        then
            # Check if text is enabled
            if ! is_app_enabled text
                then
                msg_box "The text app isn't enabled - unable to disable rich workspaces." "$SUBTITLE"
                sleep 1
            else
                # Disable workspaces
                nextcloud_occ config:app:set text workspace_available --value=0
                msg_box "Rich workspaces are now disabled." "$SUBTITLE"
            fi
        fi
    ;;&
    *"Disable user flows"*)
        SUBTITLE="Disable user flows"
        # Greater than 18.0.3 is 18.0.4 which is required
        if version_gt "$CURRENTVERSION" "18.0.3"
        then
            msg_box "This option will disable the with Nextcloud 18 introduced user flows. \
It will disable the user flow settings. Admin flows will continue to work." "$SUBTITLE"
            if yesno_box_yes "Do you want to disable user flows?" "$SUBTITLE"
            then
                nextcloud_occ config:app:set workflowengine user_scope_disabled --value yes
                msg_box "User flow settings are now disabled." "$SUBTITLE"
            fi
        else
            msg_box "'Disable user flows' is only available on Nextcloud 18.0.4 and above.
Please upgrade by running 'sudo bash /var/scripts/update.sh'" "$SUBTITLE"
            sleep 1
        fi
    ;;&
    *"Check 0-Byte files"*)
        print_text_in_color "$ICyan" "Downloading the 0-Byte files script..."
        run_script ADDONS 0-byte-files
    ;;&
    *"Update mimetype list"*)
        if yesno_box_yes "Do you want to update Nextclouds internal mimetype database?
This option is recommended to be run after every major Nextcloud update." "Update mimetypes"
        then
            print_text_in_color "$ICyan" "Updating Nextclouds internal mimetype database..."
            nextcloud_occ maintenance:mimetype:update-js
            nextcloud_occ maintenance:mimetype:update-db
        fi
    ;;&
    *"Enable logrotate"*)
        SUBTITLE="Enable logrotate"
        msg_box "This option enables logrotate for Nextcloud logs to keep all logs for 10 days" "$SUBTITLE"
        if yesno_box_yes "Do you want to enable logrotate for Nextcloud logs?" "$SUBTITLE"
        then
            # Set logrotate (without size restriction)
            nextcloud_occ config:system:set log_rotate_size --value=0

            # Configure logrotate to rotate logs for us (max 10, every day a new one)
            cat << NEXTCLOUD_CONF > /etc/logrotate.d/nextcloud.log.conf
$VMLOGS/nextcloud.log {
daily
rotate 10
copytruncate
}
$VMLOGS/audit.log {
daily
rotate 10
copytruncate
}
NEXTCLOUD_CONF

            # Set needed ownership for the Nextcloud log folder to work correctly
            chown www-data:www-data "${VMLOGS}"/
            
            msg_box "Logrotate was successfully enabled." "$SUBTITLE"
        fi
    ;;&
    *)
    ;;
esac
exit
