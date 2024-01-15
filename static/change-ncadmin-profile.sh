#!/bin/bash

# T&M Hansson IT AB © - 2024, https://www.hanssonit.se/

true
SCRIPT_NAME="Change ncadmin Profile"
# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

rm "/home/$UNIXUSER/.profile"

cat <<-UNIXUSER-PROFILE > "$UNIXUSER_PROFILE"
# ~/.profile: executed by the command interpreter for login shells.
# This file is not read by bash(1), if ~/.bash_profile or ~/.bash_login
# exists.
# see /usr/share/doc/bash/examples/startup-files for examples.
# the files are located in the bash-doc package.
# the default umask is set in /etc/profile; for setting the umask
# for ssh logins, install and configure the libpam-umask package.
#umask 022
# if running bash
if [ -n "$BASH_VERSION" ]
then
    # include .bashrc if it exists
    if [ -f "/home/$UNIXUSER/.bashrc" ]
    then
        . "/home/$UNIXUSER/.bashrc"
    fi
fi
# set PATH so it includes user's private bin if it exists
if [ -d "/home/$UNIXUSER/bin" ]
then
    PATH="/home/$UNIXUSER/bin:$PATH"
fi
bash /var/scripts/instruction.sh
# clear .bash_history by default as a security precaution
bash /var/scripts/history.sh
sudo -i

UNIXUSER-PROFILE

chown "$UNIXUSER:$UNIXUSER" "$UNIXUSER_PROFILE"
chown "$UNIXUSER:$UNIXUSER" "$SCRIPTS/history.sh"
chown "$UNIXUSER:$UNIXUSER" "$SCRIPTS/instruction.sh"

exit 0
