#!/bin/bash

# T&M Hansson IT AB © - 2026, https://www.hanssonit.se/
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

# Determines whether and which -d option smartctl needs for a given drive.
# Returns "" if no option is needed, the matching option value (e.g. "sat"),
# or "NONE" if no working option could be found.
get_smart_device_option() {
    local drive="$1"
    local output opt

    output=$(smartctl -a "$drive" 2>&1)
    if echo "$output" | grep -q 'SMART overall-health self-assessment test result:'
    then
        echo ""
        return
    fi

    for opt in sat sat,12 sat,16 usbjmicron usbsunplus usbcypress
    do
        if smartctl -a -d "$opt" "$drive" 2>&1 | grep -q 'SMART overall-health self-assessment test result:'
        then
            echo "$opt"
            return
        fi
    done

    echo "NONE"
}

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

# Update the local drive database so more USB bridges/controllers can be
# recognized automatically without needing an explicit -d option below.
print_text_in_color "$ICyan" "Updating smartctl drive database..."
update-smart-drivedb || print_text_in_color "$IRed" "Could not update the drive database, continuing anyway..."

# Test drives
print_text_in_color "$ICyan" "Testing if all drives support smart monitoring and are healthy..."
mapfile -t DRIVES <<< "$DRIVES"
declare -A DRIVE_OPTS
VALID_DRIVES=""
for drive in "${DRIVES[@]}"
do
    echo '#########################'
    print_text_in_color "$ICyan" "Testing /dev/$drive"

    SMART_TYPE=$(get_smart_device_option "/dev/$drive")
    if [ "$SMART_TYPE" = "NONE" ]
    then
        print_text_in_color "$IRed" "/dev/$drive doesn't support smart monitoring"
        msg_box "It seems like /dev/$drive doesn't support smart monitoring.
Already tried without success: sat, sat,12, sat,16, usbjmicron, usbsunplus, usbcypress.
Please check this script's output for more info!
Alternatively, run 'sudo smartctl -a -d <type> /dev/$drive' manually with a different -d type,
or check 'sudo smartctl -h' for all available device types."
        continue
    fi

    DRIVE_OPTS["$drive"]="$SMART_TYPE"

    if [ -n "$SMART_TYPE" ]
    then
        OUTPUT=$(smartctl -a -d "$SMART_TYPE" "/dev/$drive")
        MANUAL_CMD="sudo smartctl -a -d $SMART_TYPE /dev/$drive"
    else
        OUTPUT=$(smartctl -a "/dev/$drive")
        MANUAL_CMD="sudo smartctl -a /dev/$drive"
    fi

    if [[ "$drive" == nvme* ]]
    then
        # NVMe drives report their overall health via the PASSED status
        # and the "Critical Warning" field; the Error Information Log can
        # contain many harmless "Invalid Field in Command" entries which
        # don't indicate a real problem, so "No Errors Logged" isn't a
        # reliable check here.
        if ! echo "$OUTPUT" | grep -q 'SMART overall-health self-assessment test result: PASSED'
        then
            print_text_in_color "$IRed" "/dev/$drive isn't healthy"
            echo "$OUTPUT"
            msg_box "It seems like /dev/$drive isn't healthy.
Please check this script's output for more info!
Alternatively, run '$MANUAL_CMD' to check it manually."
        else
            print_text_in_color "$IGreen" "/dev/$drive supports smart monitoring and is healthy"
        fi
        VALID_DRIVES+="$drive"
    elif ! echo "$OUTPUT" | grep -q 'No Errors Logged' \
|| ! echo "$OUTPUT" | grep -q 'SMART overall-health self-assessment test result: PASSED'
    then
        print_text_in_color "$IRed" "/dev/$drive isn't healthy"
        echo "$OUTPUT"
        msg_box "It seems like /dev/$drive isn't healthy.
Please check this script's output for more info!
Alternatively, run '$MANUAL_CMD' to check it manually."
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
    # Build a literal "declare -A DRIVE_OPTS=(...)" block from the options
    # detected above, so the generated script doesn't need to re-detect
    # anything at runtime. This assumes the USB enclosure/bridge for each
    # drive does not change between runs.
    DRIVE_OPTS_DECL="declare -A DRIVE_OPTS=("
    for drive in "${!DRIVE_OPTS[@]}"
    do
        DRIVE_OPTS_DECL+=$'\n'"    [$drive]=\"${DRIVE_OPTS[$drive]}\""
    done
    DRIVE_OPTS_DECL+=$'\n'")"

    # Create smart notification script
    cat << SMART_NOTIFICATION > "$SCRIPTS/smart-notification.sh"
#!/bin/bash

# T&M Hansson IT AB © - 2026, https://www.hanssonit.se/
# Copyright © 2021 Simon Lindner (https://github.com/szaimen)

true
SCRIPT_NAME="S.M.A.R.T Notification"
SCRIPT_EXPLAINER="This script sends a notification if something is wrong with your drives."

# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh

# Check if root
root_check

# Options detected during setup, per drive (KNAME -> smartctl -d value).
# Assumes USB enclosures/bridges don't change between runs.
$DRIVE_OPTS_DECL

run_smartctl_all() {
    local drive="\$1"
    local kname
    kname=\$(basename "\$drive")
    if [ -v "DRIVE_OPTS[\$kname]" ] && [ -n "\${DRIVE_OPTS[\$kname]}" ]
    then
        smartctl --all -d "\${DRIVE_OPTS[\$kname]}" "\$drive"
    else
        smartctl --all "\$drive"
    fi
}

if home_sme_server
then
    notify_admin_gui "S.M.A.R.T results weekly scan (nvme0n1)" "\$(run_smartctl_all /dev/nvme0n1)"
    notify_admin_gui "S.M.A.R.T results weekly scan (sda)" "\$(run_smartctl_all /dev/sda)"
else
    # get all disks into an array
    disks="\$(fdisk -l | grep Disk | grep /dev/sd | awk '{print\$2}' | cut -d ":" -f1)"
    # loop over disks in array
    for disk in \$(printf "\${disks[@]}")
    do
        if [ -n "\$disks" ]
        then
             notify_admin_gui "S.M.A.R.T results weekly scan (\$disk)" "\$(run_smartctl_all \$disk)"
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
    # Write conf to file - one line per drive, so the per-drive detected
    # -d option (e.g. for USB enclosures) is taken into account.
    # https://wiki.debianforum.de/Festplattendiagnostik-_und_%C3%9Cberwachung#Beispiel_3
    : > /etc/smartd.conf
    for drive in "${!DRIVE_OPTS[@]}"
    do
        opt="${DRIVE_OPTS[$drive]}"
        DEV_OPT=""
        if [ -n "$opt" ]
        then
            DEV_OPT="-d $opt"
        fi
        echo "/dev/$drive $DEV_OPT -a -I 194 -W 5,45,55 -r 5 -R 5 -n standby,24 -m <nomailer> -M exec \
$SCRIPTS/smart-notification.sh -s (S/../.././01|L/../../6/02)" >> /etc/smartd.conf
    done

    # Create smart notification script
    cat << SMART_NOTIFICATION > "$SCRIPTS/smart-notification.sh"
#!/bin/bash

# T&M Hansson IT AB © - 2026, https://www.hanssonit.se/
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
