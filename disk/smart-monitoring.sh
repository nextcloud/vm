#!/bin/bash

# T&M Hansson IT AB © - 2020, https://www.hanssonit.se/
# Copyright © 2020 Simon Lindner (https://github.com/szaimen)

# shellcheck disable=2034,2059
true
SCRIPT_NAME="S.M.A.R.T Monitoring"
SCRIPT_EXPLAINER="This script configures S.M.A.R.T Monitoring for all your drives \
and sends a notification if an error was found."
# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh || source <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Check if root
root_check

# Check if bpytop is already installed
if ! [ -f "$SCRIPTS/smart-notification.sh" ]
then
    # Ask for installing
    install_popup "$SCRIPT_NAME"
else
    # Ask for removal or reinstallation
    reinstall_remove_menu "$SCRIPT_NAME"
    # Removal
    check_command rm "$SCRIPTS/smart-notification.sh"
    if is_this_installed smartmontools
    then
        apt purge smartmontools -y
        apt autoremove -y
    fi
    # Show successful uninstall if applicable
    removal_popup "$SCRIPT_NAME"
fi

# Install needed tools
install_if_not smartmontools
check_command systemctl stop smartmontools

# Write conf to file
# https://wiki.debianforum.de/Festplattendiagnostik-_und_%C3%9Cberwachung#Beispiel_3
echo "DEVICESCAN -a -I 194 -W 5,45,55 -r 5 -R 5 -n standby,24 -m <nomailer> -M exec $SCRIPTS/smart-notification.sh \
-s (O/../.././(06|18)|S/../../6/02|L/../20/./02)" > /etc/smartd.conf

# Create smart notification script
cat << SMART_NOTIFICATION > "$SCRIPTS/smart-notification.sh"
#!/bin/bash

# T&M Hansson IT AB © - 2020, https://www.hanssonit.se/
# Copyright © 2020 Simon Lindner (https://github.com/szaimen)

# shellcheck disable=2034,2059
true
SCRIPT_NAME="S.M.A.R.T Notification"
SCRIPT_EXPLAINER="This script sends a notification if something is wrong with your drives."

# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh || source <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)

# Check if root
root_check

# Save the message (STDIN) to the MESSAGE variable:
MESSAGE=\$(cat)

# Append the output of smartctl -a to the message:
MESSAGE+=\$(/usr/sbin/smartctl -a -d \$SMARTD_DEVICETYPE \$SMARTD_DEVICE)

# Now send the message
if ! send_mail "\$SMARTD_SUBJECT on \$SMARTD_DEVICE" "\$MESSAGE"
then
    notify_admin_gui "\$SMARTD_SUBJECT on \$SMARTD_DEVICE" "\$MESSAGE"
fi
exit
SMART_NOTIFICATION

# Make it executable
chmod +x "$SCRIPTS/smart-notification.sh"

# Restart service
check_command systemctl start smartmontools

msg_box "S.M.A.R.T Monitoring was successfully set up."

exit