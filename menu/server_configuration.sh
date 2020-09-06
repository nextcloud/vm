#!/bin/bash

# T&M Hansson IT AB © - 2020, https://www.hanssonit.se/

# shellcheck disable=2034,2059
true
SCRIPT_NAME="Server Configuration Menu"
# shellcheck source=lib.sh
. <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Must be root
root_check

# Server configurations
choice=$(whiptail --title "$TITLE" --checklist "Choose what you want to configure\n$CHECKLIST_GUIDE\n$MENU_GUIDE" "$WT_HEIGHT" "$WT_WIDTH" 4 \
"Activate TLS" "(Enable HTTPS with Let's Encrypt)" ON \
"Security" "(Add extra security based on this http://goo.gl/gEJHi7)" OFF \
"Static IP" "(Set static IP in Ubuntu with netplan.io)" OFF \
"DDclient Configuration" "(Use ddclient for automatic DDNS updates)" OFF \
"Automatic updates" "(Automatically update your server every week on Sundays)" OFF \
"Disk Check" "(Check for S.M.A.R.T errors on your disks every week on Mondays)" OFF 3>&1 1>&2 2>&3)

case "$choice" in
    *"Security"*)
        clear
        print_text_in_color "$ICyan" "Downloading the Security script..."
        run_script ADDONS security
    ;;&
    *"Static IP"*)
        clear
        print_text_in_color "$ICyan" "Downloading the Static IP script..."
        run_script NETWORK static_ip
    ;;&
    *"DDclient Configuration"*)
        clear
        print_text_in_color "$ICyan" "Downloading the DDclient Configuration script..."
        run_script NETWORK ddclient-configuration
    ;;&
    *"Automatic updates"*)
        clear
        print_text_in_color "$ICyan" "Downloading the Automatic Updates script..."
        run_script ADDONS automatic_updates
    ;;&
    *"Disk Check"*)
        clear
        print_text_in_color "$ICyan" "Downloading the Disk Check script..."
        run_script DISK smartctl
    ;;&
    *"Activate TLS"*)
        clear
msg_box "The following script will install a trusted
TLS certificate through Let's Encrypt.
It's recommended to use TLS (https) together with Nextcloud.
Please open port 80 and 443 to this servers IP before you continue.
More information can be found here:
https://www.techandme.se/open-port-80-443/"

        if yesno_box "Do you want to install TLS?"
        then
            if [ -f $SCRIPTS/activate-tls.sh ]
            then
                bash $SCRIPTS/activate-tls.sh
            else
                print_text_in_color "$ICyan" "Downloading the Let's Encrypt script..."
                download_script LETS_ENC activate-tls
                bash $SCRIPTS/activate-tls.sh
            fi
        else
            echo
            print_text_in_color "$ICyan" "OK, but if you want to run it later, just type: sudo bash $SCRIPTS/activate-tls.sh"
            any_key "Press any key to continue..."
        fi

        # Just make sure they are gone
        rm -f "$SCRIPTS/test-new-config.sh"
        rm -f "$SCRIPTS/activate-tls.sh"
        clear
    ;;&
    *)
    ;;
esac
exit
