#!/bin/bash

# T&M Hansson IT AB © - 2020, https://www.hanssonit.se/

# shellcheck disable=2034,2059
true
# shellcheck source=lib.sh
NC_UPDATE=1 . <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)
unset NC_UPDATE

print_text_in_color "$ICyan" "Checking for new Nextcloud version..."

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Check if root
root_check

NCMIN=$(curl -s -m 900 $NCREPO/ | sed --silent 's/.*href="nextcloud-\([^"]\+\).zip.asc".*/\1/p' | sort --version-sort | grep "${CURRENTVERSION%%.*}" | tail -1)
REPORTEDMAJ=""
REPORTEDMIN=""

if [ "$CURRENTVERSION" == "$NCVERSION" ] && [ "$CURRENTVERSION" == "$NCMIN" ]
then
    print_text_in_color "$IGreen" "You already run the latest version! ($NCVERSION)"
    exit
fi

if [ "$REPORTEDMAJ" == "$NCVERSION" ] && [ "$REPORTEDMIN" == "$NCMIN" ]
then
    print_text_in_color "$ICyan" "The notification regarding the new Nextcloud update has been already reported!"
    exit
fi

if [ "$NCVERSION" == "$NCMIN" ] && version_gt "$NCMIN" "$REPORTEDMIN"
then
    sed -i "s|^REPORTEDMAJ.*|REPORTEDMAJ=$NCVERSION|" $SCRIPTS/updatenotification.sh
    sed -i "s|^REPORTEDMIN.*|REPORTEDMIN=$NCMIN|" $SCRIPTS/updatenotification.sh
    if crontab -l -u root | grep -q $SCRIPTS/update.sh
    then
        notify_admin_gui \
        "New Nextcloud version!" \
        "Nextcloud $NCVERSION just became available. Since you are running Automatic Updates on Saturdays at $AUT_UPDATES_TIME:00, you don't need to bother about updating the server manually, as that's already taken care of."
    else
        notify_admin_gui \
        "Update available!" \
        "Nextcloud $NCVERSION is available. Please run 'sudo bash /var/scripts/update.sh' from your CLI to update your server."
    fi
    exit
fi

if version_gt "$NCMIN" "$REPORTEDMIN"
then
    sed -i "s|^REPORTEDMIN.*|REPORTEDMIN=$NCMIN|" $SCRIPTS/updatenotification.sh
    if crontab -l -u root | grep -q $SCRIPTS/update.sh
    then
        notify_admin_gui \
        "New Nextcloud version!" \
        "Nextcloud $NCMIN just became available. Since you are running Automatic Updates on Saturdays at $AUT_UPDATES_TIME:00, you don't need to bother about updating the server manually, as that's already taken care of."
    else
        notify_admin_gui \
        "Update available!" \
        "Nextcloud $NCMIN is available. Please run 'sudo bash /var/scripts/update.sh minor' from your CLI to update your server."
    fi
fi

if version_gt "$NCVERSION" "$REPORTEDMAJ"
then
    sed -i "s|^REPORTEDMAJ.*|REPORTEDMAJ=$NCVERSION|" $SCRIPTS/updatenotification.sh
    notify_admin_gui \
    "Update available!" \
    "Nextcloud $NCVERSION is available. Please run 'sudo bash /var/scripts/update.sh' from your CLI to update your server."
fi
