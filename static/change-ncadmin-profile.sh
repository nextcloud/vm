#!/bin/bash

UNIXUSER=ncadmin
UNIXUSER_PROFILE="/home/$UNIXUSER/.bash_profile"

rm /home/$UNIXUSER/.profile

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
    if [ -f "$HOME/.bashrc" ]
    then
        . "$HOME/.bashrc"
    fi
fi
# set PATH so it includes user's private bin if it exists
if [ -d "$HOME/bin" ]
then
    PATH="$HOME/bin:$PATH"
fi
bash /var/scripts/instruction.sh
bash /var/scripts/history.sh
sudo -i

UNIXUSER-PROFILE

exit 0
