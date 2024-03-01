#!/bin/bash

# T&M Hansson IT AB © - 2024, https://www.hanssonit.se/
# Copyright © 2021 Simon Lindner (https://github.com/szaimen)

true
SCRIPT_NAME="SMTP Relay with msmtp"
SCRIPT_EXPLAINER="This script will setup an SMTP Relay (Mail Server) in your Nextcloud Server \
that will be used to send emails about failed cronjob's and such."
# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Must be root
root_check

# Check if Smtp Relay was already configured
if ! [ -f /etc/msmtprc ]
then
    # Ask for installing
    install_popup "$SCRIPT_NAME"
else
    # Ask for removal or reinstallation
    reinstall_remove_menu "$SCRIPT_NAME"
    # Removal
    apt-get purge msmtp -y
    apt-get purge msmtp-mta -y
    apt-get purge mailutils -y
    apt-get autoremove -y
    rm -f /etc/mail.rc
    rm -f /etc/msmtprc
    rm -f /var/log/msmtp
    echo "" > /etc/aliases
    # Show successful uninstall if applicable
    removal_popup "$SCRIPT_NAME"
fi

# Install needed tools
install_if_not msmtp
install_if_not msmtp-mta
install_if_not mailutils

# Default providers
choice=$(whiptail --title "$TITLE" --nocancel --menu \
"Please choose the mail provider that you want to use.
$MENU_GUIDE\n\n$RUN_LATER_GUIDE" "$WT_HEIGHT" "$WT_WIDTH" 4 \
"mail.de" "(German mail provider)" \
"SMTP2GO" "(https://www.smtp2go.com)" \
"Manual" "(Complete manual setup)" 3>&1 1>&2 2>&3)

case "$choice" in
    "mail.de")
        NEEDS_CREDENTIALS=1
        MAIL_SERVER="smtp.mail.de"
        PROTOCOL="SSL"
        SMTP_PORT="465"
    ;;
    "SMTP2GO")
        NEEDS_CREDENTIALS=1
        SMTP2GO=1
        MAIL_SERVER="mail-eu.smtp2go.com"
        PROTOCOL="SSL"
        SMTP_PORT="465"	
    ;;
    # Manual setup will be handled a few lines below
    "")
        msg_box "You haven't selected any option. Exiting!"
        exit 1
    ;;
    *)
    ;;
esac

print_text_in_color "$ICyan" "$choice was chosen..."
sleep 1

# Set everything up manually
if [ "$choice" = "Manual" ]
then
    # Enter Mail Server
    MAIL_SERVER=$(input_box_flow "Please enter the SMTP Relay URL that you want to use.\nE.g. smtp.mail.com")

    # Enter if you want to use ssl
    PROTOCOL=$(whiptail --title "$TITLE" --nocancel --menu \
"Please choose the encryption protocol for your SMTP Relay.
$MENU_GUIDE\n\n$RUN_LATER_GUIDE" "$WT_HEIGHT" "$WT_WIDTH" 4 \
"SSL" "" \
"STARTTLS" "" \
"NO-ENCRYPTION" "" 3>&1 1>&2 2>&3)

    if [ -z "$PROTOCOL" ]
    then
        exit 1
    fi

    case "$PROTOCOL" in
        "SSL")
            DEFAULT_PORT=465
        ;;
        "STARTTLS")
            DEFAULT_PORT=587
        ;;
        "NO-ENCRYPTION")
            DEFAULT_PORT=25
        ;;
        *)
        ;;
    esac

    # Enter custom port or just use the default port
    SMTP_PORT=$(whiptail --title "$TITLE" --nocancel --menu \
"Based on your selection of encryption the default port is $DEFAULT_PORT. Would you like to use that port or something else?
$MENU_GUIDE\n\n$RUN_LATER_GUIDE" "$WT_HEIGHT" "$WT_WIDTH" 4 \
"Use default port" "($DEFAULT_PORT)" \
"Enter another port" ""  3>&1 1>&2 2>&3)

    if [ -z "$SMTP_PORT" ]
    then
        exit 1
    fi

    case "$SMTP_PORT" in
        "Use default port")
            SMTP_PORT="$DEFAULT_PORT"
        ;;
        "Enter another port")
            SMTP_PORT="$(input_box_flow 'Please enter the port for your SMTP Relay.')"
        ;;
        *)
        ;;
    esac
fi

# Enter your SMTP username
if [ -n "$NEEDS_CREDENTIALS" ] || yesno_box_yes "Does $MAIL_SERVER require any credentials, like username and password?"
then
    MAIL_USERNAME=$(input_box_flow "Please enter the SMTP username to your email provider.\nE.g. you@mail.com, or just the actual 'username'.")

    # Enter your mail user password
    MAIL_PASSWORD=$(input_box_flow "Please enter the SMTP password to your email provider.")
fi

# Enter the recipient
RECIPIENT=$(input_box_flow "Please enter the recipient email address that shall receive all mails.\nE.g. recipient@mail.com")

# Check if the server use self-signed certificates
if yesno_box_no "Does the SMTP-server use self-signed certificates?"
then
    SELF_SIGNED_CERT=yes
    nextcloud_occ config:system:set mail_smtpstreamoptions ssl allow_self_signed --value=true --type=boolean
    nextcloud_occ config:system:set mail_smtpstreamoptions ssl verify_peer --value=false --type=boolean
    nextcloud_occ config:system:set mail_smtpstreamoptions ssl verify_peer_name --value=false --type=boolean
else
    SELF_SIGNED_CERT=no
fi

# Present what we gathered, if everything okay, write to files
msg_box "These are the settings that will be used. Please check that everything seems correct.

SMTP Relay URL=$MAIL_SERVER
Encryption=$PROTOCOL
SMTP Port=$SMTP_PORT
SMTP Username=$MAIL_USERNAME
SMTP Password=$MAIL_PASSWORD
Recipient=$RECIPIENT
Self-signed TLS/SSL certificate=$SELF_SIGNED_CERT"

# Ask if everything is okay
if ! yesno_box_yes "Does everything look correct?"
then
    msg_box "OK, please start over by running this script again."
    exit
fi

# Add the encryption settings to the file as well
if [ "$PROTOCOL" = "SSL" ]
then
    MSMTP_ENCRYPTION1="tls             on"
    MSMTP_ENCRYPTION2="tls_starttls    off"
elif [ "$PROTOCOL" = "STARTTLS" ]
then
    MSMTP_ENCRYPTION1="tls             on"
    MSMTP_ENCRYPTION2="tls_starttls    on"
elif [ "$PROTOCOL" = "NO-ENCRYPTION" ]
then
    MSMTP_ENCRYPTION1="tls             off"
    MSMTP_ENCRYPTION2="tls_starttls    off"
fi

# Check if auth should be set or not
if [ -z "$MAIL_USERNAME" ]
then
    MAIL_USERNAME="no-reply@nextcloudvm.com"

# Without AUTH (Username and Password)
cat << MSMTP_CONF > /etc/msmtprc
# Set default values for all following accounts.
defaults
auth            off
aliases         /etc/aliases
$MSMTP_ENCRYPTION1
$MSMTP_ENCRYPTION2

tls_trust_file  /etc/ssl/certs/ca-certificates.crt
# logfile         /var/log/msmtp

# Account to send emails
account         $MAIL_USERNAME
host            $MAIL_SERVER
port            $SMTP_PORT
from            $MAIL_USERNAME

account default : $MAIL_USERNAME

### DO NOT REMOVE THIS LINE (it's used in one of the functions in on the Nextcloud Server)
# recipient=$RECIPIENT
MSMTP_CONF
elif [ -n "$SMTP2GO" ]
then
# With AUTH (Username and Password)
cat << MSMTP_CONF > /etc/msmtprc
# Set default values for all following accounts.
defaults
auth            on
aliases         /etc/aliases
$MSMTP_ENCRYPTION1
$MSMTP_ENCRYPTION2

tls_trust_file  /etc/ssl/certs/ca-certificates.crt
logfile         /var/log/msmtp

# Account to send emails
account         $MAIL_USERNAME
host            $MAIL_SERVER
port            $SMTP_PORT
from            no-reply@nextcloudvm.com
user            $MAIL_USERNAME
password        $MAIL_PASSWORD

account default : $MAIL_USERNAME

### DO NOT REMOVE THIS LINE (it's used in one of the functions in on the Nextcloud Server)
# recipient=$RECIPIENT

MSMTP_CONF
else
# With AUTH (Username and Password)
cat << MSMTP_CONF > /etc/msmtprc
# Set default values for all following accounts.
defaults
auth            on
aliases         /etc/aliases
$MSMTP_ENCRYPTION1
$MSMTP_ENCRYPTION2

tls_trust_file  /etc/ssl/certs/ca-certificates.crt
logfile         /var/log/msmtp

# Account to send emails
account         $MAIL_USERNAME
host            $MAIL_SERVER
port            $SMTP_PORT
from            $MAIL_USERNAME
user            $MAIL_USERNAME
password        $MAIL_PASSWORD

account default : $MAIL_USERNAME

### DO NOT REMOVE THIS LINE (it's used in one of the functions in on the Nextcloud Server)
# recipient=$RECIPIENT

MSMTP_CONF
fi

# Secure the file
chmod 600 /etc/msmtprc

# Create logs
rm -f /var/log/msmtp
touch /var/log/msmtp
chmod 666 /var/log/msmtp

# Create aliases
cat << ALIASES_CONF > /etc/aliases
root: $RECIPIENT
default: $RECIPIENT
cron: $RECIPIENT
ALIASES_CONF

# Store message in a variable
TEST_MAIL="Congratulations!

Given this email reached you, it seems like everything is working properly. :)

To change the settings please check /etc/msmtprc on your server, or simply just run the setup script again.

YOUR CURRENT SETTINGS:
-------------------------------------------
$(grep -v password /etc/msmtprc)
-------------------------------------------

Best regards
The NcVM team
https://nextcloudvm.com"

# Define the mail-program
echo 'set sendmail="/usr/bin/msmtp -t"' > /etc/mail.rc

# Test mail
if ! echo -e "$TEST_MAIL" | mail -s "Test email from your NcVM" "$RECIPIENT" >> /var/log/msmtp 2>&1
then
    # Set from email address
    sed -i "s|from .*|from            no-reply@nextcloudvm.com|g" /etc/msmtprc
    MAIL_USERNAME=no-reply@nextcloudvm.com
    # Second try
    if ! echo -e "$TEST_MAIL" | mail -s "Test email from your NcVM" "$RECIPIENT" >> /var/log/msmtp 2>&1
    then
        # Test another version
        echo 'set sendmail="/usr/bin/msmtp"' > /etc/mail.rc

        # Third try
        if ! echo -e "$TEST_MAIL" | mail -s "Test email from your NcVM" "$RECIPIENT" >> /var/log/msmtp 2>&1
        then
            # Fail message
            msg_box "It seems like something has failed.
You can look at /var/log/msmtp for further logs.
Please run this script once more if you want to make another try or \
if you want to deinstall all newly installed packages."
            exit 1
        fi
    fi
fi

# Success message
msg_box "Congratulations, the test email was successfully sent!
Please check the inbox for $RECIPIENT. The test email should arrive soon."

# Only offer to use the same settings in Nextcloud if a password was chosen
if [ "$MAIL_USERNAME" = "no-reply@nextcloudvm.com" ] && [ -z "$SMTP2GO" ]
then
    exit
fi

# Offer to use the same settings in Nextcloud
if ! yesno_box_no "Do you want to use the same mail server settings in your Nextcloud?
If you choose 'Yes', your Nextcloud will use the same mail settings that you've entered here."
then
    exit
fi

# SMTP mode
nextcloud_occ config:system:set mail_smtpmode --value="smtp"
nextcloud_occ config:system:set mail_sendmailmode --value="smtp"

# Encryption
if [ "$PROTOCOL" = "SSL" ]
then
    nextcloud_occ config:system:set mail_smtpsecure --value="ssl"
elif [ "$PROTOCOL" = "STARTTLS" ]
then
    nextcloud_occ config:system:set mail_smtpsecure --value="tls"
elif [ "$PROTOCOL" = "NO-ENCRYPTION" ]
then
    nextcloud_occ config:system:delete mail_smtpsecure
fi

# Authentification
nextcloud_occ config:system:set mail_smtpauthtype --value="LOGIN"
nextcloud_occ config:system:set mail_smtpauth --type=integer --value=1
if [ -n "$SMTP2GO" ]
then
    nextcloud_occ config:system:set mail_from_address --value="no-reply"
else
    nextcloud_occ config:system:set mail_from_address --value="${MAIL_USERNAME%%@*}"
fi
if [ -n "$SMTP2GO" ]
then
    nextcloud_occ config:system:set mail_domain --value="nextcloudvm.com"
else
    nextcloud_occ config:system:set mail_domain --value="${MAIL_USERNAME##*@}"
fi
nextcloud_occ config:system:set mail_smtphost --value="$MAIL_SERVER"
nextcloud_occ config:system:set mail_smtpport --value="$SMTP_PORT"
nextcloud_occ config:system:set mail_smtpname --value="$MAIL_USERNAME"
nextcloud_occ config:system:set mail_smtppassword --value="$MAIL_PASSWORD"

# Show success
msg_box "The mail settings in Nextcloud were successfully set!"

# Get admin users and create menu
args=(whiptail --title "$TITLE" --menu \
"Please select the admin user that will have $RECIPIENT as mail address.
$MENU_GUIDE" "$WT_HEIGHT" "$WT_WIDTH" 4)
NC_USERS_NEW=$(nextcloud_occ_no_check user:list | sed 's|^  - ||g' | sed 's|:.*||')
mapfile -t NC_USERS_NEW <<< "$NC_USERS_NEW"
for user in "${NC_USERS_NEW[@]}"
do
    if nextcloud_occ_no_check user:info "$user" | cut -d "-" -f2 | grep -x -q " admin"
    then
        args+=("$user" "")
    fi
done
choice=$("${args[@]}" 3>&1 1>&2 2>&3)
if [ -z "$choice" ]
then
    msg_box "No admin user selected. Exiting."
    exit 1
fi

# Set mail address for selected user
nextcloud_occ user:setting "$choice" settings email "$RECIPIENT"

# Here, it would be cool to test if sending a mail from Nextcloud works
# but this is unfortunately currently not possible via OCC, afaics

# Last message
msg_box "Congratulations, everything is now set up!"
