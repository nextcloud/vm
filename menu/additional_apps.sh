#!/bin/bash

# T&M Hansson IT AB © - 2020, https://www.hanssonit.se/

# shellcheck disable=2034,2059
true
SCRIPT_NAME="Additional Apps Menu"
# shellcheck source=lib.sh
source /var/scripts/lib.sh

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

# Install Apps
choice=$(whiptail --title "$TITLE" --checklist "Which apps do you want to install?\n\nAutomatically configure and install selected apps\n$CHECKLIST_GUIDE\n$MENU_GUIDE" "$WT_HEIGHT" "$WT_WIDTH" 4 \
"Documentserver" "(OnlyOffice or Collabora - Docker or Integrated)" OFF \
"Bitwarden" "(External password manager)" OFF \
"Fail2ban  " "(Extra Bruteforce protection)" "$STARTUP_SWITCH" \
"Adminer" "(PostgreSQL GUI)" OFF \
"Netdata" "(Real-time server monitoring in Web GUI)" OFF \
"BPYTOP" "(Real-time server monitoring in CLI)" OFF \
"FullTextSearch" "(Elasticsearch for Nextcloud [2GB RAM])" OFF \
"PreviewGenerator" "(Pre-generate previews)" "$STARTUP_SWITCH" \
"LDAP" "(Windows Active directory)" OFF \
"Talk" "(Nextcloud Video calls and chat)" OFF \
"Webmin" "(Server GUI)" "$STARTUP_SWITCH" \
"SMB-mount" "(Connect to SMB-shares from your local network)" OFF 3>&1 1>&2 2>&3)

case "$choice" in
    *"Documentserver"*)
        clear
        print_text_in_color "$ICyan" "Downloading the Documentserver script..."
        run_script MENU documentserver
    ;;&
    *"Bitwarden"*)
        clear
        print_text_in_color "$ICyan" "Downloading the Bitwarden script..."
        run_script MENU bitwarden_menu
    ;;&
    *"Fail2ban  "*)
        clear
        print_text_in_color "$ICyan" "Downloading the Fail2ban script..."
        run_script MENU fail2ban_menu
    ;;&
    *"Adminer"*)
        clear
        print_text_in_color "$ICyan" "Downloading the Adminer script..."
        run_script APP adminer
    ;;&
    *"Netdata"*)
        clear
        print_text_in_color "$ICyan" "Downloading the Netdata script..."
        run_script APP netdata
    ;;&
    *"BPYTOP"*)
        clear
        SUBTITLE="BPYTOP"
        msg_box "BPYTOP is an amazing alternative to ressource-monitor software like htop." "$SUBTITLE"
        if yesno_box_yes "Do you want to install BPYTOP?" "$SUBTITLE"
        then
            print_text_in_color "$ICyan" "Installing BPYTOP..."
            install_if_not snapd
            if snap install bpytop
            then
                snap connect bpytop:mount-observe
                snap connect bpytop:network-control
                snap connect bpytop:hardware-observe
                snap connect bpytop:system-observe
                snap connect bpytop:process-control
                snap connect bpytop:physical-memory-observe
                hash -r
                msg_box "BPYTOP is now installed! Check out the amazing stats by runnning 'bpytop' from your CLI.\n\nYou can check out their Gihub repo here: https://github.com/aristocratos/bpytop/blob/master/README.md" "$SUBTITLE"
            else
                msg_box "It seems like the installation of BPYTOP failed. Please try again." "$SUBTITLE"
            fi
        fi
    ;;&
    *"FullTextSearch"*)
        clear
        print_text_in_color "$ICyan" "Downloading the FullTextSearch script..."
        run_script APP fulltextsearch
    ;;&
    *"PreviewGenerator"*)
        clear
        print_text_in_color "$ICyan" "Downloading the PreviewGenerator script..."
        run_script APP previewgenerator
    ;;&
    *"LDAP"*)
        clear
        SUBTITLE="LDAP"
        print_text_in_color "$ICyan" "Installing LDAP..."
        if install_and_enable_app user_ldap
        then
            msg_box "LDAP installed! Please visit https://subdomain.yourdomain.com/settings/admin/ldap to finish the setup once this script is done." "$SUBTITLE"
        else
            msg_box "LDAP installation failed." "$SUBTITLE"
        fi
    ;;&
    *"Talk"*)
        clear
        print_text_in_color "$ICyan" "Downloading the Talk script..."
        run_script MENU talk_menu
    ;;&
    *"Webmin"*)
        clear
        print_text_in_color "$ICyan" "Downloading the Webmin script..."
        run_script APP webmin
    ;;&
    *"SMB-mount"*)
        clear
        print_text_in_color "$ICyan" "Downloading the SMB-mount script..."
        run_script APP smbmount
    ;;&
    *)
    ;;
esac
exit
