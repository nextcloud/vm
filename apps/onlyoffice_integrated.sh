#!/bin/bash

# T&M Hansson IT AB © - 2020, https://www.hanssonit.se/

# shellcheck disable=2034,2059
true
SCRIPT_NAME="OnlyOffice (Integrated)"
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

print_text_in_color "$ICyan" "Running the OnlyOffice install script..."

# Nextcloud 18 is required.
lowest_compatible_nc 18

# Check if Nextcloud is installed with TLS
check_nextcloud_https "OnlyOffice (Integrated)"

# Check if OnlyOffice is installed using the old method
if does_this_docker_exist 'onlyoffice/documentserver'
then
    # Greater than 18.0.1 is 18.0.2 which is required
    if version_gt "$CURRENTVERSION" "18.0.1"
    then
        msg_box "Your server is compatible with the new way of installing OnlyOffice. We will now remove the old docker and install the app from Nextcloud instead."
        # Remove docker image
        docker_prune_this 'onlyoffice/documentserver'
        # Disable RichDocuments (Collabora App) if activated
        if is_app_installed richdocuments
        then
            occ_command app:remove richdocuments
        fi
        # Disable OnlyOffice (Collabora App) if activated
        if is_app_installed onlyoffice
        then
            occ_command app:remove onlyoffice
        fi
        # Revoke LE
        SUBDOMAIN=$(input_box "Please enter the subdomain you are using for OnlyOffice, e.g: office.yourdomain.com")
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
            if [ "$(occ_command_no_check config:system:get trusted_domains "$count")" == "$SUBDOMAIN" ]
            then
                occ_command_no_check config:system:delete trusted_domains "$count"
                break
            else
                count=$((count+1))
            fi
        done
    else
msg_box "You need to run at least Nextcloud 18.0.1 to be able to run OnlyOffice. Please upgrade using the built in script:

'sudo bash $SCRIPTS/update.sh'

You can also buy support directly in our shop: https://shop.hanssonit.se/product/upgrade-between-major-owncloud-nextcloud-versions/"
        exit
    fi
# Check if OnlyOffice is installed using the new method
elif version_gt "$CURRENTVERSION" "18.0.1" && ! does_this_docker_exist 'onlyoffice/documentserver'
then
    if is_app_enabled documentserver_community
    then
        choice=$(whiptail --title "$TITLE" --menu "It seems like 'OnlyOffice' is already installed.\nChoose what you want to do." "$WT_HEIGHT" "$WT_WIDTH" 4 \
        "Reinstall OnlyOffice" "" \
        "Uninstall OnlyOffice" "" 3>&1 1>&2 2>&3)

        case "$choice" in
            "Uninstall OnlyOffice")
	        print_text_in_color "$ICyan" "Uninstalling OnlyOffice..."
		occ_command app:remove documentserver_community
                # Disable Onlyoffice App if activated
                if is_app_installed onlyoffice
                then
                    occ_command app:remove onlyoffice
                fi
		msg_box "OnlyOffice was successfully uninstalled."
		exit
            ;;
            "Reinstall OnlyOffice")
                print_text_in_color "$ICyan" "Reinstalling OnlyOffice..."
                occ_command app:remove documentserver_community
            ;;
            *)
            ;;
        esac
	fi
else
msg_box "You need to run at least Nextcloud 18.0.1 to be able to run OnlyOffice. Please upgrade using the built in script:

'sudo bash $SCRIPTS/update.sh'

You can also buy support directly in our shop: https://shop.hanssonit.se/product/upgrade-between-major-owncloud-nextcloud-versions/"
    exit
fi

# Check if collabora is installed and remove every trace of it
if does_this_docker_exist 'collabora/code'
then
    msg_box "You can't run both Collabora and OnlyOffice on the same VM. We will now remove Collabora from the server."
    # Remove docker image
    docker_prune_this 'collabora/code'
    # Revoke LE
    SUBDOMAIN=$(input_box "Please enter the subdomain you are using for Collabora, e.g: office.yourdomain.com")
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
       occ_command app:remove richdocuments
    fi
    # Remove trusted domain
    count=0
    while [ "$count" -lt 10 ]
    do
        if [ "$(occ_command_no_check config:system:get trusted_domains "$count")" == "$SUBDOMAIN" ]
        then
            occ_command_no_check config:system:delete trusted_domains "$count"
            break
        else
            count=$((count+1))
        fi
    done
else
    # Remove Collabora app
    if is_app_installed richdocuments
    then
        occ_command app:remove richdocuments
    fi
fi

# Check if apache2 evasive-mod is enabled and disable it because of compatibility issues
if [ "$(apache2ctl -M | grep evasive)" != "" ]
then
    msg_box "We noticed that 'mod_evasive' is installed which is the DDOS protection for webservices. It has comptibility issues with OnlyOffice and you can now choose to disable it."
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

Please be paitent, don't abort."
install_and_enable_app onlyoffice
sleep 2
if install_and_enable_app documentserver_community
then
    chown -R www-data:www-data "$NC_APPS_PATH"
    occ_command config:app:set onlyoffice DocumentServerUrl --value="$(occ_command_no_check config:system:get overwrite.cli.url)/index.php/apps/documentserver_community/"
    msg_box "OnlyOffice was successfully installed."
else
    msg_box "The documentserver_community app failed to install. Please try again later.\n\nIf the error presist, please report the issue to https://github.com/nextcloud/documentserver_community\n\n'sudo -u www-data php ./occ app:install documentserver_community failed!'"
fi

if ! is_app_installed onlyoffice
then
    msg_box "The onlyoffice app failed to install. Please try again later."
fi

# Just make sure the script exits
exit
