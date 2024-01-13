#!/bin/bash

# T&M Hansson IT AB © - 2024, https://www.hanssonit.se/
# Copyright © 2021 Simon Lindner (https://github.com/szaimen)

true
SCRIPT_NAME="S.M.A.R.T Monitoring"
SCRIPT_EXPLAINER="This script configures S.M.A.R.T Monitoring for all your drives \
and sends a notification if an error was found."
# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh

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
    check_command apt-get purge smartmontools -y
    apt-get autoremove -y
    rm -f /etc/smartd.conf
    # reset the cronjob
    crontab -u root -l | grep -v 'smartctl.sh'  | crontab -u root -
    crontab -u root -l | grep -v 'smart-notification.sh'  | crontab -u root -
    # Show successful uninstall if applicable
    removal_popup "$SCRIPT_NAME"
fi

# Get all physical drives
DRIVES=$(lsblk -o KNAME,TYPE | grep disk | awk '{print $1}')
if [ -z "$DRIVES" ]
then
    msg_box "Not even one drive found. Cannot proceed."
    exit 1
fi

# Choose between direct notification or weekly
choice=$(whiptail --title "$TITLE" --menu \
"Please choose if you want to get informed weekly or directly if an error occurs.
$MENU_GUIDE\n\n$RUN_LATER_GUIDE" "$WT_HEIGHT" "$WT_WIDTH" 4 \
"Directly" "(Continuous S.M.A.R.T checking)" \
"Weekly" "(Weekly S.M.A.R.T checking)" 3>&1 1>&2 2>&3)

# Exit if nothing chosen
if [ -z "$choice" ]
then
    exit 1
fi

# Install needed tools
install_if_not smartmontools

# Test drives
print_text_in_color "$ICyan" "Testing if all drives support smart monitoring and are healthy..."
mapfile -t DRIVES <<< "$DRIVES"
for drive in "${DRIVES[@]}"
do
    echo '#########################'
    print_text_in_color "$ICyan" "Testing /dev/$drive"
    OUTPUT=$(smartctl -a "/dev/$drive")
    if ! echo "$OUTPUT" | grep -q 'SMART overall-health self-assessment test result:'
    then
        print_text_in_color "$IRed" "/dev/$drive doesn't support smart monitoring"
        echo "$OUTPUT"
        msg_box "It seems like /dev/$drive doesn't support smart monitoring.
Please check this script's output for more info!
Alternatively, run 'sudo smartctl -a /dev/$drive' to check it manually."
    elif ! echo "$OUTPUT" | grep -q 'No Errors Logged' \
|| ! echo "$OUTPUT" | grep -q 'SMART overall-health self-assessment test result: PASSED'
    then
        print_text_in_color "$IRed" "/dev/$drive isn't healthy"
        echo "$OUTPUT"
        msg_box "It seems like /dev/$drive isn't healthy.
Please check this script's output for more info!
Alternatively, run 'sudo smartctl -a /dev/$drive' to check it manually."
        VALID_DRIVES+="$drive"
    else
        print_text_in_color "$IGreen" "/dev/$drive supports smart monitoring and is healthy"
        VALID_DRIVES+="$drive"
    fi
done

# Test if at least one drive is healthy/suppports smart monitoring
if [ -z "$VALID_DRIVES" ]
then
    msg_box "It seems like not even one drive supports smart monitoring.
This is completely normal if you run this script in a VM since virtual drives don't support smart monitoring.
We will uninstall smart monitoring now since you won't get any helpful notification out of this going forward."
    apt-get purge smartmontools -y
    apt-get autoremove -y
    exit 1
fi

# Stop smartmontools for now
check_command systemctl stop smartmontools

# Weekly notification
if [ "$choice" = "Weekly" ]
then
    # Create smart notification script
    cat << SMART_NOTIFICATION > "$SCRIPTS/smart-notification.sh"
#!/bin/bash

# T&M Hansson IT AB © - 2024, https://www.hanssonit.se/
# Copyright © 2021 Simon Lindner (https://github.com/szaimen)

true
SCRIPT_NAME="S.M.A.R.T Notification"
SCRIPT_EXPLAINER="This script sends a notification if something is wrong with your drives."

# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh

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
$SCRIPTS/smart-notification.sh -s (S/../.././01|L/../../6/02)" > /etc/smartd.conf

    # Create smart notification script
    cat << SMART_NOTIFICATION > "$SCRIPTS/smart-notification.sh"
#!/bin/bash

# T&M Hansson IT AB © - 2024, https://www.hanssonit.se/
# Copyright © 2021 Simon Lindner (https://github.com/szaimen)

true
SCRIPT_NAME="S.M.A.R.T Notification"
SCRIPT_EXPLAINER="This script sends a notification if something is wrong with your drives."

# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh

# Check if root
root_check

# Send the message
if ! send_mail "\$SMARTD_FAILTYPE issue on \$SMARTD_DEVICE" \
"\$SMARTD_MESSAGE\n
You can find further information below!\n
\$(/usr/sbin/smartctl -a \$SMARTD_DEVICE)"
then
    notify_admin_gui "\$SMARTD_FAILTYPE issue on \$SMARTD_DEVICE" \
"\$SMARTD_MESSAGE\n
You might run 'sudo smartctl -a \$SMARTD_DEVICE' to get further information."
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
