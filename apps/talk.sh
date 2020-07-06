#!/bin/bash

# T&M Hansson IT AB © - 2020, https://www.hanssonit.se/

# shellcheck disable=2034,2059
true
# shellcheck source=lib.sh
NC_UPDATE=1 && TURN_INSTALL=1 . <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)
unset NC_UPDATE
unset TURN_INSTALL

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Must be root
root_check

# Must be 20.04
if ! version 20.04 "$DISTRO" 20.04.6
then
msg_box "Your current Ubuntu version is $DISTRO but must be between 20.04 - 20.04.6 to install Talk"
msg_box "Please contact us to get support for upgrading your server:
https://www.hanssonit.se/#contact
https://shop.hanssonit.se/"
exit
fi

# Nextcloud 13 is required.
lowest_compatible_nc 13

# Check if adminer is already installed
print_text_in_color "$ICyan" "Checking if Talk is already installed..."
if [ -n "$(occ_command_no_check config:app:get spreed turn_servers | sed 's/\[\]//')" ] || is_this_installed coturn
then
    choice=$(whiptail --radiolist "It seems like 'Nextcloud Talk' is already installed.\nChoose what you want to do.\nSelect by pressing the spacebar and ENTER" "$WT_HEIGHT" "$WT_WIDTH" 4 \
    "Uninstall Nextcloud Talk" "" OFF \
    "Reinstall Nextcloud Talk" "" ON 3>&1 1>&2 2>&3)
    
    case "$choice" in
        "Uninstall Nextcloud Talk")
            print_text_in_color "$ICyan" "Uninstalling Nextcloud Talk and resetting all settings..."
            occ_command_no_check config:app:delete spreed stun_servers
            occ_command_no_check config:app:delete spreed turn_servers
            occ_command_no_check app:remove spreed
            rm $TURN_CONF
            apt-get purge coturn -y
            msg_box "Nextcloud Talk was successfully uninstalled and all settings were resetted."
            exit
        ;;
        "Reinstall Nextcloud Talk")
            print_text_in_color "$ICyan" "Reinstalling Nextcloud Talk..."
            occ_command_no_check config:app:delete spreed stun_servers
            occ_command_no_check config:app:delete spreed turn_servers
            occ_command_no_check app:remove spreed
            rm $TURN_CONF
            apt-get purge coturn -y
        ;;
        *)
        ;;
    esac
else
    print_text_in_color "$ICyan" "Installing Nextcloud Talk..."
fi

# Check if Nextcloud is installed
print_text_in_color "$ICyan" "Checking if Nextcloud is installed..."
if ! curl -s https://"${TURN_DOMAIN//\\/}"/status.php | grep -q 'installed":true'
then
msg_box "It seems like Nextcloud is not installed or that you don't use https on:
${TURN_DOMAIN//\\/}
Please install Nextcloud and make sure your domain is reachable, or activate TLS
on your domain to be able to run this script.
If you use the Nextcloud VM you can use the Let's Encrypt script to get TLS and activate your Nextcloud domain.

When TLS is activated, run these commands from your terminal:
sudo curl -sLO $APP/talk.sh
sudo bash talk.sh"
    exit 1
fi

# Let the user choose port. TURN_PORT in msg_box is taken from lib.sh and later changed if user decides to.
NONO_PORTS=(22 25 53 80 443 3306 5432 7983 8983 10000)
msg_box "The default port for Talk used in this script is port $TURN_PORT.
You can read more about that port here: https://www.speedguide.net/port.php?port=$TURN_PORT

You will now be given the option to change this port to something of your own. 
Please keep in mind NOT to use the following ports as they are likley to be in use already: 
${NONO_PORTS[*]}"

if [[ "yes" == $(ask_yes_or_no "Do you want to change port?") ]]
then
    while true
    do
    # Ask for port
cat << ENTERDOMAIN
+---------------------------------------------------------------+
|    Please enter the port you will use for Nextcloud Talk:     |
+---------------------------------------------------------------+
ENTERDOMAIN
    echo
    read -r TURN_PORT
    echo
    if [[ "yes" == $(ask_yes_or_no "Is this correct? $TURN_PORT") ]]
    then
        break
    fi
    done
fi

containsElement () {
  local e match="$1"
  shift
  for e; do [[ "$e" == "$match" ]] && return 0; done
  return 1
}

if containsElement "$TURN_PORT" "${NONO_PORTS[@]}"
then
    msg_box "You have to choose another port. Please start over."
    exit 1
fi

# Install TURN
check_command install_if_not coturn
check_command sed -i '/TURNSERVER_ENABLED/c\TURNSERVER_ENABLED=1' /etc/default/coturn

# Create log for coturn
mkdir -p "$VMLOGS"
touch "$VMLOGS"/turnserver.log

# Generate $TURN_CONF
cat << TURN_CREATE > "$TURN_CONF"
listening-port=$TURN_PORT
fingerprint
use-auth-secret
static-auth-secret=$TURN_SECRET
realm=$TURN_DOMAIN
total-quota=100
bps-capacity=0
stale-nonce
no-multicast-peers
no-stdout-log
simple-log
log-file=$VMLOGS/turnserver.log
TURN_CREATE
if [ -f "$TURN_CONF" ];
then
    print_text_in_color "$IGreen" "$TURN_CONF was successfully created."
else
    print_text_in_color "$IRed" "Unable to create $TURN_CONF, exiting..."
    print_text_in_color "$IRed" "Please report this issue here $ISSUES"
    exit 1
fi

# Restart the TURN server
check_command systemctl restart coturn.service

# Warn user to open port
msg_box "You have to open $TURN_PORT TCP/UDP in your firewall or your TURN/STUN server won't work!
After you hit OK the script will check for the firewall and eventually exit on failure.

To run again the setup, after fixing your firewall:
sudo -sLO $APP/talk.sh
sudo bash talk.sh"

# Check if the port is open
check_open_port "$TURN_PORT" "$TURN_DOMAIN"

# Enable Spreed (Talk)
STUN_SERVERS_STRING="[\"$TURN_DOMAIN:$TURN_PORT\"]"
TURN_SERVERS_STRING="[{\"server\":\"$TURN_DOMAIN:$TURN_PORT\",\"secret\":\"$TURN_SECRET\",\"protocols\":\"udp,tcp\"}]"
if ! is_app_installed spreed
then
    install_and_enable_app spreed
    occ_command config:app:set spreed stun_servers --value="$STUN_SERVERS_STRING" --output json
    occ_command config:app:set spreed turn_servers --value="$TURN_SERVERS_STRING" --output json
    chown -R www-data:www-data "$NC_APPS_PATH"
fi

if is_app_installed spreed
then
msg_box "Nextcloud Talk is now installed. For more information about Nextcloud Talk and its mobile apps visit:
https://nextcloud.com/talk/"
fi

exit
