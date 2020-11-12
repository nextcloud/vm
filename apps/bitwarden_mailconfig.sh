#!/bin/bash

# T&M Hansson IT AB © - 2020, https://www.hanssonit.se/

true
SCRIPT_NAME="Bitwarden Mail Configuration"
SCRIPT_EXPLAINER="This script lets you configure your mailserver settings for Bitwarden."
# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh || source <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)

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

# Enter mailserver
MAIL_SERVER=$(input_box_flow "Please enter the mailserver URL that you want to use.
E.g. smtp.mail.de\nIf you don't want to change the mailserver, that is already \
configured inside the global.override.env-file, just leave the box empty.")

# Enter if you want to use ssl
while :
do
    PROTOCOL=$(input_box "Please type in the encryption protocol for your mailserver.
The available options are 'SSL', 'STARTTLS' or 'none'.\n\nIf you don't want to change the protocol \
setting, that are already configured inside the global.override.env-file, just leave the box empty.")
    if ! yesno_box_yes "Is this correct? $PROTOCOL"
    then
        msg_box "OK, please try again."
    else
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
        elif [ "$PROTOCOL" = "" ]
        then
            DEFAULT_PORT=""
            break
        else
            msg_box "The answer wasn't correct. Please type in 'SSL', 'STARTTLS', 'none' or leave the inputbox empty."
        fi
    fi
done

# Enter Port or just use standard port (defined by usage of ssl)
SMTP_PORT=$(input_box_flow "Please enter the port for your mailserver. The default port \
based on your protocol setting is $DEFAULT_PORT?\nPlease type that port into the inputbox, \
if you want to use it.\n\nIf you don't want to change the port, that is already configured \
inside the global.override.env-file, just leave the box empty.")

# Enter your mail username
MAIL_USERNAME=$(input_box_flow "Please enter the username for the login to your mail provider.
E.g. mail@example.com\nPlease note: the domain used for your mail username and the mailserver \
domain have to match!\nIf you don't want to change the mail username that is already configured \
inside the global.override.env-file, just leave the box empty.")

# Enter your mailuser password
MAIL_PASSWORD=$(input_box_flow "Please enter the password for your mailserver user.
If you don't want to change the password, that is already configured inside the \
global.override.env-file, just leave the box empty.")

# Enter admin mailadresses
ADMIN_ACCOUNT=$(input_box_flow "Please enter mailaccounts, that should have access \
to the Bitwarden admin-panel, reachable under https://your-bitwarden-domain/admin/.
They don't have to be registered Bitwarden accounts.
To make this setting work, your Bitwarden mailserver settings have to be correct.
You can enter just one e-mailaddress or enter more than one like so:
'bitwarden@example.com,bitwarden2@example1.com,bitwarden3@example2.com'
If you want to keep the admin accounts that are already configured inside the \
global.override.env-file, just leave the box empty.")

# Get results and store in a variable:
RESULT="These are the settings that will be changed in global.override.env. \
Please check that everything seems correct.\n\n"
if [ -n "$MAIL_SERVER" ]
then
    RESULT+="Mailserver URL=$MAIL_SERVER\n"
fi
# SSL
if [ -n "$PROTOCOL" ]
then
    RESULT+="PROTOCOL=$PROTOCOL\n"
fi
# SMTP-Port
if [ -n "$SMTP_PORT" ]
then
    RESULT+="SMTP port=$SMTP_PORT\n"
fi
# Mail username
if [ -n "$MAIL_USERNAME" ]
then
    RESULT+="SMTP Username=$MAIL_USERNAME\n"
fi
# Mail password
if [ -n "$MAIL_PASSWORD" ]
then
    RESULT+="SMTP Password=$MAIL_PASSWORD\n"
fi
# Admin account(s)
if [ -n "$ADMIN_ACCOUNT" ]
then
    RESULT+="Admin account(s)=$ADMIN_ACCOUNT"
fi

# Present what we gathered, if everything okay, write to files
msg_box "$RESULT"
if ! yesno_box_yes "Do you want to proceed?"
then
    exit
fi

# Stop bitwarden
systemctl stop bitwarden

# Write to files
# mailserver
if [ -n "$MAIL_SERVER" ]
then
    check_command sed -i "s|^globalSettings__mail__smtp__host=.*|globalSettings__mail__smtp__host=$MAIL_SERVER|g" "$BITWARDEN_HOME"/bwdata/env/global.override.env
fi
# SSL
if [ "$PROTOCOL" = "SSL" ]
then
    check_command sed -i "s|^globalSettings__mail__smtp__ssl=.*|globalSettings__mail__smtp__ssl=true|g" "$BITWARDEN_HOME"/bwdata/env/global.override.env
    check_command sed -i "s|^globalSettings__mail__smtp__startTls=.*|globalSettings__mail__smtp__startTls=false|g" "$BITWARDEN_HOME"/bwdata/env/global.override.env
elif [ "$PROTOCOL" = "none" ]
then
    check_command sed -i "s|^globalSettings__mail__smtp__ssl=.*|globalSettings__mail__smtp__ssl=false|g" "$BITWARDEN_HOME"/bwdata/env/global.override.env
    check_command sed -i "s|^globalSettings__mail__smtp__startTls=.*|globalSettings__mail__smtp__startTls=false|g" "$BITWARDEN_HOME"/bwdata/env/global.override.env
elif [ "$PROTOCOL" = "STARTTLS" ]
then
    check_command sed -i "s|^globalSettings__mail__smtp__startTls=.*|globalSettings__mail__smtp__startTls=true|g" "$BITWARDEN_HOME"/bwdata/env/global.override.env
    check_command sed -i "s|^globalSettings__mail__smtp__ssl=.*|globalSettings__mail__smtp__ssl=false|g" "$BITWARDEN_HOME"/bwdata/env/global.override.env
fi
# SMTP-Port
if [ -n "$SMTP_PORT" ]
then
    check_command sed -i "s|^globalSettings__mail__smtp__port=.*|globalSettings__mail__smtp__port=$SMTP_PORT|g" "$BITWARDEN_HOME"/bwdata/env/global.override.env
fi
# Mail username
if [ -n "$MAIL_USERNAME" ]
then
    check_command sed -i "s|^globalSettings__mail__smtp__username=.*|globalSettings__mail__smtp__username=$MAIL_USERNAME|g" "$BITWARDEN_HOME"/bwdata/env/global.override.env
fi
# Mail password
if [ -n "$MAIL_PASSWORD" ]
then
    check_command sed -i "s|^globalSettings__mail__smtp__password=.*|globalSettings__mail__smtp__password=$MAIL_PASSWORD|g" "$BITWARDEN_HOME"/bwdata/env/global.override.env
fi
# Admin account(s)
if [ -n "$ADMIN_ACCOUNT" ]
then
    check_command sed -i "s|^adminSettings__admins=.*|adminSettings__admins=$ADMIN_ACCOUNT|g" "$BITWARDEN_HOME"/bwdata/env/global.override.env
fi

# Start Bitwarden
start_if_stopped bitwarden
msg_box "Your Bitwarden mailserver settings should be successfully changed by now.

If you experience any issues, please report them to $ISSUES"
exit
