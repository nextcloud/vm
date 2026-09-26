#!/bin/bash

# T&M Hansson IT AB © - 2026, https://www.hanssonit.se/

true
SCRIPT_NAME="Webmin"
SCRIPT_EXPLAINER="Webmin is a web-based interface for system administration for Unix.
Using any modern web browser, you can set up user accounts, Apache, DNS, file sharing and much more.
Webmin removes the need to manually edit Unix configuration files like /etc/passwd, \
and lets you manage a system from the console or remotely.
See the following page with standard modules for a list of all the functions built into Webmin: \
https://webmin.com/standard.html"
# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh

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
    apt-get autoremove -y
    rm -f /etc/apt/sources.list.d/webmin.list
    rm -f /etc/apt/trusted.gpg.d/webmin.gpg
    rm -f /etc/apt/keyrings/jcameron-key.asc
    rm -f /etc/apt/keyrings/developers-key.asc
    sed -i '/webmin/d' /etc/apt/sources.list
    apt-get clean all
    apt-get update
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
install_if_not unzip
install_if_not shared-mime-info
install_if_not zip

# https://github.com/webmin/webmin/issues/1169
apt-get clean all
apt-get update -q4 & spinner_loading

# Install Webmin
# The old repository (sarge) is signed with a DSA-1024 key which apt rejects, so use the new one
# https://webmin.com/download/
# Remove the list from upstream's webmin-setup-repo.sh, apt fails if the same repo has a different signed-by
rm -f /etc/apt/sources.list.d/webmin-stable.list
add_trusted_key_and_repo "developers-key.asc" \
"https://download.webmin.com" \
"https://download.webmin.com/download/newkey/repository" \
"stable contrib" \
"webmin.list"
install_if_not webmin

# Check that Webmin was installed
if ! is_this_installed webmin
then
    msg_box "Failed to install $SCRIPT_NAME.
Please report this to $ISSUES"
    exit 1
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
