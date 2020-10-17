#!/bin/bash

# T&M Hansson IT AB © - 2020, https://www.hanssonit.se/

# shellcheck disable=2034,2059
true
SCRIPT_NAME="Additional Apps Menu"
# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh || source <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)

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
    msg_box "In the next step, you will be offered to easily install apps that are made to enhance your server and experiance.
We have pre-selected apps that we recommend for any installation.

PLEASE NOTE: For stability reasons you should *not* select apps just for the sake of it.
It's better to run: sudo bash $SCRIPTS/menu.sh when the first setup is complete, and after you've made a snapshot/backup of the server."
fi

# Install Apps
choice=$(whiptail --title "$TITLE" --checklist \
"Which apps do you want to install?\n\nAutomatically configure and install selected apps
$CHECKLIST_GUIDE\n\n$RUN_LATER_GUIDE" "$WT_HEIGHT" "$WT_WIDTH" 4 \
"Documentserver" "(OnlyOffice or Collabora - Docker or Integrated)" OFF \
"Bitwarden" "(External password manager)" OFF \
"Fail2ban  " "(Extra Bruteforce protection)" "$STARTUP_SWITCH" \
"Adminer" "(PostgreSQL GUI)" OFF \
"Netdata" "(Real-time server monitoring in Web GUI)" OFF \
"BPYTOP" "(Real-time server monitoring in CLI)" OFF \
"Midnight Commander" "(CLI file manager)" OFF \
"FullTextSearch" "(Elasticsearch for Nextcloud [2GB RAM])" OFF \
"PreviewGenerator" "(Pre-generate previews)" "$STARTUP_SWITCH" \
"LDAP" "(Windows Active directory)" OFF \
"Talk" "(Nextcloud Video calls and chat)" OFF \
"Webmin" "(Server GUI)" "$STARTUP_SWITCH" \
"SMB-mount" "(Connect to SMB-shares from your local network)" OFF 3>&1 1>&2 2>&3)

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
    *"Netdata"*)
        print_text_in_color "$ICyan" "Downloading the Netdata script..."
        run_script APP netdata
    ;;&
    *"BPYTOP"*)
        print_text_in_color "$ICyan" "Downloading the BPYTOP script..."
        run_script APP bpytop
    ;;&
    *"Midnight Commander"*)
        SUBTITLE="Midnight Commander"
        msg_box "Midnight Commander is a file manager that can be used in your CLI." "$SUBTITLE"
        if is_this_installed mc
        then
            if yesno_box_yes "It seems like Midnight Commander is already installed.\nDo you want to uninstall it?" "$SUBTITLE"
            then
                print_text_in_color "$ICyan" "Uninstalling Midnight Commander..."
                apt purge mc -y
                apt autoremove -y
                msg_box "Midnight Commander was successfully uninstalled." "$SUBTITLE"
            fi
        elif yesno_box_yes "Do you want to install Midnight Commander?" "$SUBTITLE"
        then
            print_text_in_color "$ICyan" "Installing Midnight Commander..."
            check_command install_if_not mc
            msg_box "Midnight Commander was successfully installed.\nYou can launch it by running 'mc' in the CLI." "$SUBTITLE"
            if yesno_box_yes "Do you want to install a dark theme for Midnight Commander?" "$SUBTITLE"
            then
                print_text_in_color "$ICyan" "Installing dark Theme for Midnight Commander..."
                USER_HOMES=$(find /home -mindepth 1 -maxdepth 1 -type d)
                mapfile -t USER_HOMES <<< "$USER_HOMES"
                USER_HOMES+=(/root)
                THEME="linux:normal=white,black:marked=yellow,black:input=,green:menu=black:menusel=white:\
menuhot=red,:menuhotsel=black,red:dfocus=white,black:dhotnormal=white,black:\
dhotfocus=white,black:executable=,black:directory=white,black:link=white,black:\
device=white,black:special=white,black:core=,black:stalelink=red,black:editnormal=white,black"
                for user_home in "${USER_HOMES[@]}"
                do
                    if [ -f "$user_home"/.config/mc/ini ]
                    then
                        sed -i "s|^base_color=|base_color=$THEME|" "$user_home"/.config/mc/ini
                    fi
                done
                msg_box "The theme was successfully applied. Now check out Midnight Commander by running 'mc' over CLI!"
            fi
        fi
    ;;&
    *"FullTextSearch"*)
        print_text_in_color "$ICyan" "Downloading the FullTextSearch script..."
        run_script APP fulltextsearch
    ;;&
    *"PreviewGenerator"*)
        print_text_in_color "$ICyan" "Downloading the PreviewGenerator script..."
        run_script APP previewgenerator
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
        print_text_in_color "$ICyan" "Downloading the Talk Menu..."
        run_script MENU talk_menu
    ;;&
    *"Webmin"*)
        print_text_in_color "$ICyan" "Downloading the Webmin script..."
        run_script APP webmin
    ;;&
    *"SMB-mount"*)
        print_text_in_color "$ICyan" "Downloading the SMB-mount script..."
        run_script APP smbmount
    ;;&
    *)
    ;;
esac
exit
