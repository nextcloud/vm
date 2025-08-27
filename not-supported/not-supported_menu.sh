#!/bin/bash

# T&M Hansson IT AB © - 2024, https://www.hanssonit.se/

true
SCRIPT_NAME="Not-supported Menu"
# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh

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
"BTRFS Format" "(Format drives to BTRFS)" OFF \
"BTRFS Mount" "(Mount BTRFS drives)" OFF \
"BTRFS Veracrypt" "(Format, encrypt and mount Veracrypt BTRFS drives)" OFF \
"NTFS Format" "(Format drives to NTFS)" OFF \
"NTFS Mount" "(Mount NTFS drives)" OFF \
"NTFS Veracrypt" "(Format, encrypt and mount Veracrypt NTFS drives)" OFF \
"Backup Viewer" "(View your Backups)" OFF \
"Restic Cloud Backup" "(Backup your server using Restic to multiple clouds)" OFF \
"Daily Backup Wizard" "(Create a Daily Backup script)" OFF \
"Firewall" "(Setting up a firewall)" OFF \
"Monitor Link Shares" "(Monitors the creation of link shares)" OFF \
"Off-Shore Backup Wizard" "(Create an Off-Shore Backup script)" OFF \
"Pi-hole" "(Network wide ads- and tracker blocking)" OFF \
"PiVPN" "(Install a Wireguard VPN server with PiVPN)" OFF \
"PLEX Media Server" "(Multimedia server application)" OFF \
"Remotedesktop" "(Install a remotedesktop based on xrdp)" OFF \
"SMB-server" "(Create and manage a SMB-server on OS level)" OFF \
"System Restore" "(Restore the system partition from a backup)" OFF 3>&1 1>&2 2>&3)

case "$choice" in
    *"BTRFS Format"*)
        print_text_in_color "$ICyan" "Downloading the BTRFS Format script..."
        run_script NOT_SUPPORTED_FOLDER btrfs-format
    ;;&
    *"BTRFS Mount"*)
        print_text_in_color "$ICyan" "Downloading the BTRFS Mount script..."
        run_script NOT_SUPPORTED_FOLDER btrfs-mount
    ;;&
    *"BTRFS Veracrypt"*)
        print_text_in_color "$ICyan" "Downloading the Veracrypt script..."
        run_script NOT_SUPPORTED_FOLDER veracrypt-btrfs
    ;;&
    *"NTFS Format"*)
        print_text_in_color "$ICyan" "Downloading the NTFS Format script..."
        run_script NOT_SUPPORTED_FOLDER ntfs-format
    ;;&
    *"NTFS Mount"*)
        print_text_in_color "$ICyan" "Downloading the NTFS Mount script..."
        run_script NOT_SUPPORTED_FOLDER ntfs-mount
    ;;&
    *"NTFS Veracrypt"*)
        print_text_in_color "$ICyan" "Downloading the Veracrypt script..."
        run_script NOT_SUPPORTED_FOLDER veracrypt-ntfs
    ;;&
    *"Backup Viewer"*)
        print_text_in_color "$ICyan" "Downloading the Daily Backup Viewer script..."
        run_script NOT_SUPPORTED_FOLDER backup-viewer
    ;;&
    *"Daily Backup Wizard"*)
        print_text_in_color "$ICyan" "Downloading the Daily Backup Wizard script..."
        run_script NOT_SUPPORTED_FOLDER daily-backup-wizard
    ;;&
    *"Restic Cloud Backup Wizard"*)
        print_text_in_color "$ICyan" "Downloading the Cloud Backup Wizard script..."
        run_script NOT_SUPPORTED_FOLDER restic-cloud-backup-wizard
    ;;&
    *"Firewall"*)
        print_text_in_color "$ICyan" "Downloading the Firewall script..."
        run_script NOT_SUPPORTED_FOLDER firewall
    ;;&
    *"Monitor Link Shares"*)
        print_text_in_color "$ICyan" "Monitor Link Shares..."
        run_script NOT_SUPPORTED_FOLDER monitor-link-shares
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
    *"System Restore"*)
        print_text_in_color "$ICyan" "Downloading the System Restore script..."
        run_script NOT_SUPPORTED_FOLDER system-restore
    ;;&
    *)
    ;;
esac
exit
