#!/bin/bash

# T&M Hansson IT AB © - 2020, https://www.hanssonit.se/

true
SCRIPT_NAME="Not-supported Menu"
# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh || source <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Must be root
root_check

# Main menu
choice=$(whiptail --title "$TITLE" --checklist \
"This is the Not-supported Menu of the Nextcloud VM!

Please note that all options that get offered to you are not part of the released version and thus not 100% ready.
So please run them on your own risk. Feedback is more than welcome, though and can get reported here: $ISSUES

Choose which one you want to execute.
$CHECKLIST_GUIDE" "$WT_HEIGHT" "$WT_WIDTH" 4 \
"Bitlocker Mount" "(Mount Bitlocker encrypted drives)" OFF \
"ClamAV" "(Antivirus for Nextcloud and files)" OFF \
"NTFS Mount" "(Mount NTFS (Windows) drives)" OFF \
"Backup Viewer" "(View your Backups)" OFF \
"Daily Backup Wizard" "(Create a Daily Backup script)" OFF \
"Off-Shore Backup Wizard" "(Create an Off-Shore Backup script)" OFF \
"Pi-hole" "(Network wide ads- and tracker blocking)" OFF \
"PiVPN" "(Install a Wireguard VPN server with PiVPN)" OFF \
"PLEX Media Server" "(Multimedia server application)" OFF \
"Remotedesktop" "(Install a remotedesktop based on xrdp)" OFF \
"SMB-server" "(Create and manage a SMB-server on OS level)" OFF 3>&1 1>&2 2>&3)

case "$choice" in
    *"Bitlocker Mount"*)
        print_text_in_color "$ICyan" "Downloading the Bitlocker Mount script..."
        run_script NOT_SUPPORTED_FOLDER bitlocker-mount
    ;;&
    *"ClamAV"*)
        print_text_in_color "$ICyan" "Downloading the ClamAV script..."
        run_script APP clamav
    ;;&
    *"NTFS Mount"*)
        print_text_in_color "$ICyan" "Downloading the NTFS Mount script..."
        run_script NOT_SUPPORTED_FOLDER ntfs-mount
    ;;&
    *"Backup Viewer"*)
        print_text_in_color "$ICyan" "Downloading the Daily Backup Viewer script..."
        run_script NOT_SUPPORTED_FOLDER backup-viewer
    ;;&
    *"Daily Backup Wizard"*)
        print_text_in_color "$ICyan" "Downloading the Daily Backup Wizard script..."
        run_script NOT_SUPPORTED_FOLDER daily-backup-wizard
    ;;&
    *"Off-Shore Backup Wizard"*)
        print_text_in_color "$ICyan" "Downloading the Off-Shore Backup Wizard script..."
        run_script NOT_SUPPORTED_FOLDER offshore-backup-wizard
    ;;&
    *"Pi-hole"*)
        print_text_in_color "$ICyan" "Downloading the Pi-hole script..."
        run_script NOT_SUPPORTED_FOLDER pi-hole
    ;;&
    *"PiVPN"*)
        print_text_in_color "$ICyan" "Downloading the PiVPN script..."
        run_script NOT_SUPPORTED_FOLDER pivpn
    ;;&
    *"PLEX Media Server"*)
        print_text_in_color "$ICyan" "Downloading the PLEX Media Server script..."
        run_script NOT_SUPPORTED_FOLDER plexmediaserver
    ;;&
    *"Remotedesktop"*)
        print_text_in_color "$ICyan" "Downloading the Remotedesktop script..."
        run_script NOT_SUPPORTED_FOLDER remotedesktop
    ;;&
    *"SMB-server"*)
        print_text_in_color "$ICyan" "Downloading the SMB Server script..."
        run_script NOT_SUPPORTED_FOLDER smbserver
    ;;&
    *)
    ;;
esac
exit
