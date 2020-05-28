#!/bin/bash

# T&M Hansson IT AB © - 2020, https://www.hanssonit.se/

# Use local lib file in case there is no internet connection
if [ -f /var/scripts/lib.sh ]
then
# shellcheck disable=2034,2059
true
# shellcheck source=lib.sh
source /var/scripts/lib.sh
 # If we have internet, then use the latest variables from the lib remote file
elif print_text_in_color "$ICyan" "Testing internet connection..." && ping github.com -c 2
then
# shellcheck disable=2034,2059
true
# shellcheck source=lib.sh
source /var/scripts/main/lib.sh &>/dev/null || . <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh) &>/dev/null
else
    print_text_in_color "$IRed" "You don't seem to have a working internet connection, and /var/scripts/lib.sh is missing so you can't run this script."
    print_text_in_color "$ICyan" "Please report this to https://github.com/nextcloud/vm/issues/"
    exit 1
fi

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Must be root
root_check

# Server configurations
choice=$(whiptail --title "Server configurations" --checklist "Choose what you want to configure\nSelect by pressing the spacebar\nYou can view this menu later by running 'sudo bash $SCRIPTS/menu.sh'" "$WT_HEIGHT" "$WT_WIDTH" 4 \
"Activate TLS" "(Enable HTTPS with Let's Encrypt)" ON \
"Security" "(Add extra security based on this http://goo.gl/gEJHi7)" OFF \
"Static IP" "(Set static IP in Ubuntu with netplan.io)" OFF \
"Automatic updates" "(Automatically update your server every week on Sundays)" OFF 3>&1 1>&2 2>&3)

case "$choice" in
    *"Security"*)
        clear
        run_script STATIC security static
    ;;&
    *"Static IP"*)
        clear
        run_script STATIC static_ip static
    ;;&
    *"Automatic updates"*)
        clear
        run_script STATIC automatic_updates static
    ;;&
    *"Activate TLS"*)
        clear
msg_box "The following script will install a trusted
TLS certificate through Let's Encrypt.
It's recommended to use TLS (https) together with Nextcloud.
Please open port 80 and 443 to this servers IP before you continue.
More information can be found here:
https://www.techandme.se/open-port-80-443/"

        if [[ "yes" == $(ask_yes_or_no "Do you want to install TLS?") ]]
        then
            if [ -f $SCRIPTS/activate-tls.sh ]
            then
                bash $SCRIPTS/activate-tls.sh
            else
                download_script LETS_ENC activate-tls lets-encrypt
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
