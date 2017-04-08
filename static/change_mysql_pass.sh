#!/bin/bash
# shellcheck disable=2034,2059
true
# shellcheck source=lib.sh
CHANGE_MYSQL=1 . <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/rewrite/lib.sh)
unset CHANGE_MYSQL

# Tech and Me © - 2017, https://www.techandme.se/

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Change MySQL Password
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
