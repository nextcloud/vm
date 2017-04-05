#!/bin/bash

# Tech and Me © - 2017, https://www.techandme.se/
CHANGE_MYSQL=1
# shellcheck disable=2034,2059
true
# shellcheck source=lib.sh
. <(curl -sL https://raw.githubusercontent.com/morph027/vm/master/lib.sh)

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Change MySQL Password
echo "Generating new MySQL root password..."
if mysqladmin -u root -p"$OLDMYSQL" password "$NEWMYSQLPASS" > /dev/null 2>&1
then
    echo -e "${Green}Your new MySQL root password is: $NEWMYSQLPASS${Color_Off}"
    echo "$NEWMYSQLPASS" > $PW_FILE
    cat << LOGIN > "$MYCNF"
[client]
password='$NEWMYSQLPASS'
LOGIN
    chmod 0600 $MYCNF
    exit 0
else
    echo "Changing MySQL root password failed."
    echo "Your old password is: $OLDMYSQL"
    cat << LOGIN > "$MYCNF"
[client]
password='$OLDMYSQLPASS'
LOGIN
    chmod 0600 $MYCNF
    exit 1
fi
