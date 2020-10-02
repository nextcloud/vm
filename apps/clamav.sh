#!/bin/bash

# T&M Hansson IT AB © - 2020, https://www.hanssonit.se/

# shellcheck disable=2034,2059
true
SCRIPT_NAME="ClamAV"
SCRIPT_EXPLAINER="This script installs the open-source Antivirus-software ClamAV on your server \
and configures Nextcloud to detect infected files already during the upload.
At the end of the script, you will have the chance to setup a weekly full-scan of all files."
# shellcheck source=lib.sh
. <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Check if root
root_check

# Show explainer
explainer_popup

# Needs 1 GB alone
ram_check 3 "ClamAV"
cpu_check 2 "ClamAV"

# Check if webmin is already installed
print_text_in_color "$ICyan" "Checking if ClamAV is already installed..."
if is_this_installed clamav-daemon || is_this_installed clamav || is_this_installed clamav-freshclam
then
    # Ask for removal or reinstallation
    reinstall_remove_menu
    # Removal
    apt purge clamav-daemon -y
    apt purge clamav-freshclam -y
    apt purge clamav -y
    apt autoremove -y
    rm -f /etc/systemd/system/clamav-daemon.service
    rm -f "$SCRIPTS"/clamav-fullscan.sh
    rm -f "$VMLOGS"/clamav-fullscan.log
    crontab -u root -l | grep -v 'clamav-fullscan.sh'  | crontab -u root -
    if is_app_installed files_antivirus
    then
        occ_command_no_check app:remove files_antivirus
    fi
    # Show successful uninstall if applicable
    removal_popup
else
    print_text_in_color "$ICyan" "Installing ClamAV..."
fi

# Install needed tools
apt update -q4 & spinner_loading
apt install clamav clamav-freshclam clamav-daemon -y

# stop freshclam and update the database
check_command systemctl stop clamav-freshclam
check_command freshclam
check_command systemctl start clamav-freshclam

# Edit ClamAV settings to fit the installation
sed -i "s|^MaxDirectoryRecursion.*|MaxDirectoryRecursion 30|" /etc/clamav/clamd.conf
sed -i "s|^MaxFileSize.*|MaxFileSize 100M|" /etc/clamav/clamd.conf
sed -i "s|^PCREMaxFileSize.*|PCREMaxFileSize 100M|" /etc/clamav/clamd.conf
sed -i "s|^StreamMaxLength.*|StreamMaxLength 100M|" /etc/clamav/clamd.conf

# Start ClamAV
check_command systemctl restart clamav-freshclam
check_command systemctl restart clamav-daemon

# Make the service more reliable
check_command cp /lib/systemd/system/clamav-daemon.service /etc/systemd/system/clamav-daemon.service
sed -i '/\[Service\]/a Restart=always' /etc/systemd/system/clamav-daemon.service
sed -i '/\[Service\]/a RestartSec=3' /etc/systemd/system/clamav-daemon.service
check_command systemctl daemon-reload
check_command systemctl restart clamav-daemon

# Install Nextcloud app
install_and_enable_app files_antivirus

# Configure Nextcloud app
occ_command config:app:set files_antivirus av_mode --value="socket"
occ_command config:app:set files_antivirus av_socket --value="/var/run/clamav/clamd.ctl"
occ_command config:app:set files_antivirus av_stream_max_length --value="104857600"
occ_command config:app:set files_antivirus av_max_file_size --value="-1"
occ_command config:app:set files_antivirus av_infected_action --value="only_log"

# Inform the user
msg_box "ClamAV was succesfully installed.

Your Nextcloud should be safer now."

# Ask for full-scan
if ! yesno_box_yes "Do you want to setup a weekly full-scan of all files?
It will run on sundays starting at 10:00 for max 12h. 
You will be notified what the result was."
then
    exit
fi

choice=$(whiptail --title "$TITLE" --nocancel --menu \
"Choose should happen with infected files.
Infected files will always get reported to you no matter which option you choose.
$MENU_GUIDE\n\n$RUN_LATER_GUIDE" "$WT_HEIGHT" "$WT_WIDTH" 4 \
"Only log" "" \
"Copy to a folder" "" \
"Move to a folder" "" \
"Remove" "" 3>&1 1>&2 2>&3)

case "$choice" in
    "Only log")
        AV_PATH=""
    ;;
    "Copy to a folder")
        AV_PATH="/root/.clamav/clamav-fullscan.jail"
        msg_box "We will move/copy the files to '$AV_PATH'"
        mkdir -p "$AV_PATH"
        chown -R clamav:clamav "$AV_PATH"
        chmod -R 600 "$AV_PATH"
    ;;
    "Move to a folder")
        AV_PATH="/root/.clamav/clamav-fullscan.jail"
        msg_box "We will move/copy the files to '$AV_PATH'"
        mkdir -p "$AV_PATH"
        chown -R clamav:clamav "$AV_PATH"
        chmod -R 600 "$AV_PATH"
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

# T&M Hansson IT AB © - 2020, https://www.hanssonit.se/

. <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)

AV_REPORT="$(clamscan \
--recursive \
--stdout \
--infected \
--cross-fs \
--log=$VMLOGS/clamav-fullscan.log \
$ARGUMENT$AV_PATH \
--max-scantime=43200000 \
--max-filesize=1G \
--pcre-max-filesize=1G \
--max-dir-recursion=30 \
/ )"

notify_admin_gui \
"Your weekly full-scan ClamAV report" \
"$AV_REPORT"
CLAMAV_REPORT

# Make the script executable
chmod +x "$SCRIPTS"/clamav-fullscan.sh

# Create the cronjob
crontab -u root -l | { cat; echo "0 10 * * 7 $SCRIPTS/clamav-fullscan.sh 2>&1"; } | crontab -u root -

# Create the log-file
touch "$VMLOGS"/clamav-fullscan.log
chown clamav:clamav "$VMLOGS"/clamav-fullscan.log

# Inform the user
msg_box "The full-scan was successfully setup.
It will run on sundays starting at 10:00 for max 12h. 
You will be notified what the result was."

exit
