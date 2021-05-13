#!/bin/bash

# T&M Hansson IT AB © - 2021, https://www.hanssonit.se/

true
SCRIPT_NAME="OnlyOffice (Integrated)"
SCRIPT_EXPLAINER="This script will install the integrated OnlyOffice Documentserver Community."
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

# Check if Documentserver_community is already installed
if ! is_app_enabled documentserver_community
then
    # Ask for installing
    install_popup "$SCRIPT_NAME"
else
    # Ask for removal or reinstallation
    reinstall_remove_menu "$SCRIPT_NAME"
    # Removal
    nextcloud_occ app:remove documentserver_community
    # Disable Onlyoffice App if activated
    if is_app_installed onlyoffice
    then
        nextcloud_occ app:remove onlyoffice
    fi
    # Show successful uninstall if applicable
    removal_popup "$SCRIPT_NAME"
fi

# Nextcloud 19 is required.
lowest_compatible_nc 19

# Check if Nextcloud is installed with TLS
check_nextcloud_https "OnlyOffice (Integrated)"

if does_this_docker_exist 'collabora/code'
then
    ram_check 3 OnlyOffice
    cpu_check 3 OnlyOffice
else
    ram_check 2 OnlyOffice
    cpu_check 2 OnlyOffice
fi

# Check if OnlyOffice is installed using the old method
if does_this_docker_exist 'onlyoffice/documentserver'
then
    msg_box "Your server is compatible with the new way of installing OnlyOffice. \
We will now remove the old docker and install the app from Nextcloud instead."
    # Remove docker image
    docker_prune_this 'onlyoffice/documentserver'
    # Disable OnlyOffice (Collabora App) if activated
    if is_app_installed onlyoffice
    then
        nextcloud_occ app:remove onlyoffice
    fi
    # Revoke LE
    SUBDOMAIN=$(input_box_flow "Please enter the subdomain you are using for OnlyOffice\nE.g: office.yourdomain.com")
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

# Install OnlyOffice
msg_box "We will now install OnlyOffice.

Please note that it might take very long time to install the app, and you will not see any progress bar.

Please be patient, don't abort."
install_and_enable_app onlyoffice
sleep 2
if install_and_enable_app documentserver_community
then
    chown -R www-data:www-data "$NC_APPS_PATH"
    nextcloud_occ config:app:set onlyoffice DocumentServerUrl --value="$(nextcloud_occ_no_check config:system:get overwrite.cli.url)index.php/apps/documentserver_community/"
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
