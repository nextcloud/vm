#!/bin/bash

# T&M Hansson IT AB © - 2020, https://www.hanssonit.se/

true
SCRIPT_NAME="OnlyOffice (Integrated)"
SCRIPT_EXPLAINER="This script will install the integrated OnlyOffice Documentserver Community."
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

# Check if OnlyOffice is already installed
if ! is_app_installed documentserver_community
then
    # Ask for installing
    install_popup "$SCRIPT_NAME"
else
    # Ask for removal or reinstallation
    reinstall_remove_menu "$SCRIPT_NAME"
    # Removal
    nextcloud_occ app:remove documentserver_community
    # Disable Onlyoffice App if activated
    nextcloud_occ_no_check config:app:delete onlyoffice DocumentServerUrl
    if is_app_installed onlyoffice
    then
        nextcloud_occ app:remove onlyoffice
    fi
    # Show successful uninstall if applicable
    removal_popup "$SCRIPT_NAME"
fi

# Nextcloud 18 is required.
lowest_compatible_nc 18

# Check if Nextcloud is installed with TLS
check_nextcloud_https "$SCRIPT_NAME"

# Disable Collabora App if activated
disable_office_integration richdocuments "Collabora Online"

# Check if apache2 evasive-mod is enabled and disable it because of compatibility issues
disable_mod_evasive

# Install OnlyOffice
msg_box "We will now install $SCRIPT_NAME.

Please note that it might take very long time to install the app, and you will not see any progress bar.

Please be paitent, don't abort."
install_and_enable_app onlyoffice
sleep 2
if install_and_enable_app documentserver_community
then
    chown -R www-data:www-data "$NC_APPS_PATH"
    nextcloud_occ config:app:set onlyoffice DocumentServerUrl --value="$(nextcloud_occ_no_check config:system:get overwrite.cli.url)index.php/apps/documentserver_community/"
    # Check the connection
    nextcloud_occ app:update onlyoffice
    nextcloud_occ onlyoffice:documentserver --check
    msg_box "OnlyOffice was successfully installed."
else
    msg_box "The documentserver_community app failed to install. Please try again later.
    
If the error presist, please report the issue to https://github.com/nextcloud/documentserver_community

'sudo -u www-data php ./occ app:install documentserver_community failed!'"
fi

if ! is_app_installed onlyoffice
then
    msg_box "The onlyoffice app failed to install. Please try again later."
fi

# Just make sure the script exits
exit
