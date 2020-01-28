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

# Check if root
root_check

# Check if adminer ist already installed
print_text_in_color "$ICyan" "Checking if Webmin is already installed..."
if is_this_installed webmin
then
    msg_box "It seems like 'Webmin' is already installed.\nIf you continue, Webmin will get removed now."
    if [[ "no" == $(ask_yes_or_no "Do you really want to continue?") ]]
    then
        check_command apt purge webmin -y
        msg_box "Webmin was successfully uninstalled."
        exit
    fi
fi

print_text_in_color "$ICyan" "Installing Webmin..."

# Install packages for Webmin
install_if_not apt-transport-https
install_if_not perl
install_if_not libnet-ssleay-perl
install_if_not openssl
install_if_not libauthen-pam-perl
install_if_not libpam-runtime
install_if_not libio-pty-perl
install_if_not apt-show-versions
install_if_not python

# Install Webmin
if curl -fsSL http://www.webmin.com/jcameron-key.asc | sudo apt-key add -
then
    echo "deb https://download.webmin.com/download/repository sarge contrib" > /etc/apt/sources.list.d/webmin.list
    apt update -q4 & spinner_loading
    install_if_not webmin
fi

exit
