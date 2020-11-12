#!/bin/bash

# T&M Hansson IT AB © - 2020, https://www.hanssonit.se/
# SwITNet Ltd © - 2020, https://switnet.net/

true
SCRIPT_NAME="Full Text Search"
SCRIPT_EXPLAINER="Full Text Search provides Elasticsearch for Nextcloud, which makes it possible to search for text inside files."
# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh || source <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)

# Get all needed variables from the library
ncdb
nc_update
es_install

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Must be root
root_check

# Nextcloud 18 is required.
lowest_compatible_nc 18

# Check if Full Text Search is already installed
if ! does_this_docker_exist "$nc_fts" || ! is_app_installed fulltextsearch
then
    # Ask for installing
    install_popup "$SCRIPT_NAME"
else
    # Ask for removal or reinstallation
    reinstall_remove_menu "$SCRIPT_NAME"
    # Reset database table
    check_command sudo -Hiu postgres psql "$NCCONFIGDB" -c "TRUNCATE TABLE oc_fulltextsearch_ticks;"
    # Reset Full Text Search to be able to index again, and also remove the app to be able to install it again
    nextcloud_occ_no_check fulltextsearch:reset
    APPS=(fulltextsearch fulltextsearch_elasticsearch files_fulltextsearch)
    for app in "${APPS[@]}"
    do
        if is_app_installed "$app"
        then
            nextcloud_occ app:remove "$app"
        fi
    done
    # Removal Docker image
    docker_prune_this "$nc_fts"
    # Show successful uninstall if applicable
    removal_popup "$SCRIPT_NAME"
fi

# Test RAM size (2GB min) + CPUs (min 2)
ram_check 3 FullTextSearch
cpu_check 2 FullTextSearch

# Make sure there is an Nextcloud installation
if ! [ "$(nextcloud_occ -V)" ]
then
    msg_box "It seems there is no Nextcloud server installed, please check your installation."
    exit 1
fi

# Disable and remove Nextant + Solr
if is_app_installed nextant
then
    # Remove Nextant
    msg_box "We will now remove Nextant + Solr and replace it with Full Text Search"
    nextcloud_occ app:remove nextant

    # Remove Solr
    systemctl stop solr.service
    rm -rf /var/solr
    rm -rf /opt/solr*
    rm /etc/init.d/solr
    deluser --remove-home solr
    deluser --group solr
fi

# Check if the app is compatible with the current Nextcloud version
if ! install_and_enable_app fulltextsearch
then
    exit 1
fi

# Check & install docker
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
--ulimit memlock=-1:-1 \
--ulimit nofile=65536:65536 \
-p 127.0.0.1:9200:9200 \
-p 127.0.0.1:9300:9300 \
-v esdata:/usr/share/elasticsearch/data \
-v /opt/es/readonlyrest.yml:/usr/share/elasticsearch/config/readonlyrest.yml \
-e "discovery.type=single-node" \
-e "bootstrap.memory_lock=true" \
-e ES_JAVA_OPTS="-Xms1024M -Xmx1024M" \
-i -t $nc_fts

# Wait for bootstraping
docker restart $fts_es_name
if [ "$(nproc)" -gt 2 ]
then
    countdown "Waiting for Docker bootstraping..." "30"
else
    countdown "Waiting for Docker bootstraping..." "120"
fi
docker logs $fts_es_name

# Get Full Text Search app for nextcloud
install_and_enable_app fulltextsearch
install_and_enable_app fulltextsearch_elasticsearch
install_and_enable_app files_fulltextsearch
chown -R www-data:www-data $NC_APPS_PATH

# Final setup
nextcloud_occ fulltextsearch:configure '{"search_platform":"OCA\\FullTextSearch_ElasticSearch\\Platform\\ElasticSearchPlatform"}'
nextcloud_occ fulltextsearch_elasticsearch:configure "{\"elastic_host\":\"http://${INDEX_USER}:${ROREST}@localhost:9200\",\"elastic_index\":\"${INDEX_USER}-index\"}"
nextcloud_occ files_fulltextsearch:configure "{\"files_pdf\":\"1\",\"files_office\":\"1\"}"
if nextcloud_occ fulltextsearch:index < /dev/null
then
    msg_box "Full Text Search was successfully installed!"
fi

# Make sure the script exists
exit
