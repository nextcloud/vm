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

# Test RAM size (3 GB min) + CPUs (min 2)
ram_check 3 Bitwarden
cpu_check 2 Bitwarden

# Check if Bitwarden is already installed
print_text_in_color "$ICyan" "Checking if Bitwarden is already installed..."
if [ "$(docker ps -a >/dev/null 2>&1 && echo yes || echo no)" == "yes" ]
then
    if docker ps -a --format '{{.Names}}' | grep -Eq "bitwarden";
    then
        if is_this_installed apache2
        then
            if [ -d /root/bwdata ]
            then
                msg_box "It seems like 'Bitwarden' is already installed.\n\nYou cannot run this script twice, because you would loose all your passwords."
                exit 1
            fi
        fi
    fi
fi

print_text_in_color "$ICyan" "Installing Bitwarden password manager..."

msg_box "Bitwarden is a password manager that is seperate from Nextcloud, though we provide this service because it's self hosted and secure.

If you just want to run Bitwarden locally (not connecting your smartphone) then you can use 'localhost' as domain.
If you on the other hand want to run this on a domain, then please create a DNS record and point it to this server.
In the process of setting up Bitwarden you will be asked to generate an TLS cert with Let's Enrypt so no need to get your own prior to this setup.

The script is based on this documentation: https://help.bitwarden.com/article/install-on-premise/
It's a good idea to read that before you start this script.

Please also report any issues regarding this script setup to $ISSUES"

msg_box "The necessary preparations to run expose Bitwarden to the internet are:
1. The HTTP proxy and HTTPS ports for Bitwarden are 8080 and 8443, please open those ports before running this script.
2. Please create a DNS record and point that to this server.
3. Raise the amount of RAM to this server to at least 3 GB."

if [[ "no" == $(ask_yes_or_no "Have you made the necessary preparations?") ]]
then
msg_box "OK, please do the necessary preparations before you run this script and then simply run it again once you're done.

To run this script again, execute $SCRIPTS/apps.sh and choose Bitwarden"
    exit
else
    sleep 0.1
fi

# Install Docker
install_docker
install_if_not docker-compose

# Stop Apache to not conflict when LE is run
check_command systemctl stop apache2.service

# Install Bitwarden 
install_if_not curl
cd /root
curl_to_dir "https://raw.githubusercontent.com/bitwarden/core/master/scripts" "bitwarden.sh" "/root"
chmod +x /root/bitwarden.sh
check_command ./bitwarden.sh install
sed -i "s|http_port.*|http_port: 8080|g" /root/bwdata/config.yml
sed -i "s|https_port.*|https_port: 8443|g" /root/bwdata/config.yml
check_command ./bitwarden.sh rebuild
check_command ./bitwarden.sh start
if check_command ./bitwarden.sh updatedb
then
msg_box "Bitwarden was sucessfully installed! Please visit $(grep 'url:' /root/bwdata/config.yml | awk '{print$2}'):8443 to setup your account."
else
msg_box "Bitwarden installation failed! We will now remove necessary configs to be able to run this script again"
    rm -rf /root/bwdata/
fi

# Start Apache2
check_command systemctl start apache2.service

exit
