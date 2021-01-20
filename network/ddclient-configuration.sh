#!/bin/bash

# T&M Hansson IT AB © - 2021, https://www.hanssonit.se/
# Copyright © 2021 Simon Lindner (https://github.com/szaimen)

true
SCRIPT_NAME="DynDNS with ddclient"
SCRIPT_EXPLAINER="This script lets you setup DynDNS by using the Linux ddclient software."
# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh || source <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Check if root
root_check

# Check if ddclient is already installed
if ! is_this_installed ddclient && ! (is_docker_running && docker ps -a --format "{{.Names}}" | grep -q "^ddclient$")
then
    # Ask for installing
    install_popup "$SCRIPT_NAME"
else
    # Ask for removal or reinstallation
    reinstall_remove_menu "$SCRIPT_NAME"
    # Removal
    if is_this_installed ddclient
    then
        apt purge ddclient -y
    fi
    if is_this_installed libjson-any-perl
    then
        apt purge libjson-any-perl -y
    fi
    apt autoremove -y
    rm -f /etc/ddclient.conf
    if is_docker_running && docker ps -a --format "{{.Names}}" | grep -q "^ddclient$"
    then
        docker stop ddclient
        docker rm ddclient
    fi
    rm -rf /home/ddclient
    # Show successful uninstall if applicable
    removal_popup "$SCRIPT_NAME"
fi

# install needed tool
install_docker
docker pull ghcr.io/linuxserver/ddclient

choice=$(whiptail --title "$TITLE" --menu \
"Please choose your DynDNS-Provider.\nYou have to setup an account before you can start.\n
If your DDNS provider isn't already supported, please open a new issue here:\n$ISSUES
$MENU_GUIDE\n\n$RUN_LATER_GUIDE" "$WT_HEIGHT" "$WT_WIDTH" 4 \
"Cloudflare" "(cloudflare.com)" \
"deSEC" "(desec.io)" \
"Duck DNS" "(duckdns.org)" \
"Strato" "(strato.de)" 3>&1 1>&2 2>&3)

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

# Create directory
mkdir -p /home/ddclient

# Write information to ddclient.conf
cat << DDCLIENT_CONF > "/home/ddclient/ddclient.conftemp"
# Default system settings
use=if, if=$IFACE
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

# Correct permissions
chown nobody:nogroup -R /home/ddclient
chmod 600 -R /home/ddclient

# Create docker container
docker run -d \
  --name=ddclient \
  -e PUID=65534 \
  -e PGID=65534 \
  -v /home/ddclient:/config \
  -v /etc/timezone:/etc/timezone:ro \
  -v /etc/localtime:/etc/localtime:ro \
  ghcr.io/linuxserver/ddclient

# Inform user
msg_box "Everything is set up by now and we will check the connection."

# Test connection
if ! docker exec ddclient bash -c "ddclient -file /config/ddclient.conftemp -verbose"
then
    msg_box "Something failed while testing the DDNS update.
Please try again by running this script again!"
else
    mv /home/ddclient/ddclient.conftemp /home/ddclient/ddclient.conf
    msg_box "Congratulations, it seems like the initial DDNS update worked!
DDclient is now set up correctly!"
fi
exit
