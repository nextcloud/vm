#!/bin/bash

# Tech and Me, ©2016 - www.techandme.se

# Based on: http://www.techrepublic.com/blog/smb-technologist/secure-your-apache-server-from-ddos-slowloris-and-dns-injection-attacks/

SPAMHAUS=/etc/spamhaus.wl
ENVASIVE=/etc/apache2/mods-available/mod-evasive.load
APACHE2=/etc/apache2/apache2.conf

set -e

# Protect against DDOS
apt-get -y install libapache2-mod-evasive
mkdir -p /var/log/apache2/evasive
chown -R www-data:root /var/log/apache2/evasive
if [ -f $ENVASIVE ];
then
        echo "Envasive mod exists"
else
	touch $ENVASIVE
        cat << ENVASIVE > "$ENVASIVE"
DOSHashTableSize 2048
DOSPageCount 20  # maximum number of requests for the same page
DOSSiteCount 300  # total number of requests for any object by the same client IP on the same listener
DOSPageInterval 1.0 # interval for the page count threshold
DOSSiteInterval 1.0  # interval for the site count threshold
DOSBlockingPeriod 10.0 # time that a client IP will be blocked for
DOSLogDir
ENVASIVE
fi

# Protect against Slowloris
apt-get -y install libapache2-mod-qos

# Protect against DNS Injection
apt-get -y install libapache2-mod-spamhaus
if [ -f $SPAMHAUS ];
then
        echo "Spamhaus mod exists"
else
	touch $SPAMHAUS
        cat << SPAMHAUS >> "$APACHE2"

# Spamhaus module
<IfModule mod_spamhaus.c>
  MS_METHODS POST,PUT,OPTIONS,CONNECT
  MS_WhiteList /etc/spamhaus.wl
  MS_CacheSize 256
</IfModule>
SPAMHAUS
fi

if [ -f $SPAMHAUS ];
then
        echo "Adding Whitelist IP-ranges..."
        cat << SPAMHAUSconf >> "$SPAMHAUS"

# Whitelisted IP-ranges
192.168.0.0/16
172.16.0.0/12
10.0.0.0/8
SPAMHAUSconf
else
        echo "No file exists, so not adding anything to whitelist"
fi

# Enable $SPAMHAUS
sed -i "s|#MS_WhiteList /etc/spamhaus.wl|MS_WhiteList $SPAMHAUS|g" /etc/apache2/mods-enabled/spamhaus.conf

service apache2 restart
if [[ $? -gt 0 ]]
then
        echo "Something went wrong..."
        sleep 5
        exit 1
else
	echo "Security added!"
fi
