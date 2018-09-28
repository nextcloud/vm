#!/bin/bash

# Tech and Me © - 2018, https://www.techandme.se/
# SwITNet Ltd © - 2018, https://switnet.net/

echo "Installing Elastic Search & Full Text Search on Nextcloud..."

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

# Check & install docker
apt update -q4 & spinner_loading
install_docker
set_max_count
mkdir -p "$RORDIR"
docker pull "$nc_fts"

# Create configuration YML 
cat << YML_CREATE > /opt/es/readonlyrest.yml
readonlyrest:
  access_control_rules:
  - name: Accept requests from cloud1 on $INDEX_USER-index
    groups: ["cloud1"]
    indices: ["$INDEX_USER-index"]
    
  users:
  - username: $INDEX_USER
    auth_key: $INDEX_USER:$ROREST
    groups: ["cloud1"]
YML_CREATE

# Set persmissions
chown 1000:1000 -R  $RORDIR
chmod ug+rwx -R  $RORDIR

# Run Elastic Search Docker
docker run -d --restart always \
--name $fts_es_name \
-p 9200:9200 \
-p 9300:9300 \
-v esdata:/usr/share/elasticsearch/data \
-v /opt/es/readonlyrest.yml:/usr/share/elasticsearch/config/readonlyrest.yml \
-e "discovery.type=single-node" \
-i -t $nc_fts

docker restart $fts_es_name

echo "Waiting for docker bootstraping..."
secs=$((20))
while [ $secs -gt 0 ]; do
   echo -ne "$secs\033[0K\r"
   sleep 1
   : $((secs--))
done
docker logs $fts_es_name

# Get Full Text Search app for nextcloud
install_and_enable_app fulltextsearch
install_and_enable_app fulltextsearch_elasticsearch
install_and_enable_app files_fulltextsearch
chown -R www-data:www-data $NC_APPS_PATH

# Final setup
occ_command fulltextsearch:configure '{"search_platform":"OCA\\FullTextSearch_ElasticSearch\\Platform\\ElasticSearchPlatform"}'
occ_command fulltextsearch_elasticsearch:configure "{\"elastic_host\":\"http://${INDEX_USER}:${ROREST}@localhost:9200\",\"elastic_index\":\"${INDEX_USER}-index\"}"
occ_command files_fulltextsearch:configure "{\"files_pdf\":\"1\",\"files_office\":\"1\"}"
if occ_command fulltextsearch:index < /dev/null
then
msg_box "Full Text Search was successfully installed!"
fi

exit
