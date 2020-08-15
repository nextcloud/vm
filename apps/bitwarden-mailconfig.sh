#!/bin/bash

# T&M Hansson IT AB © - 2020, https://www.hanssonit.se/

# shellcheck disable=2034,2059
true
# shellcheck source=lib.sh
. <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Must be root
root_check

# Check if Bitwarden is already installed
print_text_in_color "$ICyan" "Checking if Bitwarden is already installed..."
if is_docker_running
then
    if docker ps -a --format '{{.Names}}' | grep -Eq "bitwarden";
    then
        if [ ! -d /root/bwdata ] [ ! -d "$BITWARDEN_HOME"/bwdata ]
        then
            msg_box "It seems like 'Bitwarden' isn't installed.\n\nYou cannot run this script."
            exit 1
        fi
    else
        msg_box "It seems like 'Bitwarden' isn't installed.\n\nYou cannot run this script."
        exit 1
    fi
else
    msg_box "It seems like 'Bitwarden' isn't installed.\n\nYou cannot run this script."
    exit 1
fi

msg_box "This script lets you configure your mailserver settings for Bitwarden."
if [[ "no" == $(ask_yes_or_no "Do you want to continue?") ]]
then
    exit
fi

# Enter Mailserver
while true
do
    MAIL_SERVER=$(whiptail --inputbox "Please enter the Mailserver, that you want to use.\nE.g. smtp.mail.de\nIf you don't want to change the Mailserver, that is already configured inside the global.override.env-file, just leave the box empty." "$WT_HEIGHT" "$WT_WIDTH" 3>&1 1>&2 2>&3)
    if [[ "no" == $(ask_yes_or_no "Are your sure about your answer?") ]]
    then
        msg_box "It seems like your weren't satisfied by the Mailserver you entered. Please try again."
    else
        break
    fi
done

# Enter if you want to use ssl
while true
do
    USE_SSL=$(whiptail --inputbox "Do you want to use SSL for your Mailserver? If yes: please type in 'yes'.\nPlease note: if your Mailserver only supports Starttls, you cannot use SSL - so please answer in this case here 'no'.\nIf you don't want to change the SSL-setting, that is already configured inside the global.override.env-file, just leave the box empty." "$WT_HEIGHT" "$WT_WIDTH" 3>&1 1>&2 2>&3)
    if [[ "no" == $(ask_yes_or_no "Are your sure about your answer?") ]]
    then
        msg_box "It seems like your weren't satisfied by the answer you entered. Please try again."
    else
        if [ "$USE_SSL" = "yes" ]
        then
            DEFAULT_PORT=465
            break
        elif [ "$USE_SSL" = "no" ]
        then
            DEFAULT_PORT=25
            break
        elif [ "$USE_SSL" = "" ]
        then
            DEFAULT_PORT=
            break
        fi
    fi
done

# Enter Port or just use standard port (defined by usage of ssl)
while true
do
    SMTP_PORT=$(whiptail --inputbox "Please enter the Port for your Mailserver. The Standard-Port is currently $DEFAULT_PORT?\nIf you don't want to change the Port, that is already configured inside the global.override.env-file, just leave the box empty." "$WT_HEIGHT" "$WT_WIDTH" 3>&1 1>&2 2>&3)
    if [[ "no" == $(ask_yes_or_no "Are your sure about your answer?") ]]
    then
        msg_box "It seems like your weren't satisfied by the Port you entered. Please try again."
    else
        break
    fi
done

# Enter your mail username
while true
do
    MAIL_USERNAME=$(whiptail --inputbox "Please enter mail-username. E.g. mail@example.com\nPlease note: the domain used for your mail-username and the mailserver-domain heave to match!\nIf you don't want to change the mail-username, that is already configured inside the global.override.env-file, just leave the box empty." "$WT_HEIGHT" "$WT_WIDTH" 3>&1 1>&2 2>&3)
    if [[ "no" == $(ask_yes_or_no "Are your sure about your answer?") ]]
    then
        msg_box "It seems like your weren't satisfied by the mail-username you entered. Please try again."
    else
        break
    fi
done

# Enter your mailuser password
while true
do
    MAIL_PASSWORD=$(whiptail --inputbox "Please enter the password for your mail-username.\nIf you don't want to change the password, that is already configured inside the global.override.env-file, just leave the box empty." "$WT_HEIGHT" "$WT_WIDTH" 3>&1 1>&2 2>&3)
    if [[ "no" == $(ask_yes_or_no "Are your sure about your answer?") ]]
    then
        msg_box "It seems like your weren't satisfied by the password you entered. Please try again."
    else
        break
    fi
done

# Enter admin mailadresses
while true
do
    ADMIN_ACCOUNTS=$(whiptail --inputbox "Please enter mailaccounts, that should have access to the Bitwarden admin-panel, reachable under https://your-bitwarden-domain/admin/.\nThey don't have to be registered bitwarden-accounts.\nTo make this setting work, your bitwarden mailserver-settings have to be correct.\nYou can enter just one e-mailaddress or enter more than one like so:\n'bitwarden@example.com,bitwarden2@example1.com,bitwarden3@example2.com'\nIf you want to keep the admin-accounts, that are already configured inside the global.override.env-file, just leave the box empty." "$WT_HEIGHT" "$WT_WIDTH" 3>&1 1>&2 2>&3)
    if [[ "no" == $(ask_yes_or_no "Are your sure about your answer?") ]]
    then
        msg_box "It seems like your weren't satisfied by the mailaccounts you entered. Please try again."
    else
        break
    fi
done

# Present what we gathered, if everything okay, write to files

# Stop bitwarden
systemctl stop bitwarden

# Write to files 


# Start bitwarden
systemctl start bitwarden
