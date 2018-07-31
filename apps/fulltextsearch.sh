#!/bin/bash

# Tech and Me © - 2018, https://www.techandme.se/

# shellcheck disable=2034,2059
true
# shellcheck source=lib.sh
NC_UPDATE=1 && ES_INSTALL=1 . <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)
unset NC_UPDATE
unset ES_INSTALL

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Must be root
root_check

# Nextcloud 13 is required.
lowest_compatible_nc 13

# Make sure there is an Nextcloud installation
if ! [ "$(occ_command -V)" ]
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
    occ_command app:disable nextant
    rm -rf $NC_APPS_PATH/nextant
    
    # Remove Solr
    service solr stop
    rm -rf /var/solr
    rm -rf /opt/solr*
    rm /etc/init.d/solr
    deluser --remove-home solr
    deluser --group solr
fi

#Prepare docker env
mkdir /usr/share/elasticsearch/data
docker pull ark74/nc_fts-rorest:1.6.22_es6.3.1

# Create configuration YML 
mkdir /etc/elasticsearch/

cat << YML_CREATE > /etc/elasticsearch/readonlyrest.yml
readonlyrest:


  access_control_rules:

  - name: Accept requests from cloud1 on $NCADMIN-index
    groups: ["cloud1"]
    indices: ["$NCADMIN-index"]


  users:

  - username: $NCADMIN
    auth_key: $NCADMIN:$ROREST
    groups: ["cloud1"]
YML_CREATE

# Run Elastic Search Docker
docker run -d --restart always \
--name es6.3-rorest_1.6.22 \
-p 9200:9200 \
-p 9300:9300 \
--mount source=esdata,target=/usr/share/elasticsearch/data \
-v /etc/elasticsearch/:/etc/elasticsearch/ \
-i -t ark74/nc_fts-rorest:1.6.22_es6.3.1 \
-e "discovery.type=single-node"

# Get Full Text Search app for nextcloud
install_and_enable_app fulltextsearch
install_and_enable_app fulltextsearch_elasticsearch
install_and_enable_app files_fulltextsearch
chown -R www-data:www-data $NC_APPS_PATH

# Final setup
occ_command fulltextsearch:configure '{"search_platform":"OCA\\FullTextSearch_ElasticSearch\\Platform\\ElasticSearchPlatform"}'
occ_command fulltextsearch_elasticsearch:configure "{\"elastic_host\":\"http://${NCADMIN}:${ROREST}@localhost:9200\",\"elastic_index\":\"${NCADMIN}-index\"}"
occ_command files_fulltextsearch:configure "{\"files_pdf\":\"1\",\"files_office\":\"1\"}"
occ_command fulltextsearch:index
