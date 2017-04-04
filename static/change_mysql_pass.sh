#!/bin/bash
# shellcheck disable=2034,2059
true
# shellcheck source=lib.sh
. <(curl -sL https://cdn.rawgit.com/morph027/vm/master/lib.sh)

# Tech and Me, ©2017 - www.techandme.se

echo "Generating new MySQL root password..."
# Change MySQL password
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
