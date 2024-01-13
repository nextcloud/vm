#!/bin/bash

# T&M Hansson IT AB © - 2024, https://www.hanssonit.se/

true
SCRIPT_NAME="Monitor Link Shares"
SCRIPT_EXPLAINER="This script creates a script which monitors link shares and sends a mail or notification if new link shares were created in Nextcloud."
# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Check if root
root_check

# Check if the script is already installed
if ! [ -f "$SCRIPTS/audit-link-shares.sh" ]
then
    # Ask for installing
    install_popup "$SCRIPT_NAME"
else
    # Ask for removal or reinstallation
    reinstall_remove_menu "$SCRIPT_NAME"
    # Removal
    rm "$SCRIPTS/audit-link-shares.sh"
    crontab -u root -l | grep -v "$SCRIPTS/audit-link-shares.sh"  | crontab -u root -
    # Show successful uninstall if applicable
    removal_popup "$SCRIPT_NAME"
fi

# Create script
cat << MONITOR_LINK_SHARES > "$SCRIPTS/audit-link-shares.sh"
#!/bin/bash

LINK_SHARE="\$(timeout 30m tail -n0 -f "$VMLOGS/audit.log" | grep "has been shared via link")"
if [ -z "\$LINK_SHARE" ]
then
    exit
fi

source "$SCRIPTS/fetch_lib.sh"
LINK_SHARE="\$(prettify_json "\$LINK_SHARE")"
FILES_FOLDERS="\$(echo "\$LINK_SHARE" | grep '"message":' | sed 's|.*"message": "||;s| with ID ".*||' | sort | uniq)"
if ! send_mail "Link share was created" "The following files/folders have been shared via link:
\$FILES_FOLDERS\n
See the full log below:
\$LINK_SHARE"
then
    notify_admin_gui "Link share was created" "The following files/folders have been shared via link:
\$FILES_FOLDERS"
fi
MONITOR_LINK_SHARES

# Adjust rights
chown root:root "$SCRIPTS/audit-link-shares.sh"
chmod 700 "$SCRIPTS/audit-link-shares.sh"

# Create cronjob
crontab -u root -l | grep -v "$SCRIPTS/audit-link-shares.sh"  | crontab -u root -
crontab -u root -l | { cat; echo "*/30 * * * * $SCRIPTS/audit-link-shares.sh >/dev/null" ; } | crontab -u root -

# enable admin_audit app
install_and_enable_app admin_audit

msg_box "$SCRIPT_NAME was successfully configured!
You will get a mail if new link shares were created."
