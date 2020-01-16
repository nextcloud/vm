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

if version_gt "$NCVERSION" "$CURRENTVERSION"
then
    notify_admin_gui \ ## TODO: change name of function everywhere else
    "Update availabile!" \
    "Nextcloud $NCVERSION is available. Please run 'sudo bash /var/scripts/update.sh' from your CLI to update your server."
else
    print_text_in_color "$IGreen" "You already run the latest version! ($NCVERSION)"
fi
