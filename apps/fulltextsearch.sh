#!/bin/bash

# Tech and Me © - 2018, https://www.techandme.se/

######################## Change to MASTER before merge ###########################
############################# Developed for NC 13 ################################

# shellcheck disable=2034,2059
true
# shellcheck source=lib.sh
FTS_INSTALL=1 . <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/nc13-appinstall/lib.sh)
unset FTS_INSTALL

FTS_VERSION=6.1.1
FTS_DEB_VERSION="$(echo $FTS_VERSION | head -c 3)"

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

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
if [ -d /usr/share/elasticsearch ]
then
    echo
    echo "It seems like /usr/share/elasticsearch already exists. Have you already run this script?"
    echo "If yes, revert all the settings and try again, it must be a clean install."
    exit 1
fi

echo "Starting to setup Elastic Search & Full Text Search on Nextcloud..."
apt update -q4 & spinner_loading

# Disable and remove Nextant + Solr
if [ -d "$NC_APPS_PATH"/nextant ]
then
    # Remove Nextant
    msg_box "We will now remove Nextant + Solr and replace it with Full Text Search"
    occ_command app:disbale nextant
    rm -rf $NC_APPS_PATH/nextant
    
    # Remove Solr
    service solr stop
    rm -rf /var/solr
    rm -rf /opt/solr*
    rm /etc/init.d/solr
    deluser --remove-home solr
    deluser --group solr
fi

# Installing requirements
check_command apt install openjdk-8-jre -y
check_command apt install apt-transport-https -y

# Install Elastic
check_command wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo apt-key add -
check_command echo "deb https://artifacts.elastic.co/packages/$FTS_DEB_VERSION/apt stable main" | sudo tee -a /etc/apt/sources.list.d/elastic-$FTS_DEB_VERSION.list
apt update -q4 & spinner_loading
apt install elasticsearch -y
check_command /etc/init.d/elasticsearch start
check_command /etc/init.d/elasticsearch stop
check_command /etc/init.d/elasticsearch restart
if ! [ "$(curl http://127.0.0.1:9200)" ]
then
msg_box "Installation failed!

Please report this to $ISSUES"
    exit 1
fi

# Install ingest-attachment plugin
if [ -d /usr/share/elasticsearch ]
then
    cd /usr/share/elasticsearch/bin
    check_command ./elasticsearch-plugin install ingest-attachment
fi

# Install ReadOnlyREST
if [ -d /usr/share/elasticsearch ]
then
    cd /usr/share/elasticsearch/bin
    check_command ./elasticsearch-plugin install file://"$GITHUB_REPO"/"$APPS"/fulltextsearch-files/readonlyrest-1.16.15_es"$FTS_VERSION".zip
fi

# Check with SHA TODO

# Create YML with password TODO

# Add password and user values to FTS GUI TODO
occ_command "config:app:set --value '1' fullnextsearch app_navigation"

# Get Full Text Search app for nextcloud
install_and_enable_app fulltextsearch
chown -R www-data:www-data $NC_APPS_PATH
check_command occ_command "fulltextsearch:index"

