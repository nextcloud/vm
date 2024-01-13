#!/bin/bash

# T&M Hansson IT AB © - 2024, https://www.hanssonit.se/

true
SCRIPT_NAME="Collabora (Integrated)"
SCRIPT_EXPLAINER="This script will install the integrated Collabora Office Server"
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
if ! is_app_installed richdocumentscode
then
    # Ask for installing
    install_popup "$SCRIPT_NAME"
else
    # Ask for removal or reinstallation
    reinstall_remove_menu "$SCRIPT_NAME"
    # Removal
    nextcloud_occ app:remove richdocumentscode
    # Disable Collabora App if activated
    if is_app_installed richdocuments
    then
        nextcloud_occ app:remove richdocuments
    fi
    # Show successful uninstall if applicable
    removal_popup "$SCRIPT_NAME"
fi

# Check if Collabora is installed using the old method
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

# Nextcloud 19 is required.
lowest_compatible_nc 19

ram_check 2 Collabora
cpu_check 2 Collabora

# Check if Nextcloud is installed with TLS
check_nextcloud_https "Collabora (Integrated)"

# Install Collabora
msg_box "We will now install Collabora.

Please note that it might take very long time to install the app, and you will not see any progress bar.

Please be patient, don't abort."
install_and_enable_app richdocuments
sleep 2
if install_and_enable_app richdocumentscode
then
    chown -R www-data:www-data "$NC_APPS_PATH"
    msg_box "Collabora was successfully installed."
else
    msg_box "The Collabora app failed to install. Please try again later."
fi

if ! is_app_installed richdocuments
then
    msg_box "The Collabora app failed to install. Please try again later."
fi

nextcloud_occ config:app:set richdocuments public_wopi_url --value="$(nextcloud_occ_no_check config:system:get overwrite.cli.url)"

# Just make sure the script exits
exit
