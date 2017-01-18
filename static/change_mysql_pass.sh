#!/bin/bash

# Tech and Me, ©2017 - www.techandme.se

SHUF=$(shuf -i 17-20 -n 1)
NEWMYSQLPASS=$(cat /dev/urandom | tr -dc "a-zA-Z0-9@#*=" | fold -w $SHUF | head -n 1)
PW_FILE=/var/mysql_password.txt
MYCNF=/root/.my.cnf
OLDMYSQL=$(cat $PW_FILE)

echo "Generating new MySQL root password..."
# Change MySQL password
mysqladmin -u root -p$OLDMYSQL password $NEWMYSQLPASS > /dev/null 2>&1
if [ $? -eq 0 ]
then
    echo -e "\e[32mYour new MySQL root password is: $NEWMYSQLPASS\e[0m"
    echo "$NEWMYSQLPASS" > $PW_FILE
    cat << LOGIN > "$MYCNF"
[client]
password='$NEWMYSQLPASS'
LOGIN
    chmod 0600 $MYCNF
    rm $PW_FILE
    exit 0
else
    echo "Changing MySQL root password failed."
    echo "Your old password is: $OLDMYSQL and stored in $PW_FILE"
    echo -e "\e[32m"
    read -p "Press any key to continue..." -n1 -s
    echo -e "\e[0m"
    exit 1
fi

