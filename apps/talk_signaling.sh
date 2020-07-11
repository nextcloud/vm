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

DESCRIPTION="High Performance Backend for Talk"

# Check if root
root_check

# Check if HPB is already installed
is_process_running dpkg
is_process_running apt
print_text_in_color "$ICyan" "Checking if ${DESCRIPTION} is already installed..."
if ! is_this_installed nextcloud-spreed-signaling
then
    choice=$(whiptail --radiolist "It seems like '${DESCRIPTION}' is already installed.\nChoose what you want to do.\nSelect by pressing the spacebar and ENTER" "$WT_HEIGHT" "$WT_WIDTH" 4 \
    "Uninstall ${DESCRIPTION}" "" OFF \
    "Reinstall ${DESCRIPTION}" "" ON 3>&1 1>&2 2>&3)
    case "$choice" in
        "Uninstall ${DESCRIPTION}")
          # TODO: remove nats, janus and signaling-server
          :
        ;;
        "Reinstall ${DESCRIPTION}")
          # TODO: remove nats, janus and signaling-server
          :
        ;;
        *)
        ;;
    esac
else
    print_text_in_color "$ICyan" "Installing ${DESCRIPTION}..."
fi

# Install
. /etc/lsb-release
for package in nats-server nextcloud-spreed-signaling janus
do
  curl -sL -o "/etc/apt/trusted.gpg.d/morph027-${key}.asc" "https://packaging.gitlab.io/${key}/gpg.key"
done

echo "deb [arch=amd64] https://packaging.gitlab.io/nextcloud-spreed-signaling signaling main" > /etc/apt/sources.list.d/morph027-nextcloud-spreed-signaling.list
echo "deb [arch=amd64] https://packaging.gitlab.io/janus/$DISTRIB_CODENAME $DISTRIB_CODENAME main" > /etc/apt/sources.list.d/morph027-janus.list
echo "deb [arch=amd64] https://packaging.gitlab.io/nats-server nats main" > /etc/apt/sources.list.d/morph027-nats-server.list

apt update -q4 & spinner_loading
check_command apt-get install -y nextcloud-spreed-signaling nats-server janus

# Apache proxy config
# TODO: https://github.com/strukturag/nextcloud-spreed-signaling#apache

# Configuration
# TODO: create keys, setup config for janus and hpb (get turn server url from coturn app)
# https://morph027.gitlab.io/blog/nextcloud-spreed-signaling/
