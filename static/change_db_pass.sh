#!/bin/bash
# shellcheck disable=2034,2059
true
# shellcheck source=lib.sh
NCDBPASS=1 . <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)
unset NCDBPASS

# Tech and Me © - 2018, https://www.techandme.se/

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Change PostgreSQL Password
cd /tmp
sudo -u www-data php "$NCPATH"/occ config:system:set dbpassword --value="$NEWPGPASS"

if [ "$(sudo -u postgres psql -c "ALTER USER $NCUSER WITH PASSWORD '$NEWPGPASS'";)" == "ALTER ROLE" ]
then
    echo -e "${Green}Your new PosgreSQL Nextcloud password is: $NEWPGPASS${Color_Off}"
else
    echo "Changing PostgreSQL Nextcloud password failed."
    sed -i "s|  'dbpassword' =>.*|  'dbpassword' => '$NCCONFIGDBPASS',|g" /var/www/nextcloud/config/config.php
    echo "Nothing is changed. Your old password is: $NCCONFIGDBPASS"
    exit 1
fi
