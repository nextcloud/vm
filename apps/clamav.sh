#!/bin/bash

# T&M Hansson IT AB © - 2024, https://www.hanssonit.se/

true
SCRIPT_NAME="ClamAV"
SCRIPT_EXPLAINER="This script installs the open-source antivirus-software ClamAV on your server \
and configures Nextcloud to detect infected files already during the upload.
At the end of the script, you will be able to choose to set up a weekly full scan of all files."
# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh

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
    apt-get purge clamav-daemon -y
    apt-get purge clamav-freshclam -y
    apt-get purge clamav -y
    apt-get autoremove -y
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
install_if_not clamav
install_if_not clamav-freshclam
install_if_not clamav-daemon

# stop freshclam and update the database
check_command systemctl stop clamav-freshclam
check_command freshclam
start_if_stopped clamav-freshclam

# Edit ClamAV settings to fit the installation
sed -i "s|^MaxDirectoryRecursion.*|MaxDirectoryRecursion 30|" /etc/clamav/clamd.conf
sed -i "s|^MaxFileSize.*|MaxFileSize 1000M|" /etc/clamav/clamd.conf
sed -i "s|^PCREMaxFileSize.*|PCREMaxFileSize 1000M|" /etc/clamav/clamd.conf
sed -i "s|^StreamMaxLength.*|StreamMaxLength 1000M|" /etc/clamav/clamd.conf

# Start ClamAV
check_command systemctl restart clamav-freshclam
check_command systemctl restart clamav-daemon

print_text_in_color "$ICyan" "Waiting for ClamAV daemon to start up. This can take a while... (max 60s)"
counter=0
while ! [ -e "/var/run/clamav/clamd.ctl" ] && [ "$counter" -lt 12 ]
do
    countdown "Waiting for ClamAV to start..." "10"
    ((counter++))
done

# Check if clamd exists now
if ! [ -e "/var/run/clamav/clamd.ctl" ]
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
nextcloud_occ config:app:set files_antivirus av_stream_max_length --value="1048576000"
nextcloud_occ config:app:set files_antivirus av_max_file_size --value="1048576000"
nextcloud_occ config:app:set files_antivirus av_infected_action --value="only_log"

# Create av notification script
SCRIPT_PATH="$SCRIPTS/nextcloud-av-notification.sh"
cat << AV_NOTIFICATION >> "$SCRIPT_PATH"
#!/bin/bash

INFECTED_FILES_LOG="\$(timeout 30m tail -n0 -f "$VMLOGS/nextcloud.log" | grep "Infected file" | grep '"level":4,')"
if [ -z "\$INFECTED_FILES_LOG" ]
then
    exit
fi

source "$SCRIPTS/fetch_lib.sh"
INFECTED_FILES_LOG="\$(prettify_json "\$INFECTED_FILES_LOG")"
INFECTED_FILES="\$(echo "\$INFECTED_FILES_LOG" | grep '"message":' | sed 's|.*"message": "||;s| File: .*||' | sort | uniq)"

if ! send_mail "Virus was found" "The following action was executed by the antivirus app:
\$INFECTED_FILES\n
See the full log below:
\$INFECTED_FILES_LOG"
then
    notify_admin_gui "Virus was found" "The following action was executed by the antivirus app:
\$INFECTED_FILES"
fi
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

# T&M Hansson IT AB © - 2024, https://www.hanssonit.se/

source /var/scripts/fetch_lib.sh

# Variables/arrays
FULLSCAN_DONE=""
FIND_OPTS=(-maxdepth 30 -type f -not -path "/proc/*" -not -path "/sys/*" -not -path "/dev/*" -not -path "*/.snapshots/*")

# Exit if clamscan is already running
if pgrep clamscan &>/dev/null
then
    exit
fi

# Send mail that backup was started
if ! send_mail "Weekly ClamAV scan started." "You will be notified again when the scan is finished!"
then
    notify_admin_gui "Weekly ClamAV scan started." "You will be notified again when the scan is finished!"
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

INFECTED_FILES_LOG="\$(sed -n '/----------- SCAN SUMMARY -----------/,\$p' $VMLOGS/clamav-fullscan.log)"
INFECTED_FILES="\$(grep 'FOUND$' $VMLOGS/clamav-fullscan.log)"

if [ -z "$INFECTED_FILES" ]
then
    INFECTED_FILES="No infected files found"
fi

# Send notification
if ! send_mail "Your weekly full-scan ClamAV report" "\$INFECTED_FILES_LOG\n
\$INFECTED_FILES"
then
    notify_admin_gui "Your weekly full-scan ClamAV report" "\$INFECTED_FILES_LOG\n
\$INFECTED_FILES"
fi
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
