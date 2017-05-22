#!/bin/bash
# shellcheck disable=2034,2059
true
# shellcheck source=lib.sh
MYCNFPW=1 . <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)
unset MYCNFPW

# Tech and Me © - 2017, https://www.techandme.se/

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Change MySQL Password
if mysqladmin -u root -p"$MYSQLMYCNFPASS" password "$NEWMYSQLPASS" > /dev/null 2>&1
then
    echo -e "${Green}Your new MySQL root password is: $NEWMYSQLPASS${Color_Off}"
    cat << LOGIN > "$MYCNF"
[client]
password='$NEWMYSQLPASS'
LOGIN
    chmod 0600 $MYCNF
    exit 0
else
    echo "Changing MySQL root password failed."
    echo "Your old password is: $MYSQLMYCNFPASS"
    exit 1
fi
