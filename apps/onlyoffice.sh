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

# Check if Nextcloud is installed with SSL
if ! occ_command_no_check config:system:get overwrite.cli.url | grep -q "https"
then
msg_box "Sorry, but Nextcloud needs to be run on HTTPS which doesn't seem to be the case here.

You easily activate TLS (HTTPS) by running the Let's Encrypt script found in $SCRIPTS.
More info here: https://bit.ly/37wRCin

To run this script again, just exectue 'sudo bash $SCRIPTS/apps.sh' and choose OnlyOffice."
    exit
fi

# Get the latest packages
apt update -q4 & spinner_loading

# Check if OnlyOffice is installed using the old method
if does_this_docker_exist 'onlyoffice/documentserver'
then
    # Greater than 18.0.0 is 18.0.1 which is required
    if version_gt "$CURRENTVERSION" "18.0.0"
    then
        print_text_in_color "$ICyan" "Your server is compatible with the new way of installing OnlyOffice. We will now remove the old docker and install the app from Nextcloud instead."
        # Remove docker image
        docker_prune_this 'onlyoffice/documentserver'
        # Revoke LE
        SUBDOMAIN=$(whiptail --title "T&M Hansson IT - OnlyOffice" --inputbox "Please enter the subdomain you are using for OnlyOffice, eg: office.yourdomain.com" "$WT_HEIGHT" "$WT_WIDTH" 3>&1 1>&2 2>&3)
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
        # Remove app
        occ_command_no_check app:remove onlyoffice
    fi
# Check if OnlyOffice is installed using the new method
elif version_gt "$CURRENTVERSION" "18.0.0" && ! does_this_docker_exist 'onlyoffice/documentserver'
then
    install_if_not jq
    if occ_command_no_check app:list --output=json | jq -e '.enabled | .documentserver_community' > /dev/null
    then
        choice=$(whiptail --radiolist "It seems like 'OnlyOffice' is already installed.\nChoose what you want to do.\nSelect by pressing the spacebar and ENTER" "$WT_HEIGHT" "$WT_WIDTH" 4 \
        "Uninstall OnlyOffice" "" OFF \
        "Reinstall OnlyOffice" "" ON 3>&1 1>&2 2>&3)

        case "$choice" in
            "Uninstall OnlyOffice")
                print_text_in_color "$ICyan" "Uninstalling OnlyOffice..."
                occ_command app:remove documentserver_community
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

# Check if collabora is installed and remove every trace of it
if does_this_docker_exist 'collabora/code'
then
    msg_box "You can't run both Collabora and OnlyOffice on the same VM. We will now remove Collabora from the server."
    # Remove docker image
    docker_prune_this 'collabora/code'
    # Revoke LE
    SUBDOMAIN=$(whiptail --title "T&M Hansson IT - OnlyOffice" --inputbox "Please enter the subdomain you are using for Collabora, eg: office.yourdomain.com" "$WT_HEIGHT" "$WT_WIDTH" 3>&1 1>&2 2>&3)
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
    # Remove app
    occ_command_no_check app:remove richdocuments
fi

# Install OnlyOffice
msg_box "We will now install OnlyOffice.

Please note that it might take very long time to install it, and you will not see any progress bar.

Please be paitent, don't abort."
install_and_enable_app onlyoffice
sleep 2
if install_and_enable_app documentserver_community
then
    chown -R www-data:www-data "$NC_APPS_PATH"
    occ_command config:app:set onlyoffice DocumentServerUrl --value="$(occ_command_no_check config:system:get overwrite.cli.url)apps/documentserver_community/"
    msg_box "OnlyOffice was successfully installed."
fi

# Just make sure the script exits
exit
