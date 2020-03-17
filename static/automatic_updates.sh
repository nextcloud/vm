#!/bin/bash

# T&M Hansson IT AB © - 2020, https://www.hanssonit.se/

# shellcheck disable=2034,2059
true
# shellcheck source=lib.sh
. <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)

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
Please keep in mind that automatic updates might fail hence it's important to have a proper backup in place if you plan to run this option.

You can disable the automatic updates by entering the crontab file like this:
'sudo crontab -e -u root'
Then just put a hash (#) in front of the row that you want to disable.

In the next step you will be able to choose to proceed or exit."

if [[ "yes" == $(ask_yes_or_no "Do you want to enable automatic updates?") ]]
then
    occ_command config:app:set updatenotification notify_groups --value="[]"
    touch $VMLOGS/update.log
    crontab -u root -l | { cat; echo "0 $AUT_UPDATES_TIME * * 6 $SCRIPTS/update.sh minor >> $VMLOGS/update.log"; } | crontab -u root -
    if [[ "yes" == $(ask_yes_or_no "Do you want to reboot your server after every update? *recommended*") ]]
    then
        sed -i "s|exit|shutdown -r +1|g" "$SCRIPTS"/update.sh
        echo "exit" >> "$SCRIPTS"/update.sh
    fi
fi
