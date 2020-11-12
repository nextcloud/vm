#!/bin/bash

# T&M Hansson IT AB © - 2020, https://www.hanssonit.se/
# Copyright © 2020 Simon Lindner (https://github.com/szaimen)

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
if ! is_this_installed smartmontools
then
    # Ask for installing
    install_popup "$SCRIPT_NAME"
else
    # Ask for removal or reinstallation
    reinstall_remove_menu "$SCRIPT_NAME"
    # Removal
    rm -f "$SCRIPTS/smart-notification.sh"
    check_command apt purge smartmontools -y
    apt autoremove -y
    rm -f /etc/smartd.conf
    # reset the cronjob
    crontab -u root -l | grep -v 'smartctl.sh'  | crontab -u root -
    crontab -u root -l | grep -v 'smart-notification.sh'  | crontab -u root -
    # Show successful uninstall if applicable
    removal_popup "$SCRIPT_NAME"
fi

# Choose between direct notifiaction or weekly
choice=$(whiptail --title "$TITLE" --menu \
"Please choose if you want to get informed weekly or directly if an error occurs.
$MENU_GUIDE\n\n$RUN_LATER_GUIDE" "$WT_HEIGHT" "$WT_WIDTH" 4 \
"Directly" "(Continous S.M.A.R.T checking)" \
"Weekly" "(Weekly S.M.A.R.T checking)" 3>&1 1>&2 2>&3)

# Exit if nothing chosen
if [ -z "$choice" ]
then
    exit 1
fi

# Install needed tools
install_if_not smartmontools
check_command systemctl stop smartmontools

# Weekly notification
if [ "$choice" = "Weekly" ]
then
    # Create smart notification script
    cat << SMART_NOTIFICATION > "$SCRIPTS/smart-notification.sh"
#!/bin/bash

# T&M Hansson IT AB © - 2020, https://www.hanssonit.se/
# Copyright © 2020 Simon Lindner (https://github.com/szaimen)

true
SCRIPT_NAME="S.M.A.R.T Notification"
SCRIPT_EXPLAINER="This script sends a notification if something is wrong with your drives."

# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh || source <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)

# Check if root
root_check
if home_sme_server
then
    notify_admin_gui "S.M.A.R.T results weekly scan (nvme0n1)" "\$(smartctl --all /dev/nvme0n1)"
    notify_admin_gui "S.M.A.R.T results weekly scan (sda)" "\$(smartctl --all /dev/sda)"
else
    # get all disks into an array
    disks="\$(fdisk -l | grep Disk | grep /dev/sd | awk '{print\$2}' | cut -d ":" -f1)"
    # loop over disks in array
    for disk in \$(printf "\${disks[@]}")
    do
        if [ -n "\$disks" ]
        then
             notify_admin_gui "S.M.A.R.T results weekly scan (\$disk)" "\$(smartctl --all \$disk)"
        fi
    done
fi
SMART_NOTIFICATION
    # Add crontab “At 06:12 on Monday.”
    if ! crontab -u root -l | grep -w 'smart-notification.sh'
    then
        print_text_in_color "$ICyan" "Adding weekly crontab..."
        crontab -u root -l | { cat; echo "12 06 * * 1 $SCRIPTS/smart-notification.sh"; } | crontab -u root -
    fi
# Direct notification
elif [ "$choice" = "Directly" ]
then
    # Write conf to file
    # https://wiki.debianforum.de/Festplattendiagnostik-_und_%C3%9Cberwachung#Beispiel_3
    echo "DEVICESCAN -a -I 194 -W 5,45,55 -r 5 -R 5 -n standby,24 -m <nomailer> -M exec \
$SCRIPTS/smart-notification.sh -s (O/../../(2|4|6)/02|S/../../5/02|L/../20/./02)" > /etc/smartd.conf

    # Create smart notification script
    cat << SMART_NOTIFICATION > "$SCRIPTS/smart-notification.sh"
#!/bin/bash

# T&M Hansson IT AB © - 2020, https://www.hanssonit.se/
# Copyright © 2020 Simon Lindner (https://github.com/szaimen)

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
fi

# Make it executable
chown root:root "$SCRIPTS/smart-notification.sh"
chmod 700 "$SCRIPTS/smart-notification.sh"

# Restart service
if start_if_stopped smartmontools
then
    msg_box "S.M.A.R.T Monitoring was successfully set up."
else
    msg_box "Starting smartmontools failed!"
fi
exit
