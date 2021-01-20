#!/bin/bash

# T&M Hansson IT AB © - 2021, https://www.hanssonit.se/

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
if ! [ -f /etc/msmtprc ] && ! (is_docker_running && docker ps -a --format "{{.Names}}" | grep -q "^msmtpd$")
then
    # Ask for installing
    install_popup "$SCRIPT_NAME"
else
    # Ask for removal or reinstallation
    reinstall_remove_menu "$SCRIPT_NAME"
    # Removal
    for packet in msmtp msmtp-mta mailutils
    do
        if is_this_installed "$packet"
        then
            apt purge "$packet" -y
        fi
    done
    apt autoremove -y
    rm -f /etc/mail.rc
    rm -f /etc/msmtprc
    rm -f /var/log/msmtp
    echo "" > /etc/aliases
    if is_docker_running && docker ps -a --format "{{.Names}}" | grep -q "^msmtpd$"
    then
        docker stop msmtpd
        docker rm msmtpd
    fi
    rm -fr /home/msmtpd
    # Show successful uninstall if applicable
    removal_popup "$SCRIPT_NAME"
fi

# Install needed tools
install_docker
docker pull crazymax/msmtpd

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
if yesno_box_yes "Does $MAIL_SERVER require any credentials, like username and password?"
then
    MAIL_USERNAME=$(input_box_flow "Please enter the SMTP username to your email provider.\nE.g. you@mail.com")

    # Enter your mail user password
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
    MSMTP_ENCRYPTION1="SMTP_TLS=on"
    MSMTP_ENCRYPTION2="SMTP_STARTTLS=off"
    MSMTP_ENCRYPTION3="SMTP_TLS_CHECKCERT=on"
elif [ "$PROTOCOL" = "STARTTLS" ]
then
    MSMTP_ENCRYPTION1="SMTP_TLS=on"
    MSMTP_ENCRYPTION2="SMTP_STARTTLS=on"
    MSMTP_ENCRYPTION3="SMTP_TLS_CHECKCERT=on"
elif [ "$PROTOCOL" = "NO-ENCRYPTION" ]
then
    MSMTP_ENCRYPTION1="SMTP_TLS=off"
    MSMTP_ENCRYPTION2="SMTP_STARTTLS=off"
    MSMTP_ENCRYPTION3="SMTP_TLS_CHECKCERT=off"
fi

mkdir -p /home/msmtpd

# Check if auth should be set or not
if [ -z "$MAIL_USERNAME" ]
then
    MAIL_USERNAME="no-reply@nextcloudvm.com"

    # Without AUTH (Username and Password)
    cat << MSMTP_CONF > /home/msmtpd/conf
SMTP_AUTH=off
$MSMTP_ENCRYPTION1
$MSMTP_ENCRYPTION2
$MSMTP_ENCRYPTION3
SMTP_USER=$MAIL_USERNAME
SMTP_HOST=$MAIL_SERVER
SMTP_PORT=$SMTP_PORT
SMTP_FROM=$MAIL_USERNAME
MSMTP_CONF
    else
    # With AUTH (Username and Password)
    cat << MSMTP_CONF > /home/msmtpd/conf
SMTP_AUTH=on
$MSMTP_ENCRYPTION1
$MSMTP_ENCRYPTION2
$MSMTP_ENCRYPTION3
SMTP_USER=$MAIL_USERNAME
SMTP_HOST=$MAIL_SERVER
SMTP_PORT=$SMTP_PORT
SMTP_FROM=$MAIL_USERNAME
SMTP_PASSWORD=$MAIL_PASSWORD
MSMTP_CONF
    fi

# Add recipient file
cat << RECEIVER > /home/msmtpd/receiver
### DO NOT REMOVE THE NEXT LINE (it's used in one of the functions in on the Nextcloud Server)
RECIPIENT=$RECIPIENT
RECEIVER
chown root:root /home/msmtpd/receiver
chmod 700 /home/msmtpd/receiver

# Store message in a variable
TEST_MAIL="Congratulations!

Given this email reached you, it seems like everything is working properly. :)

To change the settings simply run the setup script again.

YOUR CURRENT SETTINGS:
-------------------------------------------
$(grep -v SMTP_PASSWORD /home/msmtpd/conf)
-------------------------------------------

Best regards
The NcVM team
https://nextcloudvm.com"

# Start docker container
docker run -d --name msmtpd \
  --env-file /home/msmtpd/conf \
  -v /etc/timezone:/etc/timezone:ro \
  -v /etc/localtime:/etc/localtime:ro \
  --restart always \
  crazymax/msmtpd

# Remove the conf-file since no longer needed
rm -f /home/msmtpd/conf

# Test mail
sleep 2
if ! send_mail "Test email from your NcVM" "$TEST_MAIL"
then
    # Fail message
    msg_box "It seems like something has failed.
Please try again!"
    exit 1
fi

# Success message
msg_box "Congratulations, the test email was successfully sent!
Please check the inbox for $RECIPIENT. The test email should arrive soon."
exit
