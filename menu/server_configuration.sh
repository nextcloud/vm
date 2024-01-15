#!/bin/bash

# T&M Hansson IT AB © - 2024, https://www.hanssonit.se/

true
SCRIPT_NAME="Server Configuration Menu"
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
    msg_box "In the next step, you will be offered to easily install different configurations that are made to enhance your server and experience.
We have pre-selected some choices that we recommend for any installation.

PLEASE NOTE: For stability reasons you should *not* select everything just for the sake of it.
It's better to run: sudo bash $SCRIPTS/menu.sh when the first setup is complete, and after you've made a snapshot/backup of the server."
fi

# Server configurations
choice=$(whiptail --title "$TITLE" --checklist \
"Choose what you want to configure
$CHECKLIST_GUIDE\n\n$RUN_LATER_GUIDE" "$WT_HEIGHT" "$WT_WIDTH" 4 \
"deSEC" "(Automatically set up a dedyn.io domain, together with DDNS and TLS)" "$STARTUP_SWITCH" \
"DDclient Configuration" "(Use ddclient for automatic DDNS updates)" OFF \
"Activate TLS" "(Enable HTTPS with Let's Encrypt on your domain)" "$STARTUP_SWITCH" \
"SMTP Mail" "(Enable being notified by mail from your server)" OFF \
"Static IP" "(Set static IP in Ubuntu with netplan.io)" OFF \
"Automatic updates" "(Automatically update your server every week on Sundays)" OFF \
"GeoBlock" "(Only allow certain countries to access your server)" OFF \
"Disk Monitoring" "(Check for S.M.A.R.T errors on your disks)" OFF \
"Extra Security" "(Add extra security to prevent attacks)" OFF \
"Database Shrinking" "(Shrink the database if it got too big)" OFF \
"Daily Backup Wizard" "([BETA] Create a Daily Backup script)" OFF 3>&1 1>&2 2>&3)

case "$choice" in
    *"Static IP"*)
        print_text_in_color "$ICyan" "Downloading the Static IP script..."
        run_script NETWORK static_ip
    ;;&
    *"Extra Security"*)
        print_text_in_color "$ICyan" "Downloading the Extra Security script..."
        run_script ADDONS security
    ;;&
    *"deSEC"*)
        if [ -f $SCRIPTS/desec_menu.sh ]
        then
            bash $SCRIPTS/desec_menu.sh
        else
            print_text_in_color "$ICyan" "Downloading the deSEC menu script..."
            run_script MENU desec_menu
        fi
    ;;&
    *"DDclient Configuration"*)
        if [[ "$choice" != *"deSEC"* ]]
        then
            print_text_in_color "$ICyan" "Downloading the DDclient Configuration script..."
            run_script NETWORK ddclient-configuration
        fi
    ;;&
    *"Activate TLS"*)
        if [[ "$choice" != *"deSEC"* ]]
        then
            SUBTITLE="Activate TLS"
            msg_box "The following script will install a trusted
TLS certificate through Let's Encrypt.
It's recommended to use TLS (https) together with Nextcloud.
Please open port 80 and 443 to this servers IP before you continue.
More information can be found here:
https://www.techandme.se/open-port-80-443/" "$SUBTITLE"

            if yesno_box_yes "Do you want to install TLS?" "$SUBTITLE"
            then
                if [ -f $SCRIPTS/activate-tls.sh ]
                then
                    bash $SCRIPTS/activate-tls.sh
                else
                    print_text_in_color "$ICyan" "Downloading the Let's Encrypt script..."
                    run_script LETS_ENC activate-tls
                fi
            else
                msg_box "OK, but if you want to run it later, just type: sudo bash $SCRIPTS/menu.sh --> Server Configuration --> Activate TLS" "$SUBTITLE"
            fi
            
            # Just make sure it is gone
            rm -f "$SCRIPTS/test-new-config.sh"
        fi
    ;;&
    *"GeoBlock"*)
        print_text_in_color "$ICyan" "Downloading the Geoblock script..."
        run_script NETWORK geoblock 
    ;;&
    *"Automatic updates"*)
        print_text_in_color "$ICyan" "Downloading the Automatic Updates script..."
        run_script ADDONS automatic_updates
    ;;&
    *"SMTP Mail"*)
        print_text_in_color "$ICyan" "Downloading the SMTP Mail script..."
        run_script ADDONS smtp-mail
    ;;&
    *"Disk Monitoring"*)
        print_text_in_color "$ICyan" "Downloading the Disk Monitoring script..."
        run_script DISK smart-monitoring
    ;;&
    *"Daily Backup Wizard"*)
        print_text_in_color "$ICyan" "Downloading the Daily Backup Wizard script..."
        run_script NOT_SUPPORTED_FOLDER daily-backup-wizard
    ;;&
    *"Database Shrinking"*)
        print_text_in_color "$ICyan" "Downloading the Database Shrinking script..."
        run_script ADDONS database_shrinking
    ;;&
    *)
    ;;
esac
exit
