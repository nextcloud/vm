#!/bin/bash

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

if [ $# -eq 0  ]
	then
		echo "No arguments supplied"
		exit 0
	elif [ $# -lt 4  ]; then
		echo "Wrong number of arguments supplied"
		exit 0
fi

echo "Using folder $1, and Nextcloud User $2"

DIR="$1"
NC_USER=$2
NC_PWD=$3
NC_PORT=$4

POSTGRESPATH="/etc/postgresql"
PSQLVERSION_DOCKER=13
CFG_VARS=("dbname" "dbpassword" "dbuser")
CFG_NAMES=("POSTGRES_DB" "POSTGRES_PASSWORD" "POSTGRES_USER")
CFG_NAMES_EXT=("NEXTCLOUD_ADMIN_USER" "NEXTCLOUD_ADMIN_PASSWORD")

NC_CFG_PATH="config/config.php"
PG_CFG_PATH="db/postgresql.conf"
PG_COMMENT_OUT=("data_directory" "hba_file" "ident_file" "external_pid_file" "port" "ssl" "ssl_cert_file" "ssl_key_file" "log_line_prefix" "cluster_name" "stats_temp_directory" "include_dir")  

if [ -d "$POSTGRESPATH" ] 
then
	mapfile -t test < <(find /usr -wholename '*/bin/postgres' |grep -Eo "[0-9][0-9]")
	
	PSQLVERSION=0
	for v in "${test[@]}"; do
	    if (( v > PSQLVERSION )); then PSQLVERSION=$v; fi; 
	done

	echo "Postgresql installation Version $PSQLVERSION found"
else
	echo "No postgresql installation found"
	exit 0
fi

PG_CFG="/etc/postgresql/$PSQLVERSION/main"
PG_DATA="/var/lib/postgresql/$PSQLVERSION/main"


if (( PSQLVERSION < PSQLVERSION_DOCKER )); then
	echo "Migrating database from version $PSQLVERSION to version $PSQLVERSION_DOCKER"
	
	sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
	
	echo "Adding postgresql 13 repo and installing"
	wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -

	apt-get update

	apt-get -y install postgresql-$PSQLVERSION_DOCKER -y
	
	echo "Stopping Version $PSQLVERSION_DOCKER cluster"
	pg_dropcluster 13 main --stop

	echo "Migrating old cluster"
	{
		pg_upgradecluster -m upgrade "$PSQLVERSION" main
	} ||
	{
		# could also check postgresql owner
		#USER=$(stat -c '%U' "/etc/postgresql/12/main")
		#echo $USER
		#USER=$(stat -c '%U' "/var/lib/postgresql/12/main")
		#echo $USER
		chown -R postgres:postgres "$PG_CFG"
		chown -R postgres:postgres "$PG_DATA"
		pg_upgradecluster -m upgrade "$PSQLVERSION" main
	}	
fi

echo "making new folders"
mkdir "$DIR"

echo "Copying docker-compose file"
cp docker-compose.yml "$DIR"

cd "$DIR" || exit 0
mkdir db 
mkdir config



echo "Copying database files"
cp -R /var/lib/postgresql/13/main db
cp /etc/postgresql/13/main/pg_hba.conf db
cp /etc/postgresql/13/main/pg_ident.conf db
cp /etc/postgresql/13/main/postgresql.conf db

echo "copying Nextcloud config file"
cp -R /var/www/nextcloud/config/* config



echo "Creating .env file"

for var in "${CFG_VARS[@]}"
do	
	file=$(grep "$var" < config/config.php)
	IFS=" " read -r -a line <<< "$(grep "[\"'][^\"']*[\"']" <<< "$file")"
	value=$(echo "${line[2]}"| sed -r "s/[\"',-]//gi")
	echo "${CFG_NAMES[INDEX]}=$value saved in .env file"
	echo "${CFG_NAMES[INDEX]}=$value" >> ".env"
	
	((INDEX=INDEX+1))
done

{
	echo "${CFG_NAMES_EXT[0]}=$NC_USER" 
	echo "${CFG_NAMES_EXT[1]}=$NC_PWD" 
}>> ".env"

echo "NC_PORT=${NC_PORT}" >> ".env"


file=$(grep datadirectory < config/config.php)
IFS=" " read -r -a line <<< "$(grep "[\"'][^\"']*[\"']" <<< "$file")"
ORG_DATADIR=$(echo "${line[2]}"| sed -r "s/[\"',-]//gi")
echo "NC_DATADIR=${ORG_DATADIR}" >> ".env"

echo "Patching Nextcloud configuration file"

sed -i '/memcache.distributed/s/^/#/g' $NC_CFG_PATH
sed -i '/memcache.locking/s/^/#/g' $NC_CFG_PATH

start=$(sed -n '/redis/=' $NC_CFG_PATH| head -1) 
mapfile -t ends < <(sed -n '/),/=' $NC_CFG_PATH )

for e in "${ends[@]}"
do
	if [ "$e" -gt "$start" ]; then
		end=$e
		break
	fi
done

sed -i "$start,$end s/^/#/" $NC_CFG_PATH

start=$(sed -n '/dbhost/=' $NC_CFG_PATH)
sed -i "$start s/.*/  'dbhost' => 'db',/" $NC_CFG_PATH

start=$(sed -n '/datadirectory/=' $NC_CFG_PATH)
sed -i "$start s/.*/  'datadirectory' => '\/var\/www\/html\/data',/" $NC_CFG_PATH


echo "Patching Postgresql configuration file"

for cmt in "${PG_COMMENT_OUT[@]}"
do
	sed -i "/$cmt/s/^/#/g" $PG_CFG_PATH
done

start=$(sed -n '/listen_addresses/=' $PG_CFG_PATH)
sed -i "$start s/.*/listen_addresses = '*'/" $PG_CFG_PATH

echo "Patching Postgresql HBA file"
echo "host all all all md5" >> db/pg_hba.conf

chown -R www-data:docker ./*

echo "Disabling postgresql"
systemctl disable postgresql
systemctl stop postgresql

echo "Finished"
echo "Change the 'trusted_domains' section in the config/config.php file to match your needs"
echo "Run 'docker-compose up -d' to start the Nextcloud docker container"
echo "You may have to adjust the ownership of config and db folders"
echo "Consider changing your Apache configuration"