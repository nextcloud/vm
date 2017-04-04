#!/bin/bash

# Tech and Me © - 2017, https://www.techandme.se/

# shellcheck disable=2034,2059
true
# shellcheck source=lib.sh
. <(curl -sL https://raw.githubusercontent.com/morph027/vm/master/lib.sh)

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Solr Server & Nextant App Installation

# Must be root
if ! is_root
then
    echo "Must be root to run script, in Ubuntu type: sudo -i"
    exit 1
fi

# Make sure there is an Nextcloud installation
if ! [ "$(sudo -u www-data php $NCPATH/occ -V)" ]
then
    echo "It seems there is no Nextcloud server installed, please check your installation."
    sleep 3
exit 1
fi

# Check if it's a clean install
if [ -d "$SOLR_HOME" ]
then
    echo
    echo "It seems like $SOLR_HOME already exists. Have you already run this script?"
    echo "If yes, revert all the settings and try again, it must be a clean install."
    exit 1
fi

echo "Starting to setup Solr & Nextant on Nextcloud..."
sleep 2

# Installing requirements
apt update -q2
apt install default-jre -y

# Getting and installing Apache Solr
echo "Installing Apache Solr"
echo "It might take some time depending on your bandwith, please be patient..."
mkdir -p "$SOLR_HOME"
cd "$SOLR_HOME" || exit 1
wget -q "$SOLR_DL" --show-progress
tar -zxf "$SOLR_RELEASE"
if "./solr-$SOLR_VERSION/bin/install_solr_service.sh" "$SOLR_RELEASE"
then
    rm -rf "${SOLR_HOME:?}/$SOLR_RELEASE"
    wget -q https://raw.githubusercontent.com/apache/lucene-solr/master/solr/bin/install_solr_service.sh -P $SCRIPTS/
else
    echo "Solr failed to install, something is wrong with the Solr installation"
    exit 1
fi

sudo sed -i '35,37  s/"jetty.host" \//"jetty.host" default="127.0.0.1" \//' $SOLR_JETTY

iptables -A INPUT -p tcp -s localhost --dport 8983 -j ACCEPT
iptables -A INPUT -p tcp --dport 8983 -j DROP
# Not tested
#sudo apt install iptables-persistent
#sudo service iptables-persistent start
#sudo iptables-save > /etc/iptables.conf

if service solr start
then
    sudo -u solr /opt/solr/bin/solr create -c nextant 
else
    echo "Solr failed to start, something is wrong with the Solr installation"
    exit 1
fi

# Add search suggestions feature
sed -i '2i <!DOCTYPE config [' "$SOLR_DSCONF"
sed -i "3i   <\!ENTITY nextant_component SYSTEM \"$NCPATH/apps/nextant/config/nextant_solrconfig.xml\"\>" "$SOLR_DSCONF"
sed -i '4i   ]>' "$SOLR_DSCONF"

sed -i '$d' "$SOLR_DSCONF" | sed -i '$d' "$SOLR_DSCONF"
echo "
&nextant_component;
</config>" | tee -a "$SOLR_DSCONF"

echo "SOLR_OPTS=\"\$SOLR_OPTS -Dsolr.allow.unsafe.resourceloading=true\"" | sudo tee -a /etc/default/solr.in.sh

if ! service solr restart
then
    echo "Solr failed to restart, something is wrong with the Solr installation"
    exit 1
fi

# Get nextant app for nextcloud
wget -q -P "$NC_APPS_PATH" "$NT_DL"
cd "$NC_APPS_PATH" || exit 1
tar zxf "$NT_RELEASE"
# Check if permission script exists, if not get it.
if [ -f $SCRIPTS/setup_secure_permissions_nextcloud.sh ]
then
    bash $SCRIPTS/setup_secure_permissions_nextcloud.sh
else
    wget -q $STATIC/setup_secure_permissions_nextcloud.sh -P $SCRIPTS
    bash $SCRIPTS/setup_secure_permissions_nextcloud.sh
fi
rm -r "$NT_RELEASE"
sudo -u www-data php $NCPATH/occ app:enable nextant
sudo -u www-data php $NCPATH/occ nextant:test http://127.0.0.1:8983/solr/ nextant --save
sudo -u www-data php $NCPATH/occ nextant:index
if [ $? -eq 0 ] # Do a while loop here instad @morph027 that checks each command individually
then
    echo "Nextant app is now installed and enabled."
    sleep 3
else
    echo "Nextant app install failed"
    sleep 3
    exit 1
fi
