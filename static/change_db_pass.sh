#!/bin/bash
true
SCRIPT_NAME="Change Database Password"
# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh

# Get all needed variables from the library
ncdb

# T&M Hansson IT AB © - 2024, https://www.hanssonit.se/

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Change PostgreSQL Password
cd /tmp
sudo -u www-data php "$NCPATH"/occ config:system:set dbpassword --value="$NEWPGPASS"

if [ "$(sudo -u postgres psql -c "ALTER USER $PGDB_USER WITH PASSWORD '$NEWPGPASS'";)" == "ALTER ROLE" ]
then
    sleep 1
else
    print_text_in_color "$IRed" "Changing PostgreSQL Nextcloud password failed."
    sed -i "s|  'dbpassword' =>.*|  'dbpassword' => '$NCDBPASS',|g" /var/www/nextcloud/config/config.php
    print_text_in_color "$IRed" "Nothing is changed. Your old password is: $NCDBPASS"
    exit 1
fi
