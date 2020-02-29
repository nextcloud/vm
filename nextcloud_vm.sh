#!/bin/bash

# T&M Hansson IT AB © - 2020, https://www.hanssonit.se/

# Variables:
SCRIPTS=/var/scripts

# Todo: Test internet connection

# Todo: Verify the release package and integrity with the gpg key

# Todo: Download the release package (.tar) file

# Todo: Verify the state of the downloaded package with a checksum?

# Todo: Extract everything to "$SCRIPTS"

# This is for testing purposes only; should get removed if everything above is ready.
if [ ! -d "$SCRIPTS"/apps ] && [ ! -d "$SCRIPTS"/main ] && [ ! -d "$SCRIPTS"/lets-encrypt ] && [ ! -d "$SCRIPTS"/static ]
then
    git clone https://github.com/nextcloud/vm.git "$SCRIPTS"
    
    # Remove all unnecessary files
    rm -r "$SCRIPTS"/.git
    rm "$SCRIPTS"/LICENSE
    rm "$SCRIPTS"/issue-templace.md
    rm "$SCRIPTS"/.travis.yml
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
