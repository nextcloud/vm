#!/bin/bash

# Tech and Me © - 2017, https://www.techandme.se/

# shellcheck disable=2034,2059
true
# shellcheck source=lib.sh
NEXTANT_INSTALL=1 . <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)
unset NEXTANT_INSTALL

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

# Installing requirements
apt update -q4 & spinner_loading
apt install default-jre -y

# Getting and installing Apache Solr
echo "Installing Apache Solr"
echo "It might take some time depending on your bandwith, please be patient..."
mkdir -p "$SOLR_HOME"
check_command cd "$SOLR_HOME" 
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

check_command "echo \"SOLR_OPTS=\\\"\\\$SOLR_OPTS -Dsolr.allow.unsafe.resourceloading=true\\\"\" | sudo tee -a /etc/default/solr.in.sh"

check_command service solr restart

# Get nextant app for nextcloud
check_command wget -q -P "$NC_APPS_PATH" "$NT_DL"
check_command cd "$NC_APPS_PATH"
check_command tar zxf "$NT_RELEASE"

# Enable Nextant
rm -r "$NT_RELEASE"
check_command sudo -u www-data php $NCPATH/occ app:enable nextant
chown -R www-data:www-data $NCPATH/apps
check_command sudo -u www-data php $NCPATH/occ nextant:test http://127.0.0.1:8983/solr/ nextant --save
check_command sudo -u www-data php $NCPATH/occ nextant:index

