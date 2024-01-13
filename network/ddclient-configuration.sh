#!/bin/bash

# T&M Hansson IT AB © - 2024, https://www.hanssonit.se/
# Copyright © 2021 Simon Lindner (https://github.com/szaimen)

true
SCRIPT_NAME="DynDNS with ddclient"
SCRIPT_EXPLAINER="This script lets you set up DynDNS by using the Linux ddclient software."
# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Check if root
root_check

# Check if ddclient is already installed
if [ -n "$DEDYNDOMAIN" ]
then
    print_text_in_color "$ICyan" "Setting up ddclient for deSEC..."
elif ! is_this_installed ddclient
then
    # Ask for installing
    install_popup "$SCRIPT_NAME"
else
    # Ask for removal or reinstallation
    reinstall_remove_menu "$SCRIPT_NAME"
    # Removal
    apt-get purge ddclient -y
    if is_this_installed libjson-any-perl
    then
        apt-get purge libjson-any-perl -y
    fi
    apt-get autoremove -y
    rm -f /etc/ddclient.conf
    # Show successful uninstall if applicable
    removal_popup "$SCRIPT_NAME"
fi

# install needed tool
apt-get update -q4 & spinner_loading
DEBIAN_FRONTEND=noninteractive apt-get install ddclient -y

# Test if file exists
if [ ! -f /etc/ddclient.conf ]
then
    msg_box "The default ddclient.conf doesn't seem to exist.\nPlease report this to\n$ISSUES."
    exit 1
fi

if [ -n "$DEDYNDOMAIN" ]
then
    choice="deSEC"
else
    choice=$(whiptail --title "$TITLE" --menu \
"Please choose your DynDNS-Provider.\nYou have to set up an account before you can start.\n
If your DDNS provider isn't already supported, please open a new issue here:\n$ISSUES
$MENU_GUIDE\n\n$RUN_LATER_GUIDE" "$WT_HEIGHT" "$WT_WIDTH" 4 \
"Cloudflare" "(cloudflare.com)" \
"deSEC" "(desec.io)" \
"Duck DNS" "(duckdns.org)" \
"Google Domains" "(domains.google)" \
"No-IP" "(noip.com)" \
"Strato" "(strato.de)" 3>&1 1>&2 2>&3)
fi

case "$choice" in
    "Cloudflare")
        PROVIDER="Cloudflare"
        INSTRUCTIONS="register an email address for your domain and get an Cloudflare API-key"
        GUIDE="https://www.techandme.se/setup-multiple-accounts-with-ddclient-and-cloudflare/"
        PROTOCOL="cloudflare"
        SERVER="www.cloudflare.com"
        USE_SSL="yes"
    ;;
    "deSEC")
        PROVIDER="deSEC"
        INSTRUCTIONS="get a DDNS account with password"
        GUIDE="https://desec.io/#"
        PROTOCOL="dyndns2"
        SERVER="update.dedyn.io"
        USE_SSL="yes"
    ;;
    "Duck DNS")
        PROVIDER="Duck DNS"
        INSTRUCTIONS="get a DDNS account with password"
        GUIDE="https://www.duckdns.org/faqs.jsp"
        PROTOCOL="duckdns"
        SERVER="www.duckdns.org"
        USE_SSL="yes"
    ;;
    "Google Domains")
        PROVIDER="Google Domains"
        INSTRUCTIONS="activate DynDNS for your Domain"
        GUIDE="https://support.google.com/domains/answer/6147083"
        PROTOCOL="dyndns2"
        SERVER="domains.google.com"
        USE_SSL="yes"
    ;;
    "No-IP")
        PROVIDER="No-IP"
        INSTRUCTIONS="get a DDNS account with password"
        GUIDE="https://youtu.be/1eeMxhpT868"
        PROTOCOL="dyndns2"
        SERVER="dynupdate.no-ip.com"
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

if [ -n "$DEDYNDOMAIN" ]
then
    HOSTNAME="$DEDYNDOMAIN"
    LOGIN="$DEDYNDOMAIN"
    PASSWORD="$DEDYNAUTHTOKEN"
else
    # Instructions
    msg_box "Before you can continue, you have to access $PROVIDER and $INSTRUCTIONS.\n\nHere is a guide:\n$GUIDE"

    # Ask if everything is prepared
    if ! yesno_box_yes "Are you ready to continue?"
    then
        exit
    fi

    # Enter your Hostname
    HOSTNAME=$(input_box_flow "Please enter the Host that you want to configure DDNS for.\nE.g. 'example.com'")

    # Enter your login
    LOGIN=$(input_box_flow "Please enter the login for your DDNS provider.\nIt will be most likely the domain \
or registered email address depending on your DDNS Provider.\nE.g. 'example.com' or 'mail@example.com'
If you are not sure, please refer to the documentation of your DDNS provider.")

    # Enter your password
    PASSWORD=$(input_box_flow "Please enter the password or api-key that you've got for DynDNS from your DDNS provider.
If you are not sure, please refer to the documentation of your DDNS provider.")

    # Present what we gathered
    msg_box "You will see now a list of all entered information. Please check that everything seems correct.\n
Provider=$PROVIDER
Host=$HOSTNAME
Login=$LOGIN
Password=$PASSWORD"

    # If everything okay, write to file
    if ! yesno_box_yes "Do you want to proceed?"
    then
        exit
    fi

    # needed for cloudflare to work
    if [ "$PROVIDER" = "Cloudflare" ]
    then
        install_if_not libjson-any-perl
    fi
fi

# Write information to ddclient.conf
cat << DDCLIENT_CONF > "/etc/ddclient.conf"
# Configuration file for ddclient generated by debconf
#
# /etc/ddclient.conf

# Default system settings
use=if, if=$IFACE
use=web, web=https://api.ipify.org

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
msg_box "Everything is set up by now and we will check the connection."
if ! ddclient -verbose
then
    msg_box "Something failed while testing the DDNS update.
Please try again by running this script again!"
else
    msg_box "Congratulations, it seems like the initial DDNS update worked!
DDclient is now set up correctly!"
fi
exit
