#!/bin/bash

# T&M Hansson IT AB © - 2024, https://www.hanssonit.se/

true
SCRIPT_NAME="Automatic Updates"
# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh
SCRIPT_EXPLAINER="This option will update your server once every month on Saturdays at $AUT_UPDATES_TIME:00.
The update will run the built in script '$SCRIPTS/update.sh' which will update both the server packages and Nextcloud itself.\n
You can read more about it here: https://www.techandme.se/nextcloud-update-is-now-fully-automated/
Please keep in mind that automatic updates might fail, which is why it's \
important to have a proper backup in place if you plan to run this option."

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Check if root
root_check

# Check if automatic updates are already installed
if ! crontab -u root -l | grep -q "$SCRIPTS/update.sh" && ! grep -r shutdown "$SCRIPTS/update.sh"
then
    # Ask for installing
    install_popup "$SCRIPT_NAME"
else
    # Ask for removal or reinstallation
    reinstall_remove_menu "$SCRIPT_NAME"
    # Removal
    crontab -u root -l | grep -v "$SCRIPTS/update.sh"  | crontab -u root -
    sed -i '/shutdown/d' "$SCRIPTS/update.sh"
    sed -i '/reboot/d' "$SCRIPTS/update.sh"
    # Show successful uninstall if applicable
    removal_popup "$SCRIPT_NAME"
fi

# Install automatic updates
mkdir -p "$VMLOGS"/updates
crontab -u root -l | { cat; echo "0 $AUT_UPDATES_TIME * 1-12 6 $SCRIPTS/update.sh minor >> $VMLOGS/updates/update-\$(date +\%Y-\%m-\%d_\%H:\%M).log 2>&1"; } | crontab -u root -
if yesno_box_yes "Do you want to reboot your server after every update? *recommended*"
then
    sed -i "s|exit|/sbin/shutdown -r +10|g" "$SCRIPTS"/update.sh
    echo "exit" >> "$SCRIPTS"/update.sh
fi

msg_box "Please remember to keep backups in case something would go wrong!"

exit
