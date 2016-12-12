#!/bin/bash

# Tech and Me, ©2016 - www.techandme.se

SHUF=$(shuf -i 17-20 -n 1)
NEWMYSQLPASS=$(cat /dev/urandom | tr -dc "a-zA-Z0-9@#*=" | fold -w $SHUF | head -n 1)
PW_FILE=/var/mysql_password.txt
OLDMYSQL=$(cat $PW_FILE)

echo "Generating new MySQL root password..."
# Change MySQL password
mysqladmin -u root -p$OLDMYSQL password $NEWMYSQLPASS > /dev/null 2>&1
if [ $? -eq 0 ]
then
    echo -e "\e[32mYour new MySQL root password is: $NEWMYSQLPASS\e[0m"
    echo "$NEWMYSQLPASS" > $PW_FILE
else
    echo "Changing MySQL root password failed."
    echo "Your old password is: $OLDMYSQL"
fi
sleep 1

exit 0

