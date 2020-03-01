#!/bin/bash

# T&M Hansson IT AB © - 2020, https://www.hanssonit.se/

# Variables:
SCRIPTS=/var/scripts

# Check if root
if [[ "$EUID" -ne 0 ]]
then
    echo "You have to run this script as root! Exiting..."
    exit 1
fi

# Test internet connection
ping -c1 -W1 -q github.com &>/dev/null
status=$( echo $? )
if [[ $status != 0 ]]
then
    echo "Couldn't reach github.com. Exiting..."
    exit 1
fi

# Todo: Verify the release package and integrity with the gpg key

# Todo: Download the release package (.tar) file

# Todo: Verify the state of the downloaded package with a checksum?

# Todo: Extract everything to "$SCRIPTS"
mkdir -p "$SCRIPTS"

# This is for testing purposes only; should get removed if everything above is ready.
if [ ! -d "$SCRIPTS"/apps ] && [ ! -d "$SCRIPTS"/main ] && [ ! -d "$SCRIPTS"/lets-encrypt ] && [ ! -d "$SCRIPTS"/static ]
then
    git clone -b testing --single-branch https://github.com/nextcloud/vm.git "$SCRIPTS"
    # Remove all unnecessary files
    rm -r "$SCRIPTS"/.git
    rm "$SCRIPTS"/LICENSE
    rm "$SCRIPTS"/issue_template.md
    rm "$SCRIPTS"/.travis.yml
    rm "$SCRIPTS"/README.md
    rm "$SCRIPTS"/nextcloud_vm.sh
fi

# Move all main files to "$SCRIPTS"/main (apart from install-production and startup-script)
mkdir -p "$SCRIPTS"/main
mv "$SCRIPTS"/lib.sh "$SCRIPTS"/main 
mv "$SCRIPTS"/nextcloud_update.sh "$SCRIPTS"/main

# Set ownership and permission
chown -R root:root "$SCRIPTS"
chmod -R +x "$SCRIPTS"

# Run the nextcloud_install_production script
bash "$SCRIPTS"/nextcloud_install_production.sh

exit
