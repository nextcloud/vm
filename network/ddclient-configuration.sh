#!/bin/bash

# T&M Hansson IT AB © - 2020, https://www.hanssonit.se/

# shellcheck disable=2034,2059
true
SCRIPT_NAME="DDclient Configuration"
# shellcheck source=lib.sh
. <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Check if root
root_check

choice=$(whiptail --title "$TITLE" --radiolist "This script lets you setup DynDNS by using the ddclient application.\nYou have to setup an account before you can start.\n\nPlease choose your DynDNS-Provider.\nSelect by pressing the spacebar and ENTER\n\nIf your DDNS provider isn't already supported, please open a new issue here:\n$ISSUES" "$WT_HEIGHT" "$WT_WIDTH" 4 \
"Cloudflare" "(cloudflare.com)" OFF \
"Strato" "(strato.de)" OFF 3>&1 1>&2 2>&3)

case "$choice" in
    "Cloudflare")
        PROVIDER="Cloudflare"
        INSTRUCTIONS="Register an email address for your domain and get an Cloudflare API-key"
        GUIDE="https://www.techandme.se/setup-multiple-accounts-with-ddclient-and-cloudflare/"
        PROTOCOL="cloudflare"
        SERVER="www.cloudflare.com"
        USE_SSL="yes"
    ;;
    "Strato")
        PROVIDER="Strato"
        INSTRUCTIONS="activate DynDNS for your Domain"
        GUIDE="https://www.strato.de/faq/domains/so-einfach-richten-sie-dyndns-fuer-ihre-domains-ein/"
        PROTOCOL="dyndns2"
        SERVER="dyndns.strato.com"
        USE_SSL="yes"
    ;;
    "")
        msg_box "You haven't selected any option. Exiting!"
        exit 1
    ;;
    *)
    ;;
esac

# Instructions
msg_box "Before you can continue, you have to access $PROVIDER and $INSTRUCTIONS.\nHere is a guide:\n$GUIDE"

# Ask if everything is prepared
if [[ "no" == $(ask_yes_or_no "Are you ready to continue?") ]]
then
    exit
fi

# Enter your Hostname
while true
do
    HOSTNAME=$(whiptail --inputbox "Please enter the Host that you want to configure DDNS for.\nE.g. 'example.com'" "$WT_HEIGHT" "$WT_WIDTH" 3>&1 1>&2 2>&3)
    if [[ "no" == $(ask_yes_or_no "Is this correct? $HOSTNAME") ]]
    then
        msg_box "OK, please try again."
    else
        if [ -z "$HOSTNAME" ]
        then
            msg_box "Please don't leave the inputbox empty."
        else
            break
        fi
    fi
done

# Enter your login
while true
do
    LOGIN=$(whiptail --inputbox "Please enter the login for your DDNS provider.\nIt will be most likely the domain or registered email address depending on your DDNS Provider.\nE.g. 'example.com' or 'mail@example.com'\nIf you are not sure, please refer to the documentation of your DDNS provider." "$WT_HEIGHT" "$WT_WIDTH" 3>&1 1>&2 2>&3)
    if [[ "no" == $(ask_yes_or_no "Is this correct? $LOGIN") ]]
    then
        msg_box "OK, please try again."
    else
        if [ -z "$LOGIN" ]
        then
            msg_box "Please don't leave the inputbox empty."
        else
            break
        fi
    fi
done

# Enter your password
while true
do
    PASSWORD=$(whiptail --inputbox "Please enter the password or api-key that you've got for DynDNS from your DDNS provider.\nIf you are not sure, please refer to the documentation of your DDNS provider." "$WT_HEIGHT" "$WT_WIDTH" 3>&1 1>&2 2>&3)
    if [[ "no" == $(ask_yes_or_no "Is this correct? $PASSWORD") ]]
    then
        msg_box "OK, please try again."
    else
        if [ -z "$PASSWORD" ]
        then
            msg_box "Please don't leave the inputbox empty."
        else
            break
        fi
    fi
done

# Get results and store in a variable:
RESULT="You will see now a list of all entered information. Please check that everything seems correct.\n\n"
RESULT+="Provider=$PROVIDER\n"
RESULT+="Host=$HOSTNAME\n"
RESULT+="login=$LOGIN\n"
RESULT+="password=$PASSWORD\n"

# Present what we gathered, if everything okay, write to file
msg_box "$RESULT"
if [[ "no" == $(ask_yes_or_no "Do you want to proceed?") ]]
then
    exit
fi

clear

# needed for cloudflare to work
if [ "$PROVIDER" = "Cloudflare" ]
then
    install_if_not libjson-any-perl
fi

# Install ddclient
if ! is_this_installed ddclient
then
    print_text_in_color "$ICyan" "Installing ddclient..."
    # This creates a ddclient service, creates a /etc/default/ddclient file and a /etc/ddclient.conf file
    DEBIAN_FRONTEND=noninteractive apt install ddclient -y
fi

if [ ! -f /etc/ddclient.conf ]
then
    msg_box "The default ddclient.conf doesn't seem to exist.\nPlease report this to\n$ISSUES."
    exit 1
fi

# Write information to ddclient.conf
cat << DDCLIENT_CONF > "/etc/ddclient.conf"
# Configuration file for ddclient generated by debconf
#
# /etc/ddclient.conf

# Default system settings
use=if, if=ens32
use=web, web=https://ipv4bot.whatismyipaddress.com

# DDNS-service specific setting
# Provider=$PROVIDER
protocol=$PROTOCOL
server=$SERVER
ssl=$USE_SSL

# user specific setting
login=$LOGIN
password=$PASSWORD

# Hostname follows:
zone=$HOSTNAME
$HOSTNAME
DDCLIENT_CONF

# Test connection
msg_box "Everything is setup by now and we will check the connection."
ddclient -verbose

# Inform user 
any_key "Please check the logs above and make sure that everything looks good. If not, just run this script again.
If you are certain, that you entered all things correctly and it didn't work, please report this to\n$ISSUES"
print_text_in_color "$ICyan" "exiting..."
exit
