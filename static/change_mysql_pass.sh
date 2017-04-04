#!/bin/bash

. <(curl -sL https://cdn.rawgit.com/morph027/vm/color-vars/lib.sh)

# Tech and Me, ©2017 - www.techandme.se

SHUF=$(shuf -i 17-20 -n 1)
NEWMYSQLPASS=$(tr -dc "a-zA-Z0-9@#*=" < /dev/urandom | fold -w "$SHUF" | head -n 1)
PW_FILE=/var/mysql_password.txt
MYCNF=/root/.my.cnf
OLDMYSQL=$(cat $PW_FILE)

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
