#!/bin/bash

# T&M Hansson IT AB © - 2020, https://www.hanssonit.se/

true
SCRIPT_NAME="Webmin"
SCRIPT_EXPLAINER="Webmin is a web-based interface for system administration for Unix.
Using any modern web browser, you can setup user accounts, Apache, DNS, file sharing and much more.
Webmin removes the need to manually edit Unix configuration files like /etc/passwd, \
and lets you manage a system from the console or remotely.
See the following page with standard modules for a list of all the functions built into Webmin: \
https://webmin.com/standard.html"
# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh || source <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Check if root
root_check

# Check if webmin is already installed
if ! is_this_installed webmin
then
    # Ask for installing
    install_popup "$SCRIPT_NAME"
else
    # Ask for removal or reinstallation
    reinstall_remove_menu "$SCRIPT_NAME"
    # Removal
    check_command apt-get purge webmin -y
    rm -rf /etc/apt/sources.list.d/webmin.list
    # Show successful uninstall if applicable
    removal_popup "$SCRIPT_NAME"
fi

# Install packages for Webmin
install_if_not apt-transport-https
install_if_not perl
install_if_not libnet-ssleay-perl
install_if_not openssl
install_if_not libauthen-pam-perl
install_if_not libpam-runtime
install_if_not libio-pty-perl
install_if_not apt-show-versions
install_if_not python2

# Install Webmin
if curl -fsSL http://www.webmin.com/jcameron-key.asc | sudo apt-key add -
then
    echo "deb https://download.webmin.com/download/repository sarge contrib" > /etc/apt/sources.list.d/webmin.list
    apt update -q4 & spinner_loading
    install_if_not webmin
fi

print_text_in_color "$ICyan" "Configuring Webmin..."
# redirect access on http to https
check_command systemctl stop webmin
# Redirect http to https on the LAN IP
check_command sed -i '/^ssl=.*/a ssl_redirect=1' /etc/webmin/miniserv.conf
check_command sed -i "/^port=.*/a host=$ADDRESS" /etc/webmin/miniserv.conf
start_if_stopped webmin

msg_box "Webmin is now installed and can be accessed from this address:

https://$ADDRESS:10000

You can log in with your Ubuntu CLI user: $UNIXUSER."

exit
