#!bin/bash

# Tech and Me - www.techandme.se - ©2016
# Ubuntu 16.04 with php 7

DISTRO=$(grep -ic "Ubuntu 16.04 LTS" /etc/lsb-release)
SCRIPTS=/var/scripts
NCPATH=/var/www/nextcloud
REDIS_CONF=/etc/redis/redis.conf
REDIS_SOCK=/var/run/redis/redis.sock

# Must be root
[[ `id -u` -eq 0 ]] || { echo "Must be root to run script, in Ubuntu type: sudo -i"; exit 1; }

# Check Ubuntu version

if [ $DISTRO -eq 1 ]
then
        echo "Ubuntu 16.04 LTS OK!"
else
        echo "Ubuntu 16.04 LTS is required to run this script."
        echo "Please install that distro and try again."
        exit 1
fi

# Check if dir exists
if [ -d $SCRIPTS ];
then sleep 1
else mkdir -p $SCRIPTS
fi

# Get packages to be able to install Redis
apt-get update && sudo apt-get install build-essential -q -y
apt-get install tcl8.5 -q -y
apt-get install php-pear php7.0-dev -q -y

# Install Git and clone repo
apt-get install git -y -q
git clone -b php7 https://github.com/phpredis/phpredis.git

# Build Redis PHP module
sudo mv phpredis/ /etc/ && cd /etc/phpredis
phpize
./configure
make && make install
if [[ $? > 0 ]]
then
    echo "PHP module installation failed"
    sleep 5
    exit 1
else
		echo -e "\e[32m"
    echo "PHP module installation OK!"
    echo -e "\e[0m"
fi
touch /etc/php/7.0/mods-available/redis.ini
echo 'extension=redis.so' > /etc/php/7.0/mods-available/redis.ini
phpenmod redis
service apache2 restart
cd ..
rm -rf phpredis

# Install Redis
apt-get install redis-server -y
if [[ $? > 0 ]]
then
    echo "Installation failed."
    sleep 5
    exit 1
else
                echo -e "\e[32m"
    echo "Redis installation OK!"
    echo -e "\e[0m"
fi

# Prepare for adding redis configuration
sed -i "s|);||g" $NCPATH/config/config.php

# Add the needed config to Nextclouds config.php
cat <<ADD_TO_CONFIG>> $NCPATH/config/config.php
  'memcache.local' => '\\NC\\Memcache\\Redis',
  'filelocking.enabled' => 'true',
  'memcache.distributed' => '\\NC\\Memcache\\Redis',
  'memcache.locking' => '\\NC\\Memcache\\Redis',
  'redis' =>
  array (
  'host' => '$REDIS_SOCK',
  'port' => 0,
  'timeout' => 0,
  'dbindex' => 0,
  ),
);
ADD_TO_CONFIG

# Redis performance tweaks
if	grep -Fxq "vm.overcommit_memory = 1" /etc/sysctl.conf
then
	echo "vm.overcommit_memory correct"
else
	echo 'vm.overcommit_memory = 1' >> /etc/sysctl.conf
fi
sed -i "s|# unixsocket /var/run/redis/redis.sock|unixsocket $REDIS_SOCK|g" $REDIS_CONF
sed -i "s|# unixsocketperm 700|unixsocketperm 777|g" $REDIS_CONF
sed -i "s|port 6379|port 0|g" $REDIS_CONF
redis-cli SHUTDOWN

# Cleanup
apt-get purge -y \
	git \
	php7.0-dev* \
	build-essential*

apt-get update
apt-get autoremove -y
apt-get autoclean

exit 0
