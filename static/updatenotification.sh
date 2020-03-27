#!/bin/bash

# T&M Hansson IT AB © - 2020, https://www.hanssonit.se/

# Use local lib file if existant
if [ -f /var/scripts/main/lib.sh ]
then
# shellcheck disable=2034,2059
true
# shellcheck source=lib.sh
NC_UPDATE=1 source /var/scripts/main/lib.sh
unset NC_UPDATE
else
# shellcheck disable=2034,2059
true
# shellcheck source=lib.sh
NC_UPDATE=1 . <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/testing/lib.sh)
unset NC_UPDATE
fi

print_text_in_color "$ICyan" "Checking for new Nextcloud version..."

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Check if root
root_check

REPORTEDNCVERSION=""

if [ "$CURRENTVERSION" == "$NCVERSION" ]
then
    print_text_in_color "$IGreen" "You already run the latest version! ($NCVERSION)"
    exit
fi

if [ "$REPORTEDNCVERSION" == "$NCVERSION" ]
then
    print_text_in_color "$ICyan" "The notification regarding the new Nextcloud update has been already reported! ($NCVERSION)"
    exit
fi

if version_gt "$NCVERSION" "$CURRENTVERSION"
then
    if crontab -l -u root | grep $SCRIPTS/update.sh
    then
        notify_admin_gui \
        "New Nextcloud version!" \
        "Nextcloud $NCVERSION just became available. Since you are running Automatic Updates at $AUT_UPDATES_TIME:00, you don't need to bother about updating the server manually, as that's already taken care of."
        sed -i "s|^REPORTEDNCVERSION.*|REPORTEDNCVERSION=$NCVERSION|" $SCRIPTS/updatenotification.sh
    else
        notify_admin_gui \
        "Update available!" \
        "Nextcloud $NCVERSION is available. Please run 'sudo bash /var/scripts/update.sh' from your CLI to update your server."
        sed -i "s|^REPORTEDNCVERSION.*|REPORTEDNCVERSION=$NCVERSION|" $SCRIPTS/updatenotification.sh
    fi
fi
