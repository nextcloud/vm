#!/bin/bash
# shellcheck disable=2034,2059
true
# shellcheck source=lib.sh
NCDBPASS=1 . <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/postgresql/lib.sh)
unset NCDBPASS

# Tech and Me © - 2017, https://www.techandme.se/

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Change PostgreSQL Password
if sudo -u postgres psql -c "ALTER USER $NCUSER WITH PASSWORD '$NEWPGPASS'"; > /dev/null 2>&1
then
    echo -e "${Green}Your new PosgreSQL Nextcloud password is: $NEWPGPASS${Color_Off}"
    sudo -u www-data php "$NCPATH"/occ config:system:set dbpassword --value="$NEWPGPASS"
else
    echo "Changing PostgreSQL Nextcloud password failed."
    echo "Nothing is changed. Your old password is: $NCCONFIGDBPASS"
    exit 1
fi
