#!/bin/bash

# T&M Hansson IT AB © - 2026, https://www.hanssonit.se/
# Copyright © 2026 Simon Lindner (https://github.com/szaimen)

true
SCRIPT_NAME="Restrict Admin Login to private IP-ranges"
SCRIPT_EXPLAINER="This script restricts all Nextcloud admin actions to the private IP-ranges.
If your IP-address is not inside one of those ranges, the admin settings are hidden \
and every admin action is denied with a '403 Forbidden' - even for the admin user itself.

ATTENTION! Please only configure this if you have split-brain DNS set up!
(E.g. after configuring Pi-hole or your router as a local DNS server, so that your Nextcloud domain \
resolves to the *local* IP-address of this server while you are at home.)

Without split-brain DNS, your traffic from inside your network is routed over your public IP-address \
(NAT hairpinning), or you reach the server from the outside. Nextcloud will then see a public \
IP-address instead of a local one, and you will lock yourself out of all admin settings!"
# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Must be root
root_check

# Needs Nextcloud 30 or above, since the 'allowed_admin_ranges' setting was introduced there
# https://github.com/nextcloud/server/pull/46473
nc_update
if ! [ "${CURRENTVERSION%%.*}" -ge "30" ] 2>/dev/null
then
    msg_box "This script requires Nextcloud 30 or above, because the needed \
'allowed_admin_ranges' setting was introduced in Nextcloud 30.

You are currently running Nextcloud $CURRENTVERSION.
Please update your Nextcloud by running 'sudo bash $SCRIPTS/update.sh' and try again."
    exit 1
fi

# Check if it is already configured
if [ -z "$(nextcloud_occ_no_check config:system:get allowed_admin_ranges 2>/dev/null)" ]
then
    # Ask for installing
    install_popup "$SCRIPT_NAME"
else
    # Ask for removal or reinstallation
    reinstall_remove_menu "$SCRIPT_NAME"
    # Only remove it here if uninstalling, since reinstalling might still get aborted below
    if [ "$REINSTALL_REMOVE" = "Uninstall" ]
    then
        nextcloud_occ config:system:delete allowed_admin_ranges
    fi
    # Show successful uninstall if applicable
    removal_popup "$SCRIPT_NAME"
fi

# Make sure that the admin is aware of the split-brain DNS requirement
msg_box "Please read this carefully!

For this feature to work, Nextcloud needs to see a *local* IP-address when you connect to it \
from inside your network. This only works if:

1. You have split-brain DNS set up, e.g. with Pi-hole or your router, so that your Nextcloud \
domain points to the local IP-address of this server ($ADDRESS) while you are at home.
   - or -
2. You always access the admin settings directly via the local IP-address or local hostname \
of this server.

If neither is true, you will NOT be able to use the admin settings anymore after running this script!"

if ! yesno_box_no "Do you have split-brain DNS set up (or do you always access this server \
via its local address)?"
then
    msg_box "OK, nothing was changed.

You can set up split-brain DNS first, e.g. by installing Pi-hole as a local DNS server, \
and run this script again afterwards by running:
sudo bash $SCRIPTS/menu.sh --> Server Configuration --> $SCRIPT_NAME"

    # Offer to set up Pi-hole as local DNS server right away
    if yesno_box_no "Do you want to install Pi-hole as a local DNS server now?"
    then
        print_text_in_color "$ICyan" "Downloading the Pi-hole script..."
        run_script NOT_SUPPORTED_FOLDER pi-hole
    fi
    exit 1
fi

# All private IP-ranges, which are not reachable from the internet.
# Allowing all of them makes it less likely to lock yourself out.
ALLOWED_RANGES=(
"127.0.0.0/8"    # Localhost - this server itself
"10.0.0.0/8"     # Private IPv4-range
"172.16.0.0/12"  # Private IPv4-range - e.g. used by Docker
"192.168.0.0/16" # Private IPv4-range - most common in home networks
"::1/128"        # Localhost IPv6
"fc00::/7"       # Private IPv6-range - Unique Local Addresses
"fe80::/10"      # Link-local IPv6-range
)

# Show a last summary before applying
PRINT_RANGES="$(printf '%s\n' "${ALLOWED_RANGES[@]}")"
if ! yesno_box_yes "All private IP-ranges will be allowed to perform admin actions:

$PRINT_RANGES

Admin actions from every other IP-address will be denied.
Do you want to apply this now?"
then
    msg_box "OK, nothing was changed."
    exit 1
fi

# Apply the configuration
# Delete it first so that no old entries can survive
nextcloud_occ_no_check config:system:delete allowed_admin_ranges
count=0
for range in "${ALLOWED_RANGES[@]}"
do
    print_text_in_color "$ICyan" "Allowing admin actions from $range..."
    nextcloud_occ config:system:set allowed_admin_ranges "$count" --value="$range"
    count=$((count+1))
done

msg_box "Admin actions are now restricted to the following IP-ranges:

$PRINT_RANGES"

msg_box "Please note:
- The admin settings are now hidden and forbidden for every connection from outside those ranges.
- If you accidentally locked yourself out, you can remove the restriction from the \
terminal of this server by becoming root with 'sudo -i' and running:
  nextcloud_occ config:system:delete allowed_admin_ranges
- You can also remove it by running: sudo bash $SCRIPTS/menu.sh \
--> Server Configuration --> $SCRIPT_NAME --> Uninstall"

exit
