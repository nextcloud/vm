#!/bin/bash

# T&M Hansson IT AB © - 2021, https://www.hanssonit.se/

true
SCRIPT_NAME="ClamAV"
SCRIPT_EXPLAINER="This script installs the open-source antivirus-software ClamAV on your server \
and configures Nextcloud to detect infected files already during the upload.
At the end of the script, you will be able to choose to set up a weekly full scan of all files."
# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh || source <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Check if root
root_check

# Check if webmin is already installed
if ! is_this_installed clamav-daemon && ! is_this_installed clamav && ! is_this_installed clamav-freshclam
then
    # Ask for installing
    install_popup "$SCRIPT_NAME"
else
    # Ask for removal or reinstallation
    reinstall_remove_menu "$SCRIPT_NAME"
    # Removal
    apt purge clamav-daemon -y
    apt purge clamav-freshclam -y
    apt purge clamav -y
    apt autoremove -y
    rm -f /etc/systemd/system/clamav-daemon.service
    rm -f "$SCRIPTS"/clamav-fullscan.sh
    rm -f "$VMLOGS"/clamav-fullscan.log
    rm -f "$SCRIPTS/nextcloud-av-notification.sh"
    crontab -u root -l | grep -v 'clamav-fullscan.sh'  | crontab -u root -
    crontab -u root -l | grep -v 'nextcloud-av-notification.sh'  | crontab -u root -
    if is_app_installed files_antivirus
    then
        nextcloud_occ_no_check app:remove files_antivirus
    fi
    # Show successful uninstall if applicable
    removal_popup "$SCRIPT_NAME"
fi

# Needs 1 GB alone
ram_check 3 "ClamAV"
cpu_check 2 "ClamAV"

# Install needed tools
apt update -q4 & spinner_loading
apt install clamav clamav-freshclam clamav-daemon -y

# stop freshclam and update the database
check_command systemctl stop clamav-freshclam
check_command freshclam
start_if_stopped clamav-freshclam

# Edit ClamAV settings to fit the installation
sed -i "s|^MaxDirectoryRecursion.*|MaxDirectoryRecursion 30|" /etc/clamav/clamd.conf
sed -i "s|^MaxFileSize.*|MaxFileSize 100M|" /etc/clamav/clamd.conf
sed -i "s|^PCREMaxFileSize.*|PCREMaxFileSize 100M|" /etc/clamav/clamd.conf
sed -i "s|^StreamMaxLength.*|StreamMaxLength 100M|" /etc/clamav/clamd.conf

# Start ClamAV
check_command systemctl restart clamav-freshclam
check_command systemctl restart clamav-daemon

print_text_in_color "$ICyan" "Waiting for ClamAV daemon to start up. This can take a while... (max 60s)"
counter=0
while ! [ -a "/var/run/clamav/clamd.ctl" ] && [ "$counter" -lt 12 ]
do
    sleep 5 & spinner_loading
    ((counter++))
done

# Check if clamd exists now
if ! [ -a "/var/run/clamav/clamd.ctl" ]
then
    msg_box "Failed to start the ClamAV daemon.
Please report this to $ISSUES"
    exit 1
fi

# Make the service more reliable
check_command cp /lib/systemd/system/clamav-daemon.service /etc/systemd/system/clamav-daemon.service
sed -i '/\[Service\]/a Restart=always' /etc/systemd/system/clamav-daemon.service
sed -i '/\[Service\]/a RestartSec=3' /etc/systemd/system/clamav-daemon.service
check_command systemctl daemon-reload
check_command systemctl restart clamav-daemon

# Install Nextcloud app
echo ""
install_and_enable_app files_antivirus

# Configure Nextcloud app
nextcloud_occ config:app:set files_antivirus av_mode --value="socket"
nextcloud_occ config:app:set files_antivirus av_socket --value="/var/run/clamav/clamd.ctl"
nextcloud_occ config:app:set files_antivirus av_stream_max_length --value="104857600"
nextcloud_occ config:app:set files_antivirus av_max_file_size --value="-1"
nextcloud_occ config:app:set files_antivirus av_infected_action --value="only_log"

# Create av notification script
SCRIPT_PATH="$SCRIPTS/nextcloud-av-notification.sh"
cat << AV_NOTIFICATION >> "$SCRIPT_PATH"
#!/bin/bash

# T&M Hansson IT AB © - 2021, https://www.hanssonit.se/
# Copyright © 2021 Simon Lindner (https://github.com/szaimen)
# Copyright © Georgiy Sitnikov
# Inspired by/based on https://github.com/GAS85/nextcloud_scripts/blob/master/nextcloud-av-notification.sh

SCRIPT_NAME="Nextcloud Antivirus Notification"
SCRIPT_EXPLAINER="This script sends notifications about infected files."

# Variables
lastMinutes=30
LOGFILE="/var/log/nextcloud/nextcloud.log"
tempfile="/tmp/nextcloud_av_notofications-\$(date +"%M-%N").tmp"
getCurrentTimeZone=\$(date +"%:::z")
getCurrentTimeZone="\${getCurrentTimeZone:1}"
timeShiftTo=\$((60 * \$getCurrentTimeZone))
timeShiftFrom=\$((60 * \$getCurrentTimeZone + \$lastMinutes))
dateFrom=\$(date --date="-\$timeShiftFrom min" "+%Y-%m-%dT%H:%M:00+00:00")
dateTo=\$(date --date="-\$timeShiftTo min" "+%Y-%m-%dT%H:%M:00+00:00")

# Check if nextcloud.log exist
if ! [ -f "\$LOGFILE" ]
then
    exit
fi

# Extract logs for a last defined minutes
awk -v d1="\$dateFrom" -v d2="\$dateTo" -F'["]' '\$10 > d1 && \$10 < d2 || \$10 ~ d2' "\$LOGFILE" \
| grep "Infected file" | awk -F'["]' '{print \$34}' > "\$tempfile"

# Extract logs for a last defined minutes, from a ROTATED log if present
if test "\$(find "\$LOGFILE.1" -mmin -"\$lastMinutes")"
then
    awk -v d1="\$dateFrom" -v d2="\$dateTo" -F'["]' '\$10 > d1 && \$10 < d2 || \$10 ~ d2' "\$LOGFILE.1" \
| grep "Infected file" | awk -F'["]' '{print \$34}' >> "\$tempfile"
fi

# Exit if no results found
if ! [ -s "\$tempfile" ]
then
    rm "\$tempfile"
    exit
fi

# Load the library if an infected file was found
# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh || source <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)

# Check if root
root_check

# Send notification
WORDS=(found deleted)
for toFind in "\${WORDS[@]}"
do
    if grep -q "\$toFind" "\$tempfile"
    then
        # Prepare output
        grep "\$toFind" "\$tempfile" | awk '{\$1=""; \$2 = ""; \$3 = "";\$4 = ""; \$5 = ""; \$6 = ""; print \$0}' \
| sed -r -e 's|appdata_.{12}||' | sed 's|   ||g' > "\$tempfile.output"

        # Send notification
        notify_admin_gui \
        "Nextcloud Antivirus - Infected File(s) \$toFind!" \
        "\$(cat "\$tempfile.output" | cut -c -4000)"
    fi
done

rm "\$tempfile"
rm "\$tempfile.output"

exit
AV_NOTIFICATION

chown root:root "$SCRIPT_PATH"
chmod 700 "$SCRIPT_PATH"

# Create the cronjob
crontab -u root -l | grep -v "$SCRIPT_PATH" | crontab -u root -
crontab -u root -l | { cat; echo "*/30 * * * * $SCRIPT_PATH > /dev/null 2>&1"; } | crontab -u root -

# Inform the user
msg_box "ClamAV was successfully installed.

Your Nextcloud should be more secure now."

# Ask for full-scan
if ! yesno_box_yes "Do you want to set up a weekly full scan of all your files?
It will run on Sundays starting at 10:00.
The first scan will scan all your files. 
All following scans will only scan files that were changed during the week.
You will be notified when it's finished so that you can check the final result."
then
    exit
fi

choice=$(whiptail --title "$TITLE" --nocancel --menu \
"Choose what should happen with infected files.
Infected files will always get reported to you no matter which option you choose.
$MENU_GUIDE\n\n$RUN_LATER_GUIDE" "$WT_HEIGHT" "$WT_WIDTH" 4 \
"Only log" "" \
"Copy to a folder" "" \
"Move to a folder" "" \
"Remove" "" 3>&1 1>&2 2>&3)

case "$choice" in
    "Only log")
        ARGUMENT=""
        AV_PATH=""
    ;;
    "Copy to a folder")
        ARGUMENT="--copy="
        AV_PATH="/root/.clamav/clamav-fullscan.jail"
        msg_box "We will copy the files to '$AV_PATH'"
        mkdir -p "$AV_PATH"
        chown -R clamav:clamav "$AV_PATH"
        chmod -R 600 "$AV_PATH"
        EXCLUDE_AV_PATH="--exclude-dir=$AV_PATH/"
    ;;
    "Move to a folder")
        ARGUMENT="--move="
        AV_PATH="/root/.clamav/clamav-fullscan.jail"
        msg_box "We will move the files to '$AV_PATH'"
        mkdir -p "$AV_PATH"
        chown -R clamav:clamav "$AV_PATH"
        chmod -R 600 "$AV_PATH"
        EXCLUDE_AV_PATH="--exclude-dir=$AV_PATH/"
    ;;
    "Remove")
        ARGUMENT="--remove=yes"
        AV_PATH=""
    ;;
    "")
        exit 1
    ;;
    *)
    ;;
esac

# Create the full-scan script
cat << CLAMAV_REPORT > "$SCRIPTS"/clamav-fullscan.sh
#!/bin/bash

# T&M Hansson IT AB © - 2021, https://www.hanssonit.se/

source /var/scripts/fetch_lib.sh || source <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)

# Variables/arrays
FULLSCAN_DONE=""
FIND_OPTS=(-maxdepth 30 -type f -not -path "/proc/*" -not -path "/sys/*" -not -path "/dev/*" -not -path "*/.snapshots/*")

# Exit if clamscan is already running
if pgrep clamscan &>/dev/null
then
    exit
fi

# Only scan for changed files in the last week if initial full-scan is done
if [ -n "\$FULLSCAN_DONE" ]
then
    FIND_OPTS+=(-ctime -7)
fi

# Find all applicable files
find / "\${FIND_OPTS[@]}" | tee /tmp/scanlist

# Run the scan and delete the temp file afterwards
clamscan \
"$ARGUMENT$AV_PATH" \
--file-list=/tmp/scanlist \
--max-filesize=1000M \
--pcre-max-filesize=1000M \
"$EXCLUDE_AV_PATH" \
| tee "$VMLOGS/clamav-fullscan.log" \
&& rm -f /tmp/scanlist

# Set the full-scan variable to done
if [ -z "\$FULLSCAN_DONE" ]
then
    sed -i "s|^FULLSCAN_DONE.*|FULLSCAN_DONE=1|"  "$SCRIPTS"/clamav-fullscan.sh
fi

# Send notification
notify_admin_gui \
"Your weekly full-scan ClamAV report" \
"\$(sed -n '/----------- SCAN SUMMARY -----------/,\$p' $VMLOGS/clamav-fullscan.log)\n
\$(grep -i infected $VMLOGS/clamav-fullscan.log | grep -v "Infected files:")"
CLAMAV_REPORT

# Make the script executable
chmod +x "$SCRIPTS"/clamav-fullscan.sh

# Create the cronjob
crontab -u root -l | grep -v "$SCRIPTS/clamav-fullscan.sh" | crontab -u root -
crontab -u root -l | { cat; echo "0 10 * * 7 $SCRIPTS/clamav-fullscan.sh > /dev/null"; } | crontab -u root -

# Create the log-file
touch "$VMLOGS"/clamav-fullscan.log
chown clamav:clamav "$VMLOGS"/clamav-fullscan.log

# Inform the user
msg_box "The full scan was successfully set up.
It will run on Sundays starting at 10:00.
The first scan will scan all your files. 
All following scans will only scan files that were changed during the week.
You will be notified when it's finished so that you can check the final result."
