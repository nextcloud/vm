#!/bin/bash

# T&M Hansson IT AB © - 2020, https://www.hanssonit.se/

true
SCRIPT_NAME="Collabora (Integrated)"
SCRIPT_EXPLAINER="This script will install the integrated Collabora Office Server"
# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh || source <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)

# Get all needed variables from the library
nc_update

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Check if root
root_check

# Check if Collabora is installed using the old method
if does_this_docker_exist 'collabora/code'
then
    msg_box "Your server is compatible with the new way of installing Collabora. \
We will now remove the old docker and install the app from Nextcloud instead."
    # Remove docker image
    docker_prune_this 'collabora/code'
    # Disable RichDocuments (Collabora App) if activated
    if is_app_installed richdocuments
    then
        nextcloud_occ app:remove richdocuments
    fi
    # Disable OnlyOffice (Collabora App) if activated
    if is_app_installed onlyoffice
    then
        nextcloud_occ app:remove onlyoffice
    fi
    # Revoke LE
    SUBDOMAIN=$(input_box_flow "Please enter the subdomain you are using for Collabora, e.g: office.yourdomain.com")
    if [ -f "$CERTFILES/$SUBDOMAIN/cert.pem" ]
    then
        yes no | certbot revoke --cert-path "$CERTFILES/$SUBDOMAIN/cert.pem"
        REMOVE_OLD="$(find "$LETSENCRYPTPATH/" -name "$SUBDOMAIN*")"
        for remove in $REMOVE_OLD
            do rm -rf "$remove"
        done
    fi
    # Remove Apache2 config
    if [ -f "$SITES_AVAILABLE/$SUBDOMAIN.conf" ]
    then
        a2dissite "$SUBDOMAIN".conf
        restart_webserver
        rm -f "$SITES_AVAILABLE/$SUBDOMAIN.conf"
    fi
    # Remove trusted domain
    count=0
    while [ "$count" -lt 10 ]
    do
        if [ "$(nextcloud_occ_no_check config:system:get trusted_domains "$count")" == "$SUBDOMAIN" ]
        then
            nextcloud_occ_no_check config:system:delete trusted_domains "$count"
            break
        else
            count=$((count+1))
        fi
    done
fi

# Check if Collabora is installed using the new method
if is_app_enabled richdocumentscode
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

# Check if Nextcloud is installed with TLS
check_nextcloud_https "Collabora (Integrated)"

# Check if Onlyoffice is installed and remove every trace of it
if does_this_docker_exist 'onlyoffice/documentserver'
then
    msg_box "You can't run both Collabora and OnlyOffice on the same VM. We will now remove Onlyoffice from the server."
    # Remove docker image
    docker_prune_this 'onlyoffice/documentserver'
    # Revoke LE
    SUBDOMAIN=$(input_box_flow "Please enter the subdomain you are using for Onlyoffice, e.g: office.yourdomain.com")
    if [ -f "$CERTFILES/$SUBDOMAIN/cert.pem" ]
    then
        yes no | certbot revoke --cert-path "$CERTFILES/$SUBDOMAIN/cert.pem"
        REMOVE_OLD="$(find "$LETSENCRYPTPATH/" -name "$SUBDOMAIN*")"
        for remove in $REMOVE_OLD
            do rm -rf "$remove"
        done
    fi
    # Remove Apache2 config
    if [ -f "$SITES_AVAILABLE/$SUBDOMAIN.conf" ]
    then
        a2dissite "$SUBDOMAIN".conf
        restart_webserver
        rm -f "$SITES_AVAILABLE/$SUBDOMAIN.conf"
    fi
    # Remove trusted domain
    count=0
    while [ "$count" -lt 10 ]
    do
        if [ "$(nextcloud_occ_no_check config:system:get trusted_domains "$count")" == "$SUBDOMAIN" ]
        then
            nextcloud_occ_no_check config:system:delete trusted_domains "$count"
            break
        else
            count=$((count+1))
        fi
    done
else
    # Remove OnlyOffice app
    if is_app_installed onlyoffice
    then
        nextcloud_occ app:remove onlyoffice
    fi
fi

# remove OnlyOffice-documentserver if activated
if is_app_enabled documentserver_community
then
    any_key "OnlyOffice will get uninstalled. Press any key to continue. Press CTRL+C to abort"
    nextcloud_occ app:remove documentserver_community
fi

# Disable OnlyOffice App if activated
if is_app_installed onlyoffice
then
    nextcloud_occ app:remove onlyoffice
fi

# Nextcloud 19 is required.
lowest_compatible_nc 19

ram_check 2 Collabora
cpu_check 2 Collabora

# Install Collabora
msg_box "We will now install Collabora.

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
