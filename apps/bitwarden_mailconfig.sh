#!/bin/bash

# T&M Hansson IT AB © - 2024, https://www.hanssonit.se/

true
SCRIPT_NAME="Bitwarden Mail Configuration"
SCRIPT_EXPLAINER="This script lets you configure your mailserver settings for Bitwarden."
# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Must be root
root_check

# Show explainer
msg_box "$SCRIPT_EXPLAINER"

# Check if Bitwarden is already installed
print_text_in_color "$ICyan" "Checking if Bitwarden is already installed..."
if is_docker_running
then
    if docker ps -a --format '{{.Names}}' | grep -Eq "bitwarden";
    then
        if [ ! -d "$BITWARDEN_HOME"/bwdata ]
        then
            msg_box "It seems like 'Bitwarden' isn't installed in $BITWARDEN_HOME.\n\nYou cannot run this script."
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

# Let the user cancel
if ! yesno_box_yes "Do you want to continue?"
then
    exit
fi

# Insert globalSettings__mail__smtp__trustServer to global.override
if ! grep -q "^globalSettings__mail__smtp__trustServer=" "$BITWARDEN_HOME"/bwdata/env/global.override.env
then
    echo "globalSettings__mail__smtp__trustServer=false" >> "$BITWARDEN_HOME"/bwdata/env/global.override.env
fi

# Insert globalSettings__mail__smtp__startTls to global.override
if ! grep -q "^globalSettings__mail__smtp__startTls=" "$BITWARDEN_HOME"/bwdata/env/global.override.env
then
    echo "globalSettings__mail__smtp__startTls=false" >> "$BITWARDEN_HOME"/bwdata/env/global.override.env
fi

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

while :
do
    ADMIN_ACCOUNT=$(input_box "Please enter mail accounts, that should have access \
to the Bitwarden admin-panel, reachable under https://your-bitwarden-domain/admin/.
They don't have to be registered Bitwarden accounts.
To make this setting work, your Bitwarden mailserver settings have to be correct.
You can enter just one e-mail address or enter more than one like so:
'bitwarden@example.com,bitwarden2@example1.com,bitwarden3@example2.com'
If you want to keep the admin accounts that are already configured inside the \
global.override.env-file, just leave the box empty.")

    if [ -n "$ADMIN_ACCOUNT" ]
    then
        if yesno_box_yes "Does this look correct: $ADMIN_ACCOUNT"
        then
            break
        fi
    else
        break
    fi
done

# Present what we gathered, if everything okay, write to files
msg_box "These are the settings that will be used. Please check that everything seems correct.

SMTP Relay URL=$MAIL_SERVER
Encryption=$PROTOCOL
SMTP Port=$SMTP_PORT
SMTP Username=$MAIL_USERNAME
SMTP Password=$MAIL_PASSWORD
Admin account(s)=$ADMIN_ACCOUNT"

# Ask if everything is okay
if ! yesno_box_yes "Does everything look correct?"
then
    exit
fi

# Check if auth should be set or not
if [ -z "$MAIL_USERNAME" ]
then
    MAIL_USERNAME="no-reply@nextcloudvm.com"
fi

# Stop bitwarden
systemctl stop bitwarden
while :
do
    if systemctl status bitwarden | grep -q 'Active: active' > /dev/null 2>&1
    then
        sleep 3
    else
        break
     fi
done

# Write to files
# mailserver
check_command sed -i "s|^globalSettings__mail__smtp__host=.*|globalSettings__mail__smtp__host=$MAIL_SERVER|g" "$BITWARDEN_HOME"/bwdata/env/global.override.env
# SSL
if [ "$PROTOCOL" = "SSL" ]
then
    check_command sed -i "s|^globalSettings__mail__smtp__ssl=.*|globalSettings__mail__smtp__ssl=true|g" "$BITWARDEN_HOME"/bwdata/env/global.override.env
    check_command sed -i "s|^globalSettings__mail__smtp__startTls=.*|globalSettings__mail__smtp__startTls=false|g" "$BITWARDEN_HOME"/bwdata/env/global.override.env
elif [ "$PROTOCOL" = "NO-ENCRYPTION" ]
then
    check_command sed -i "s|^globalSettings__mail__smtp__ssl=.*|globalSettings__mail__smtp__ssl=false|g" "$BITWARDEN_HOME"/bwdata/env/global.override.env
    check_command sed -i "s|^globalSettings__mail__smtp__startTls=.*|globalSettings__mail__smtp__startTls=false|g" "$BITWARDEN_HOME"/bwdata/env/global.override.env
elif [ "$PROTOCOL" = "STARTTLS" ]
then
    check_command sed -i "s|^globalSettings__mail__smtp__startTls=.*|globalSettings__mail__smtp__startTls=true|g" "$BITWARDEN_HOME"/bwdata/env/global.override.env
    check_command sed -i "s|^globalSettings__mail__smtp__ssl=.*|globalSettings__mail__smtp__ssl=false|g" "$BITWARDEN_HOME"/bwdata/env/global.override.env
fi
# SMTP-Port
check_command sed -i "s|^globalSettings__mail__smtp__port=.*|globalSettings__mail__smtp__port=$SMTP_PORT|g" "$BITWARDEN_HOME"/bwdata/env/global.override.env
# Mail username
check_command sed -i "s|^globalSettings__mail__smtp__username=.*|globalSettings__mail__smtp__username=$MAIL_USERNAME|g" "$BITWARDEN_HOME"/bwdata/env/global.override.env
# Mail password
check_command sed -i "s|^globalSettings__mail__smtp__password=.*|globalSettings__mail__smtp__password=$MAIL_PASSWORD|g" "$BITWARDEN_HOME"/bwdata/env/global.override.env
# Admin account(s)
check_command sed -i "s|^adminSettings__admins=.*|adminSettings__admins=$ADMIN_ACCOUNT|g" "$BITWARDEN_HOME"/bwdata/env/global.override.env

# Start Bitwarden
systemctl start bitwarden
while :
do
    if ! systemctl status bitwarden | grep -q 'Active: active' > /dev/null 2>&1
    then
        sleep 3
    else
        break
     fi
done

msg_box "Your Bitwarden mailserver settings should be successfully changed by now.

If you experience any issues, please report them to $ISSUES"
exit
