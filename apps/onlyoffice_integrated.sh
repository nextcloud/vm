#!/bin/bash

# T&M Hansson IT AB © - 2020, https://www.hanssonit.se/

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

# Check if OnlyOffice is installed using the old method
if does_this_docker_exist 'onlyoffice/documentserver'
then
    # Greater than 18.0.1 is 18.0.2 which is required
    if version_gt "$CURRENTVERSION" "18.0.1"
    then
        msg_box "Your server is compatible with the new way of installing OnlyOffice. \
We will now remove the old docker and install the app from Nextcloud instead."
        # Remove docker image
        docker_prune_this 'onlyoffice/documentserver'
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
    else
        msg_box "You need to run at least Nextcloud 18.0.1 to be able to run OnlyOffice. \
Please upgrade using the built in script:

'sudo bash $SCRIPTS/update.sh'

You can also buy support directly in our shop: \
https://shop.hanssonit.se/product/upgrade-between-major-owncloud-nextcloud-versions/"
        exit
    fi
# Check if OnlyOffice is installed using the new method
elif version_gt "$CURRENTVERSION" "18.0.1" && ! does_this_docker_exist 'onlyoffice/documentserver'
then
    # Check if webmin is already installed
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
else
    msg_box "You need to run at least Nextcloud 18.0.1 to be able to run OnlyOffice. \
Please upgrade using the built in script:

'sudo bash $SCRIPTS/update.sh'

You can also buy support directly in our shop: \
https://shop.hanssonit.se/product/upgrade-between-major-owncloud-nextcloud-versions/"
    exit
fi

# Check if collabora is installed and remove every trace of it
if does_this_docker_exist 'collabora/code'
then
    msg_box "You can't run both Collabora and OnlyOffice on the same VM. \
We will now remove Collabora from the server."
    # Remove docker image
    docker_prune_this 'collabora/code'
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
    # Disable Collabora App if activated
    if is_app_installed richdocuments
    then
       nextcloud_occ app:remove richdocuments
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
    # Remove Collabora app
    if is_app_installed richdocuments
    then
        nextcloud_occ app:remove richdocuments
    fi
fi

# Check if apache2 evasive-mod is enabled and disable it because of compatibility issues
if [ "$(apache2ctl -M | grep evasive)" != "" ]
then
    msg_box "We noticed that 'mod_evasive' is installed which is the DDOS protection for webservices. \
It has comptibility issues with OnlyOffice and you can now choose to disable it."
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
lowest_compatible_nc 18

# Check if Nextcloud is installed with TLS
check_nextcloud_https "OnlyOffice (Integrated)"

# Install OnlyOffice
msg_box "We will now install OnlyOffice.

Please note that it might take very long time to install the app, and you will not see any progress bar.

Please be paitent, don't abort."
install_and_enable_app onlyoffice
sleep 2
if install_and_enable_app documentserver_community
then
    chown -R www-data:www-data "$NC_APPS_PATH"
    nextcloud_occ config:app:set onlyoffice DocumentServerUrl --value="$(nextcloud_occ_no_check config:system:get overwrite.cli.url)index.php/apps/documentserver_community/"
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
