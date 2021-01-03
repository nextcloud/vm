#!/bin/bash

# T&M Hansson IT AB © - 2021, https://www.hanssonit.se/

true
SCRIPT_NAME="Fail2ban Menu"
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

choice=$(whiptail --title "$TITLE" --checklist \
"Automatically install and configure Fail2ban.
$CHECKLIST_GUIDE\n\n$RUN_LATER_GUIDE" "$WT_HEIGHT" "$WT_WIDTH" 4 \
"Install-Fail2ban" "(Install Fail2ban and protect Nextcloud + SSH)" "$STARTUP_SWITCH" \
"Fail2ban-Statuscheck" "(Check status of currently blocked attacks)" OFF \
"Fail2ban-UnbanIP" "(Unban blocked IP addresses)" OFF 3>&1 1>&2 2>&3)

case "$choice" in
    *"Install-Fail2ban"*)
        print_text_in_color "$ICyan" "Downloading the Fail2ban install script..."
        run_script APP fail2ban
    ;;&
    *"Fail2ban-Statuscheck"*)
        SUBTITLE="Fail2ban Statuscheck"
        if is_this_installed fail2ban && [ -f "/etc/fail2ban/filter.d/nextcloud.conf" ]
        then
            msg_box "$(fail2ban-client status nextcloud && fail2ban-client status sshd && iptables -L -n)" "$SUBTITLE"
        else
            msg_box "Fail2ban isn't installed. Please run 'sudo bash /var/scripts/menu.sh' to install it." "$SUBTITLE"
        fi
    ;;&
    *"Fail2ban-UnbanIP"*)
        SUBTITLE="Fail2ban Unban IP"
        if is_this_installed fail2ban && [ -f "/etc/fail2ban/filter.d/nextcloud.conf" ]
        then
            UNBANIP="$(input_box_flow "Enter the IP adress that you want to unban.")" "$SUBTITLE"
            if ! iptables -L -n | grep -qv "$UNBANIP"
            then
                msg_box "It seems that $UNBANIP isn't banned. Please try again."
                run_script MENU fail2ban_menu
            else
                if fail2ban-client set ssh unbanip "$UNBANIP"
                then
                    msg_box "$UNBANIP was sucessfully removed from the block list!"
                else
                    msg_box "It seems like something went wrong, please report this issue to $ISSUES."
                    exit
                fi
            fi
        else
            msg_box "Fail2ban isn't installed. Please run 'sudo bash /var/scripts/menu.sh' to install it." "$SUBTITLE"
        fi
    ;;&
    *)
    ;;
esac
exit
