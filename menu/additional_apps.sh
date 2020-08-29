#!/bin/bash

# T&M Hansson IT AB © - 2020, https://www.hanssonit.se/

# shellcheck disable=2034,2059
true
# shellcheck source=lib.sh
. <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Must be root
root_check

# Install Apps
choice=$(whiptail --title "Which apps do you want to install?" --checklist "Automatically configure and install selected apps\nSelect by pressing the spacebar\nYou can view this menu later by running 'sudo bash $SCRIPTS/menu.sh'" "$WT_HEIGHT" "$WT_WIDTH" 4 \
"Documentserver" "(OnlyOffice or Collabora - Docker or Integrated)" OFF \
"Bitwarden" "(External password manager)" OFF \
"Fail2ban " "(Extra Bruteforce protection)" OFF \
"Fail2ban-Statuscheck" "(Check status of banned IPs in iptables and Fail2ban)" OFF \
"Adminer" "(PostgreSQL GUI)" OFF \
"Netdata" "(Real-time server monitoring in Web GUI)" OFF \
"BPYTOP" "(Real-time server monitoring in CLI)" OFF \
"FullTextSearch" "(Elasticsearch for Nextcloud [2GB RAM])" OFF \
"PreviewGenerator" "(Pre-generate previews)" OFF \
"LDAP" "(Windows Active directory)" OFF \
"Talk" "(Nextcloud Video calls and chat)" OFF \
"Webmin" "(Server GUI)" OFF \
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
    *"Fail2ban "*)
        clear
        print_text_in_color "$ICyan" "Downloading the Fail2ban script..."
        run_script APP fail2ban
    ;;&
    *"Fail2ban-Statuscheck"*)
        clear
        if is_this_installed fail2ban
        then
            fail2ban-client status nextcloud && fail2ban-client status sshd
            iptables -L -n
        else
            msg_box "Fail2ban isn't installed. Please run 'sudo bash /var/scripts/menu.sh' to install it."
        fi
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
            msg_box "BPYTOP is now installed! Check out the amazing stats by runnning 'bpytop' from your CLI.\n\nYou can check out their Gihub repo here: https://github.com/aristocratos/bpytop/blob/master/README.md"
        else
            msg_box "It seems like the installation failed. Please try again."
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
        print_text_in_color "$ICyan" "Downloading the Talk script..."
        run_script APP talk_signaling
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
