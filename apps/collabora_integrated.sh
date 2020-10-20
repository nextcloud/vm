#!/bin/bash

# T&M Hansson IT AB © - 2020, https://www.hanssonit.se/

# shellcheck disable=2034,2059
true
SCRIPT_NAME="Collabora (Integrated)"
SCRIPT_EXPLAINER="This script will install the integrated Collabora Office Server"
# shellcheck source=lib.sh
source <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/szaimen-patch-22/lib.sh)

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

# Nextcloud 19 is required.
lowest_compatible_nc 19

# Test RAM size (2GB min) + CPUs (min 2)
ram_check 2 Collabora
cpu_check 2 Collabora

# Check for other Office solutions
if does_this_docker_exist 'onlyoffice/documentserver' || does_this_docker_exist 'collabora/code'
then
    raise_ram_check_4gb "$SCRIPT_NAME"
fi

# Check if Nextcloud is installed with TLS
check_nextcloud_https "$SCRIPT_NAME"

# Disable OnlyOffice App if activated
disable_office_integration onlyoffice "OnlyOffice"

# Install Collabora
msg_box "We will now install $SCRIPT_NAME.

Please note that it might take very long time to install the app, and you will not see any progress bar.

Please be paitent, don't abort."
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

# Just make sure the script exits
exit
