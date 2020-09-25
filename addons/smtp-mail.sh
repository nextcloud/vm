#!/bin/bash

# T&M Hansson IT AB © - 2020, https://www.hanssonit.se/

# shellcheck disable=2034,2059
true
SCRIPT_NAME="SMTP Mail"
SCRIPT_EXPLAINER="This script helps setting up a SMTP client for the OS, \
that will be used to send Mails about failed Cronjob's and such."
# shellcheck source=lib.sh
. <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Must be root
root_check

# Show explainer
explainer_popup

# Check if smtp-mail was already configured
print_text_in_color "$ICyan" "Checking if smtp-mail is already installed and configured..."
if [ -f /etc/msmtprc ]
then
    # Ask for removal or reinstallation
    reinstall_remove_menu
    # Removal
    apt-get purge msmtp -y
    apt-get purge msmtp-mta -y
    apt-get purge mailutils -y
    apt autoremove -y
    mv /etc/aliases.backup /etc/aliases
    rm -f /etc/mail.rc
    rm -f /etc/msmtprc
    # Show successful uninstall if applicable
    removal_popup
else
    print_text_in_color "$ICyan" "Installing smtp-mail..."
fi

# Install needed tools
install_if_not msmtp
install_if_not msmtp-mta
install_if_not mailutils

# Enter mailserver
MAIL_SERVER=$(input_box_flow "Please enter the mailserver URL that you want to use.\nE.g. smtp.mail.de")

# Enter if you want to use ssl
while :
do
    PROTOCOL=$(input_box_flow "Please type in the encryption protocol for your mailserver.
The available options are 'SSL', 'STARTTLS' or 'none'.")
    if [ "$PROTOCOL" = "SSL" ]
    then
        DEFAULT_PORT=465
        break
    elif [ "$PROTOCOL" = "none" ]
    then
        DEFAULT_PORT=25
        break
    elif [ "$PROTOCOL" = "STARTTLS" ]
    then
        DEFAULT_PORT=587
        break
    else
        msg_box "The answer wasn't correct. Please type in 'SSL', 'STARTTLS' or 'none'."
    fi
done

# Enter Port or just use standard port (defined by usage of ssl)
SMTP_PORT=$(input_box_flow "Please enter the port for your mailserver.
The default port based on your protocol setting is '$DEFAULT_PORT'.
Please type the port that you want to use into the inputbox.")

# Enter your mail username
MAIL_USERNAME=$(input_box_flow "Please enter the username for the login to your mail provider.
E.g. mail@example.com
Please note: the domain used for your mail username and the mailserver domain have to match!")

# Enter your mailuser password
MAIL_PASSWORD=$(input_box_flow "Please enter the password for your mailserver user.")

# Enter the recipient
RECIPIENT=$(input_box_flow "Please enter the recipient mail-address that shall receive all mails.
E.g. mail@example.com")

# Present what we gathered, if everything okay, write to files
msg_box "These are the settings that will be used. Please check that everything seems correct.

Mailserver URL=$MAIL_SERVER
Encryption=$PROTOCOL
SMTP-port=$SMTP_PORT
SMTP-username=$MAIL_USERNAME
SMTP-password=$MAIL_PASSWORD
Recipient=$RECIPIENT"

# Ask if everything is okay
if ! yesno_box_yes "Do you want to proceed?"
then
    exit
fi

# Create the file
cat << MSMTP_CONF > /etc/msmtprc
defaults
port $SMTP_PORT
tls_trust_file /etc/ssl/certs/ca-certificates.crt
account $MAIL_USERNAME
host $MAIL_SERVER
from $MAIL_USERNAME
auth on
user $MAIL_USERNAME
password $MAIL_PASSWORD
account default: $MAIL_USERNAME
aliases /etc/aliases
# recipient=$RECIPIENT
MSMTP_CONF
unset MAIL_PASSWORD

# Add the encryption settings to the file as well
if [ "$PROTOCOL" = "SSL" ]
then
cat << MSMTP_CONF >> /etc/msmtprc
tls on
tls_starttls off
MSMTP_CONF
elif [ "$PROTOCOL" = "STARTTLS" ]
then
cat << MSMTP_CONF >> /etc/msmtprc
tls off
tls_starttls on
MSMTP_CONF
elif [ "$PROTOCOL" = "none" ]
then
cat << MSMTP_CONF >> /etc/msmtprc
tls off
tls_starttls off
MSMTP_CONF
fi

# Secure the file
chmod 600 /etc/msmtprc

# Create a backup of the aliases file
mv /etc/aliases /etc/aliases.backup

# Create aliases
cat << ALIASES_CONF > /etc/aliases
root: $MAIL_USERNAME
default: $MAIL_USERNAME
ALIASES_CONF

# Define the mail-program
cat << DEFINE_MAIL > /etc/mail.rc
set sendmail="/usr/bin/msmtp -t"
DEFINE_MAIL

# Test sending of mails
if ! echo -e "Congratulations!\nThis testmail has reached you, \
so it seems like everything was setup correctly." | mail -s "Testmail from your NcVM" "$RECIPIENT" &>/dev/null
then
    # Fail message
    msg_box "It seems like something has failed.
We will now reset everything so that you are able to start over again.
Please run this script again."
    apt-get purge msmtp -y
    apt-get purge msmtp-mta -y
    apt-get purge mailutils -y
    apt autoremove -y
    mv /etc/aliases.backup /etc/aliases
    rm -f /etc/mail.rc
    rm -f /etc/msmtprc
else
    # Success message
    msg_box "Congratulaions, the testmail was sent successfully.
Please look at the inbox of your recipient $RECIPIENT. The testmail should be there."
fi
exit
