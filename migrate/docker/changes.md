//create folders
mkdir nc && cd nc
mkdir db
mkdir config


//if you are running postgresql < v13, upgrade the cluster to v13

sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'

wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -

sudo apt-get update

sudo apt-get -y install postgresql-13

sudo pg_dropcluster 13 main --stop

sudo pg_upgradecluster -m upgrade 12 main

//copy db files

cp -r /var/lib/postgresql/13/main db
cp /etc/postgresql/13/main/pg_hba.conf db
cp /etc/postgresql/13/main/pg_ident.conf db
cp /etc/postgresql/13/main/postgresql.conf db

//patch postgres config file
patch db/postgresql.conf postgres.patch

//add authorization to pg-hba.conf file
echo "host all all all md5" >> db/pg_hba.conf

//copy nc config 
cp -R /var/www/nextcloud/config/* config

/*copy configuration data in thes files: 
  nextcloud_admin_password.txt # put admin password to this file
  nextcloud_admin_user.txt # put admin username to this file
  postgres_db.txt # put postgresql db name to this file
  postgres_password.txt # put postgresql password to this file
  postgres_user.txt # put postgresql username to this file
*/

//patch nc config
patch config/config.php config.patch

//change config directory ownership if not already the case (tofind out the needed id: docker exec -it nc id www-data)
chown -R www-data:www-data *

docker-compose up -d

// /usr/bin/sed -i  "/);/i 'installed' => true" /var/www/html/config/config.php