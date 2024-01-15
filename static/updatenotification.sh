#!/bin/bash

# T&M Hansson IT AB © - 2024, https://www.hanssonit.se/

true
SCRIPT_NAME="Update Notification"
# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh

# Get all needed variables from the library
nc_update

print_text_in_color "$ICyan" "Checking for new Nextcloud version..."

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Check if root
root_check

NCMIN=$(curl -s -m 900 $NCREPO/ | sed --silent 's/.*href="nextcloud-\([^"]\+\).zip.asc".*/\1/p' | sort --version-sort | grep "${CURRENTVERSION%%.*}" | tail -1)
REPORTEDMAJ="$CURRENTVERSION"
REPORTEDMIN="$CURRENTVERSION"

# Check for supported Nextcloud version
if [ "${CURRENTVERSION%%.*}" -lt "$NCBAD" ]
then
    notify_admin_gui \
        "Your Nextcloud version is End of Life! Please upgrade as soon as possible!" \
        "Nextcloud ${CURRENTVERSION%%.*} doesn't get security updates anymore. \
You should because of that update to a supported Nextcloud version as soon as possible. \
You can check your Nextcloud with the security scanner: 'https://scan.nextcloud.com/'"
fi

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

if [ "$NCVERSION" == "$NCMIN" ] && version_gt "$NCMIN" "$REPORTEDMIN" && version_gt "$NCMIN" "$CURRENTVERSION"
then
    sed -i "s|^REPORTEDMAJ.*|REPORTEDMAJ=$NCVERSION|" $SCRIPTS/updatenotification.sh
    sed -i "s|^REPORTEDMIN.*|REPORTEDMIN=$NCMIN|" $SCRIPTS/updatenotification.sh
    if crontab -l -u root | grep -q $SCRIPTS/menu.sh
    then
        notify_admin_gui \
        "New minor Nextcloud Update!" \
        "Nextcloud $NCMIN just became available. Since you are running Automatic \
Updates every month on Saturdays at $AUT_UPDATES_TIME:00, you don't need to bother about updating \
the server to minor Nextcloud versions manually, as that's already taken care of."
    else
        notify_admin_gui \
        "New minor Nextcloud Update!" \
        "Nextcloud $NCMIN just became available. Please run 'sudo bash \
/var/scripts/menu.sh' --> Update Nextcloud from your CLI to update your server to Nextcloud $NCMIN."
    fi
    exit
fi

if version_gt "$NCMIN" "$REPORTEDMIN" && version_gt "$NCMIN" "$CURRENTVERSION"
then
    sed -i "s|^REPORTEDMIN.*|REPORTEDMIN=$NCMIN|" $SCRIPTS/updatenotification.sh
    if crontab -l -u root | grep -q $SCRIPTS/menu.sh
    then
        notify_admin_gui \
        "New minor Nextcloud Update!" \
        "Nextcloud $NCMIN just became available. Since you are running Automatic \
Updates on Saturdays at $AUT_UPDATES_TIME:00, you don't need to bother about updating \
the server to minor Nextcloud versions manually, as that's already taken care of."
    else
        notify_admin_gui \
        "New minor Nextcloud Update!" \
        "Nextcloud $NCMIN just became available. Please run 'sudo bash \
/var/scripts/menu.sh' --> Update Nextcloud from your CLI to update your server to Nextcloud $NCMIN."
    fi
fi

if version_gt "$NCVERSION" "$REPORTEDMAJ" && version_gt "$NCVERSION" "$CURRENTVERSION"
then
    sed -i "s|^REPORTEDMAJ.*|REPORTEDMAJ=$NCVERSION|" $SCRIPTS/updatenotification.sh
    notify_admin_gui \
    "New major Nextcloud Update!" \
    "Nextcloud $NCVERSION just became available. Please run 'sudo bash \
/var/scripts/menu.sh' --> Update Nextcloud from your CLI to update your server to Nextcloud $NCVERSION. \
Before updating though, you should visit https://your-nc-domain/settings/admin/overview \
and make sure that all apps are compatible with the new version. And please never forget to \
create a backup and/or snapshot before updating!"
fi
