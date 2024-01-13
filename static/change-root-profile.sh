#!/bin/bash

# T&M Hansson IT AB © - 2024, https://www.hanssonit.se/

true
SCRIPT_NAME="Change root Profile"
# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

[ -f /root/.profile ] && rm -f /root/.profile

cat <<ROOT-PROFILE > "$ROOT_PROFILE"

# ~/.profile: executed by Bourne-compatible login shells.

if [ "$BASH" ]
then
    if [ -f ~/.bashrc ]
    then
        . ~/.bashrc
    fi
fi

if [ -x /var/scripts/nextcloud-startup-script.sh ]
then
    /var/scripts/nextcloud-startup-script.sh
fi

if [ -x /var/scripts/history.sh ]
then
    /var/scripts/history.sh
fi

mesg n

ROOT-PROFILE

# Add Aliases
{
echo "alias nextcloud_occ='sudo -u www-data php $NCPATH/occ'"
echo "alias update_nextcloud='bash $SCRIPTS/update.sh'"
echo "alias main_menu='bash $SCRIPTS/menu.sh'"
} > /root/.bash_aliases

