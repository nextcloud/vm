#!/bin/bash

# T&M Hansson IT AB © - 2020, https://www.hanssonit.se/

# shellcheck disable=2034,2059
true
# shellcheck source=lib.sh
NC_UPDATE=1 . <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)
unset NC_UPDATE

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Check if root
root_check

# Nextcloud 18 is required.
lowest_compatible_nc 18

# Test RAM size (2GB min) + CPUs (min 2)
ram_check 2 OnlyOffice
cpu_check 2 OnlyOffice

# Get the latest packages
apt update -q4 & spinner_loading

# Check if onlyoffice is already installed
print_text_in_color "$ICyan" "Checking if Onlyoffice is already installed..."
if version_gt "$CURRENTVERSION" "18.0.1" && ! does_this_docker_exist 'onlyoffice/documentserver'
then
    install_if_not jq
    if occ_command_no_check app:list --output=json | jq -e '.enabled | .documentserver_community' > /dev/null
    then
        choice=$(whiptail --radiolist "It seems like 'Onlyoffice' is already installed.\nChoose what you want to do.\nSelect by pressing the spacebar and ENTER" "$WT_HEIGHT" "$WT_WIDTH" 4 \
        "Uninstall Onlyoffice" "" OFF \
        "Reinstall Onlyoffice" "" ON 3>&1 1>&2 2>&3)

        case "$choice" in
            "Uninstall Onlyoffice")
                print_text_in_color "$ICyan" "Uninstalling Onlyoffice..."
                occ_command_no_check app:remove onlyoffice
                occ_command app:remove documentserver_community
		docker_prune_this 'onlyoffice/documentserver'
                msg_box "Onlyoffice was successfully uninstalled."
                exit
            ;;
            "Reinstall Onlyoffice")
                print_text_in_color "$ICyan" "Reinstalling Onlyoffice..."
                occ_command_no_check app:remove onlyoffice
                occ_command app:remove documentserver_community
		docker_prune_this 'onlyoffice/documentserver'
            ;;
            *)
            ;;
        esac
	fi
else
        print_text_in_color "$ICyan" "Installing OnlyOffice..."
fi

# Check if Nextcloud is installed with SSL
if ! occ_command_no_check config:system:get overwrite.cli.url | grep -q "https"
then
msg_box "Sorry, but Nextcloud needs to be run on HTTPS which doesn't seem to be the case here.

You easily activate TLS (HTTPS) by running the Let's Encrypt script found in $SCRIPTS.
More info here: https://bit.ly/37wRCin

To run this script again, just exectue 'sudo bash $SCRIPTS/additional_apps.sh' and choose OnlyOffice."
    exit
fi

# Check if apache2 evasive-mod is enabled and disable it because of compatibility issues
if [ "$(apache2ctl -M | grep evasive)" != "" ]
then
    msg_box "We noticed that 'mod_evasive' is installed which is the DDOS protection for webservices. It has comptibility issues with OnlyOffice and you can now choose to disable it."
    if [[ "no" == $(ask_yes_or_no "Do you want to disable DDOS protection?")  ]]
    then
        print_text_in_color "$ICyan" "Keeping mod_evasive active."
    else
        a2dismod evasive
        # a2dismod mod-evasive # not needed, but existing in the Extra Security script.
        apt purge libapache2-mod-evasive -y
	systemctl restart apache2
    fi
fi

# Check if OnlyOffice or Collabora is previously installed
# If yes, then stop and prune the docker container
docker_prune_this 'onlyoffice/documentserver'
docker_prune_this 'collabora/code'

# Disable RichDocuments (Collabora App) if activated
if [ -d "$NC_APPS_PATH"/richdocuments ]
then
    occ_command app:remove richdocuments
fi

# Disable OnlyOffice if activated
if [ -d "$NC_APPS_PATH"/onlyoffice ]
then
    occ_command app:remove onlyoffice
    if occ_command_no_check app:list --output=json | jq -e '.enabled | .documentserver_community' > /dev/null
    then
        occ_command app:remove documentserver_community
    fi
fi

# Install OnlyOffice
msg_box "We will now install Onlyoffice.

Please note that it might take very long time to install it, and you will not see any progress bar.

Please be paitent, don't abort."
install_and_enable_app onlyoffice
sleep 2
if install_and_enable_app documentserver_community
then
    chown -R www-data:www-data "$NC_APPS_PATH"
    occ_command config:app:set onlyoffice DocumentServerUrl --value=https://"$(occ_command_no_check config:system:get overwrite.cli.url)apps/documentserver_community/"
    msg_box "Onlyoffice was successfully installed."
fi

# Just make sure the script exits
exit
