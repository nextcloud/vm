#!/bin/bash

# T&M Hansson IT AB © - 2020, https://www.hanssonit.se/

true
SCRIPT_NAME="SMTP Relay with msmtp"
SCRIPT_EXPLAINER="This script will setup an SMTP Relay (Mail Server) in your Nextcloud Server \
that will be used to send emails about failed cronjob's and such."
# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh || source <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)

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
    apt autoremove -y
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

# Enter your SMTP username
if yesno_box_yes "Does $MAIL_SERVER require any credenitals, like username and password?"
then
    MAIL_USERNAME=$(input_box_flow "Please enter the SMTP username to your email provider.\nE.g. you@mail.com")

    # Enter your mailuser password
    MAIL_PASSWORD=$(input_box_flow "Please enter the SMTP password to your email provider.")
fi

# Enter the recipient
RECIPIENT=$(input_box_flow "Please enter the recipient email address that shall receive all mails.\nE.g. recipient@mail.com")

# Present what we gathered, if everything okay, write to files
msg_box "These are the settings that will be used. Please check that everything seems correct.

SMTP Relay URL=$MAIL_SERVER
Encryption=$PROTOCOL
SMTP Port=$SMTP_PORT
SMTP Username=$MAIL_USERNAME
SMTP Password=$MAIL_PASSWORD
Recipient=$RECIPIENT"

# Ask if everything is okay
if ! yesno_box_yes "Does everything look correct?"
then
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

Since this email reached you, it seems like everything is working properly. :)

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
    # Test another version
    echo 'set sendmail="/usr/bin/msmtp"' > /etc/mail.rc

    # Second try
    if ! echo -e "$TEST_MAIL" | mail -s "Test email from your NcVM" "$RECIPIENT" >> /var/log/msmtp 2>&1
    then
        # Fail message
        msg_box "It seems like something has failed.
You can look at /var/log/msmtp for further logs.
Please run this script once more if you want to make another try."

        # Let the user decide if configs/packets shall get resetted/uninstalled
        if yesno_box_yes "Do you want to reset all configs and uninstall all packets \
that were made/installed by this script so that you keep a clean system?
This will make debugging more complicated since you will only have the log file to debug this."
        then
            apt-get purge msmtp -y
            apt-get purge msmtp-mta -y
            apt-get purge mailutils -y
            apt autoremove -y
            rm -f /etc/mail.rc
            rm -f /etc/msmtprc
            echo "" > /etc/aliases
            msg_box "Uninstallation of MSMTP was successfully done" 
        fi
        exit 1
    fi
fi

# Success message
msg_box "Congratulations, the test email was successfully sent!
Please check the inbox for $RECIPIENT. The test email should arrive soon."
exit
