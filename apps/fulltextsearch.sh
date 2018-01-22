#!/bin/bash

# Tech and Me © - 2018, https://www.techandme.se/

######################## Change to MASTER before merge ###########################
############################# Developed for NC 13 ################################

# shellcheck disable=2034,2059
true
# shellcheck source=lib.sh
ES_INSTALL=1 . <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/nc13-appinstall/lib.sh)
unset ES_INSTALL

ES_VERSION=6.1.1
ES_DEB_VERSION="$(echo $ES_VERSION | head -c 1)"

######### FOR TESTING ########
GITHUB_REPO=https://raw.githubusercontent.com/nextcloud/vm/full-text-search
APP=$GITHUB_REPO/apps
##############################

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Must be root
if ! is_root
then
    msg_box "Must be root to run script, in Ubuntu type: sudo -i"
    exit 1
fi

# Make sure there is an Nextcloud installation
if ! [ "$(sudo -u www-data php $NCPATH/occ -V)" ]
then
    msg_box "It seems there is no Nextcloud server installed, please check your installation."
    exit 1
fi

# Check if it's a clean install
if [ -d /usr/share/elasticsearch ]
then
msg_box "It seems like /usr/share/elasticsearch already exists. Have you already run this script?
If yes, revert all the settings and try again, it must be a clean install."
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
echo debconf shared/accepted-oracle-license-v1-1 select true | sudo debconf-set-selections
echo debconf shared/accepted-oracle-license-v1-1 seen true | sudo debconf-set-selections
check_command apt install openjdk-8-jre -y
check_command apt install apt-transport-https -y

# Install Elastic
check_command wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo apt-key add -
check_command echo "deb https://artifacts.elastic.co/packages/$ES_DEB_VERSION.x/apt stable main" | sudo tee -a /etc/apt/sources.list.d/elastic-"$ES_DEB_VERSION".x.list
apt update -q4 & spinner_loading
apt install elasticsearch=$ES_VERSION -y
check_command /etc/init.d/elasticsearch start

# Enable on bootup
sudo systemctl enable elasticsearch.service

# Install ingest-attachment plugin
if [ -d /usr/share/elasticsearch ]
then
    cd /usr/share/elasticsearch/bin
    check_command ./elasticsearch-plugin install ingest-attachment
fi

# Check that ingest-attachment is properly installed
if ! [ "$(curl http://127.0.0.1:9300)" ]
then
msg_box "Installation failed!
Please report this to $ISSUES"
    exit 1
fi

# Install ReadOnlyREST
if [ -d /usr/share/elasticsearch ]
then
    cd /usr/share/elasticsearch/bin
    check_command ./elasticsearch-plugin install "$APP"/fulltextsearch-files/readonlyrest-1.16.15_es"$FTS_VERSION".zip
fi

# Check that ReadOnlyREST is properly installed
if ! [ "$(curl http://127.0.0.1:9300)" ]
then
msg_box "Installation failed!
Please report this to $ISSUES"
    exit 1
fi

# Check with SHA TODO

# Create YML with password TODO /etc/elasticsearch/elasticsearch.yml

# Add password and user values to FTS GUI TODO
occ_command "config:app:set --value '1' fullnextsearch app_navigation"

# Get Full Text Search app for nextcloud
install_and_enable_app fulltextsearch
chown -R www-data:www-data $NC_APPS_PATH
check_command occ_command "fulltextsearch:index"

