#!/bin/bash

# T&M Hansson IT AB © - 2024, https://www.hanssonit.se/

true
SCRIPT_NAME="Additional Apps Menu"
# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Must be root
root_check

# Set the startup switch
if [ -f "$SCRIPTS/nextcloud-startup-script.sh" ]
then
    STARTUP_SWITCH="ON"
else
    STARTUP_SWITCH="OFF"
fi

# Show a msg_box during the startup script
if [ -f "$SCRIPTS/nextcloud-startup-script.sh" ]
then
    msg_box "In the next step, you will be offered to easily install apps that are made to enhance your server and experience.
We have pre-selected apps that we recommend for any installation.

PLEASE NOTE: For stability reasons you should *not* select apps just for the sake of it.
It's better to run: sudo bash $SCRIPTS/menu.sh when the first setup is complete, and after you've made a snapshot/backup of the server."
fi

# Install Apps
choice=$(whiptail --title "$TITLE" --checklist \
"Which apps do you want to install?\n\nAutomatically configure and install selected apps
$CHECKLIST_GUIDE\n\n$RUN_LATER_GUIDE" "$WT_HEIGHT" "$WT_WIDTH" 4 \
"Documentserver" "(OnlyOffice or Collabora - Docker or Integrated)" OFF \
"Bitwarden" "(External password manager) [4GB RAM]" OFF \
"Fail2ban  " "(Extra Bruteforce protection)" "$STARTUP_SWITCH" \
"Recognize" "(Use [local] AI on your photos in Nextcloud) [8GB RAM]" OFF \
"Imaginary" "(Generate image previews for Nextcloud) [4GB RAM]" "$STARTUP_SWITCH" \
"Webmin" "(Server GUI like Cpanel)" OFF \
"Talk" "(Video calls and chat for Nextcloud - requires port 3478)" "$STARTUP_SWITCH" \
"SMB-mount" "(Mount SMB-shares from your local network)" OFF \
"Adminer" "(PostgreSQL GUI)" OFF \
"LDAP" "(Windows Active directory for Nextcloud)" OFF \
"Notify Push" "(High Performance Files Backend for Nextcloud)" OFF \
"Netdata" "(Real-time server monitoring in Web GUI)" OFF \
"FullTextSearch" "(Search for text inside documents [6GB RAM])" OFF \
"BPYTOP" "(Real-time server monitoring in CLI)" OFF \
"ClamAV" "(Antivirus for Nextcloud and files)" OFF \
"Midnight Commander" "(CLI file manager)" OFF \
"Pico CMS" "(Lightweight CMS integration in Nextcloud)" OFF \
"Whiteboard" "(Whiteboard for Nextcloud)" OFF \
"Extract" "(Archive extraction for Nextcloud)" OFF 3>&1 1>&2 2>&3)

case "$choice" in
    *"Documentserver"*)
        print_text_in_color "$ICyan" "Downloading the Documentserver Menu..."
        run_script MENU documentserver
    ;;&
    *"Bitwarden"*)
        print_text_in_color "$ICyan" "Downloading the Bitwarden Menu..."
        run_script MENU bitwarden_menu
    ;;&
    *"Fail2ban  "*)
        print_text_in_color "$ICyan" "Downloading the Fail2ban Menu..."
        run_script MENU fail2ban_menu
    ;;&
    *"Adminer"*)
        print_text_in_color "$ICyan" "Downloading the Adminer script..."
        run_script APP adminer
    ;;&
    *"ClamAV"*)
        print_text_in_color "$ICyan" "Downloading the ClamAV script..."
        run_script APP clamav
    ;;&
    *"Extract"*)
        print_text_in_color "$ICyan" "Downloading the Extract script..."
        run_script APP extract
    ;;&
    *"Netdata"*)
        print_text_in_color "$ICyan" "Downloading the Netdata script..."
        run_script APP netdata
    ;;&
    *"BPYTOP"*)
        print_text_in_color "$ICyan" "Downloading the BPYTOP script..."
        run_script APP bpytop
    ;;&
    *"Midnight Commander"*)
        print_text_in_color "$ICyan" "Downloading the Midnight Commander script..."
        run_script APP midnight-commander
    ;;&
    *"FullTextSearch"*)
        print_text_in_color "$ICyan" "Downloading the FullTextSearch script..."
        run_script APP fulltextsearch
    ;;&
    *"Pico CMS"*)
        print_text_in_color "$ICyan" "Downloading the Pico CMS script..."
        run_script APP pico_cms
    ;;&
    *"Imaginary"*)
        print_text_in_color "$ICyan" "Downloading the Imaginary script..."
        run_script APP imaginary
    ;;&
    *"Notify Push"*)
        print_text_in_color "$ICyan" "Downloading the Notify Push script..."
        run_script APP notify_push
    ;;&
    *"LDAP"*)
        SUBTITLE="LDAP"
        print_text_in_color "$ICyan" "Installing LDAP..."
        if install_and_enable_app user_ldap
        then
            msg_box "LDAP installed! Please visit https://subdomain.yourdomain.com/settings/admin/ldap \
to finish the setup once this script is done." "$SUBTITLE"
        else
            msg_box "LDAP installation failed." "$SUBTITLE"
        fi
    ;;&
    *"Talk"*)
        print_text_in_color "$ICyan" "Downloading the Talk script..."
        run_script APP talk
    ;;&
    *"Webmin"*)
        print_text_in_color "$ICyan" "Downloading the Webmin script..."
        run_script APP webmin
    ;;&
    *"Whiteboard"*)
        print_text_in_color "$ICyan" "Downloading the Whiteboard script..."
        run_script APP whiteboard
    ;;&
    *"Recognize"*)
        print_text_in_color "$ICyan" "Downloading the Recognize script..."
        run_script APP recognize
    ;;&
    *"SMB-mount"*)
        print_text_in_color "$ICyan" "Downloading the SMB-mount script..."
        run_script APP smbmount
    ;;&
    *)
    ;;
esac
exit
