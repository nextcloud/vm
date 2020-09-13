#!/bin/bash

# T&M Hansson IT AB © - 2020, https://www.hanssonit.se/

# shellcheck disable=2034,2059
true
SCRIPT_NAME="Webmin"
# shellcheck source=lib.sh
. <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Check if root
root_check

# Check if webmin is already installed
print_text_in_color "$ICyan" "Checking if Webmin is already installed..."
if is_this_installed webmin
then
    choice=$(whiptail --title "$TITLE" --menu "It seems like 'Webmin' is already installed.\nChoose what you want to do." "$WT_HEIGHT" "$WT_WIDTH" 4 \
    "Reinstall Webmin" "" \
    "Uninstall Webmin" "" 3>&1 1>&2 2>&3)
    
    case "$choice" in
        "Uninstall Webmin")
            print_text_in_color "$ICyan" "Uninstalling Webmin..."
            check_command apt --purge autoremove -y webmin
            msg_box "Webmin was successfully uninstalled."
            exit
        ;;
        "Reinstall Webmin")
            print_text_in_color "$ICyan" "Reinstalling Webmin..."
            check_command apt-get purge webmin -y
        ;;
        *)
        ;;
    esac
else
    print_text_in_color "$ICyan" "Installing Webmin..."
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
## TODO: This will cause Webmin to redirect to the hostname 'nextcloud' and not the IP address if on LAN
check_command sed -i '/^ssl=.*/a ssl_redirect=1' /etc/webmin/miniserv.conf
check_command sed -i "/^port=.*/a host=$ADDRESS" /etc/webmin/miniserv.conf
check_command systemctl start webmin

msg_box "Webmin is now installed and can be accessed from this address:

https://$ADDRESS:10000

You can log in with your Ubuntu CLI user: $UNIXUSER."

exit
