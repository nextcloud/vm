#!/bin/bash
# shellcheck disable=2034,2059
true
# shellcheck source=lib.sh
MYCNFPW=1 . <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/postgresql/lib.sh)
unset MYCNFPW

# Tech and Me © - 2017, https://www.techandme.se/

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Change PostgreSQL Password
if sudo -u posgres psql -c "ALTER USER $NCUSER WITH PASSWORD '$NEWPGDBPASS';" > /dev/null 2>&1
then
    echo -e "${Green}Your new PosgreSQL Nextcloud password is: $NEWPGDBPASS${Color_Off}"
    sudo -u www-data php "$NCPATH"/occ config:system:set dbpassword --value="$NEWPGDBPASS"
else
    echo "Changing PostgreSQL Nextcloud password failed."
    echo "Nothing is changed."
    exit 1
fi
