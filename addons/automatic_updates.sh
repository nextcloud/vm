#!/bin/bash

# T&M Hansson IT AB © - 2020, https://www.hanssonit.se/

true
SCRIPT_NAME="Automatic Updates"
# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh || source <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)

print_text_in_color "$ICyan" "Configuring automatic updates..."

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Check if root
root_check

msg_box "This option will update your server every week on Saturdays at $AUT_UPDATES_TIME:00.
The update will run the built in script '$SCRIPTS/update.sh' which will update both the server packages and Nextcloud itself.

You can read more about it here: https://www.techandme.se/nextcloud-update-is-now-fully-automated/
Please keep in mind that automatic updates might fail hence it's \
important to have a proper backup in place if you plan to run this option.

You can disable the automatic updates by entering the crontab file like this:
'sudo crontab -e -u root'
Then just put a hash (#) in front of the row that you want to disable.

In the next step you will be able to choose to proceed or exit." "$SUBTITLE"

if yesno_box_yes "Do you want to enable automatic updates?"
then
    # TODO: delete the following line after a few releases. It was copied to the install-script.
    nextcloud_occ config:app:set updatenotification notify_groups --value="[]"
    touch $VMLOGS/update.log
    crontab -u root -l | { cat; echo "0 $AUT_UPDATES_TIME * * 6 $SCRIPTS/update.sh minor >> $VMLOGS/update.log"; } | crontab -u root -
    if yesno_box_yes "Do you want to reboot your server after every update? *recommended*"
    then
        sed -i "s|exit|/sbin/shutdown -r +1|g" "$SCRIPTS"/update.sh
        echo "exit" >> "$SCRIPTS"/update.sh
    fi
    msg_box "Please remember to keep backups in case something should go wrong, you never know." "$SUBTITLE"
fi
