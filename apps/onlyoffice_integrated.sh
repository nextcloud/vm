#!/bin/bash

# T&M Hansson IT AB © - 2024, https://www.hanssonit.se/

true
SCRIPT_NAME="OnlyOffice (Integrated)"
SCRIPT_EXPLAINER="This script will install the integrated OnlyOffice Documentserver Community."
# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh

# Get all needed variables from the library
nc_update

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Check if root
root_check

# Check if Collabora is installed using the new method
if ! is_app_installed documentserver_community
then
    # Ask for installing
    install_popup "$SCRIPT_NAME"
else
    # Ask for removal or reinstallation
    reinstall_remove_menu "$SCRIPT_NAME"
    # Removal
    nextcloud_occ app:remove documentserver_community
    # Disable onlyoffice App if activated
    if is_app_installed onlyoffice
    then
        nextcloud_occ app:remove onlyoffice
    fi
    # Show successful uninstall if applicable
    removal_popup "$SCRIPT_NAME"
fi

# Check if collabora is installed and remove every trace of it
if does_this_docker_exist 'collabora/code'
then
    # Removal
    remove_collabora_docker
fi

# Check if Onlyoffice is installed and remove every trace of it
if does_this_docker_exist 'onlyoffice/documentserver'
then
    # Removal
    remove_onlyoffice_docker
fi

# Remove all office apps
remove_all_office_apps

# Check if apache2 evasive-mod is enabled and disable it because of compatibility issues
if [ "$(apache2ctl -M | grep evasive)" != "" ]
then
    msg_box "We noticed that 'mod_evasive' is installed which is the DDOS protection for webservices. \
It has compatibility issues with OnlyOffice and you can now choose to disable it."
    if ! yesno_box_yes "Do you want to disable DDOS protection?"
    then
        print_text_in_color "$ICyan" "Keeping mod_evasive active."
    else
        a2dismod evasive
        # a2dismod mod-evasive # not needed, but existing in the Extra Security script.
        apt-get purge libapache2-mod-evasive -y
	systemctl restart apache2.service
    fi
fi

# Nextcloud 18 is required.
lowest_compatible_nc 19

# Check if Nextcloud is installed with TLS
check_nextcloud_https "OnlyOffice (Integrated)"

# Install OnlyOffice
msg_box "We will now install OnlyOffice.

Please note that it might take very long time to install the app, and you will not see any progress bar.

Please be patient, don't abort."
install_and_enable_app onlyoffice
sleep 2
if install_and_enable_app documentserver_community
then
    chown -R www-data:www-data "$NC_APPS_PATH"
    nextcloud_occ config:app:set onlyoffice DocumentServerUrl --value="$(nextcloud_occ_no_check config:system:get overwrite.cli.url)/index.php/apps/documentserver_community/"
    msg_box "OnlyOffice was successfully installed."
else
    msg_box "The documentserver_community app failed to install. Please try again later.

If the error persists, please report the issue to https://github.com/nextcloud/documentserver_community

'sudo -u www-data php ./occ app:install documentserver_community failed!'"
fi

if ! is_app_installed onlyoffice
then
    msg_box "The onlyoffice app failed to install. Please try again later."
fi

# Just make sure the script exits
exit
