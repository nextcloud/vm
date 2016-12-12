#!/bin/bash

# Tech and Me - www.techandme.se - ©2016
# Ubuntu 16.04 with php 7

OS=$(grep -ic "Ubuntu" /etc/issue.net)
SCRIPTS=/var/scripts
NCPATH=/var/www/nextcloud
REDIS_CONF=/etc/redis/redis.conf
REDIS_SOCK=/var/run/redis/redis.sock

# Must be root
[[ `id -u` -eq 0 ]] || { echo "Must be root to run script, in Ubuntu type: sudo -i"; exit 1; }

# Check Ubuntu version
echo "Checking server OS and version..."
if [ $OS -eq 1 ]
then
    sleep 1
else
    echo "Ubuntu Server is required to run this script."
    echo "Please install that distro and try again."
    exit 1
fi

DISTRO=$(lsb_release -sd | cut -d ' ' -f 2)
version(){
    local h t v

    [[ $2 = "$1" || $2 = "$3" ]] && return 0

    v=$(printf '%s\n' "$@" | sort -V)
    h=$(head -n1 <<<"$v")
    t=$(tail -n1 <<<"$v")

    [[ $2 != "$h" && $2 != "$t" ]]
}

if ! version 16.04 "$DISTRO" 16.04.4; then
    echo "Ubuntu version $DISTRO must be between 16.04 - 16.04.4"
    exit
fi

# Check if dir exists
if [ -d $SCRIPTS ]
then
    sleep 1
else
    mkdir -p $SCRIPTS
fi

# Get packages to be able to install Redis
apt update -q2 && sudo apt install build-essential -q -y
apt install tcl8.5 -q -y
apt install php-pear php7.0-dev -q -y

# Install PHPmodule
pecl install -Z redis
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
# Set globally doesn't work for some reason
# touch /etc/php/7.0/mods-available/redis.ini
# echo 'extension=redis.so' > /etc/php/7.0/mods-available/redis.ini
# phpenmod redis
# Setting direct to apache2 works if 'libapache2-mod-php7.0' is installed
echo 'extension=redis.so' >> /etc/php/7.0/apache2/php.ini
service apache2 restart


# Install Redis
apt install redis-server -y
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
  'memcache.local' => '\\OC\\Memcache\\Redis',
  'filelocking.enabled' => true,
  'memcache.distributed' => '\\OC\\Memcache\\Redis',
  'memcache.locking' => '\\OC\\Memcache\\Redis',
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
if grep -Fxq "vm.overcommit_memory = 1" /etc/sysctl.conf
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
apt purge -y \
    git \
    php7.0-dev* \
    build-essential*

apt update -q2
apt autoremove -y
apt autoclean

exit 0
