#!/bin/bash

# T&M Hansson IT AB © - 2020, https://www.hanssonit.se/

# shellcheck disable=2034,2059
true
# shellcheck source=lib.sh
source /var/scripts/main/lib.sh &>/dev/null || . <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh) &>/dev/null

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Must be root
root_check

# Install Apps
choice=$(whiptail --title "Which apps do you want to install?" --checklist "Automatically configure and install selected apps\nSelect by pressing the spacebar\nYou can view this menu later by running 'sudo bash $SCRIPTS/menu.sh'" "$WT_HEIGHT" "$WT_WIDTH" 4 \
"Fail2ban" "(Extra Bruteforce protection)" OFF \
"Adminer" "(PostgreSQL GUI)" OFF \
"Netdata" "(Real-time server monitoring)" OFF \
"Collabora" "(Online editing [2GB RAM])" OFF \
"OnlyOffice" "(Online editing [2GB RAM])" OFF \
"Bitwarden" "(External password manager)" OFF \
"FullTextSearch" "(Elasticsearch for Nextcloud [2GB RAM])" OFF \
"PreviewGenerator" "(Pre-generate previews)" OFF \
"LDAP" "(Windows Active directory)" OFF \
"Talk" "(Nextcloud Video calls and chat)" OFF \
"SMB-mount" "(Connect to SMB-shares from your local network)" OFF 3>&1 1>&2 2>&3)

case "$choice" in
    *"Fail2ban"*)
        clear
        print_text_in_color "$ICyan" "Downloading Fail2ban.sh..."
        run_script APP fail2ban apps
    ;;&
    *"Adminer"*)
        clear
        print_text_in_color "$ICyan" "Downloading Adminer.sh..."
        run_script APP adminer apps
    ;;&
    *"Netdata"*)
        clear
        print_text_in_color "$ICyan" "Downloading Netdata.sh..."
        run_script APP netdata apps
    ;;&
    *"OnlyOffice"*)
        clear
        print_text_in_color "$ICyan" "Downloading OnlyOffice.sh..."
        run_script APP onlyoffice apps
    ;;&
    *"Collabora"*)
        clear
        print_text_in_color "$ICyan" "Downloading Collabora.sh..."
        run_script APP collabora apps
    ;;&
    *"Bitwarden"*)
        clear
        print_text_in_color "$ICyan" "Downloading Bitwarden.sh..."
        run_script APP tmbitwarden apps
    ;;&
    *"FullTextSearch"*)
        clear
        print_text_in_color "$ICyan" "Downloading FullTextSearch.sh..."
        run_script APP fulltextsearch apps
    ;;&
    *"PreviewGenerator"*)
        clear
        print_text_in_color "$ICyan" "Downloading PreviewGenerator.sh..."
        run_script APP previewgenerator apps
    ;;&
    *"LDAP"*)
        clear
        print_text_in_color "$ICyan" "Installing LDAP..."
        if install_and_enable_app user_ldap
        then
            msg_box "LDAP installed! Please visit https://subdomain.yourdomain.com/settings/admin/ldap to finish the setup once this script is done."
        else
            msg_box "LDAP installation failed."
        fi
    ;;&
    *"Talk"*)
        clear
        print_text_in_color "$ICyan" "Downloading Talk.sh..."
        run_script APP talk apps
    ;;&
    *"SMB-mount"*)
        clear
        print_text_in_color "$ICyan" "Downloading SMB-mount.sh..."
        run_script APP smbmount apps
    ;;&
    *)
    ;;
esac
clear
exit
