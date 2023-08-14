#!/bin/bash

# T&M Hansson IT AB © - 2023, https://www.hanssonit.se/
# SwITNet Ltd © - 2023, https://switnet.net/

true
SCRIPT_NAME="Full Text Search"
SCRIPT_EXPLAINER="Full Text Search provides ElastichSearch for Nextcloud, which makes it possible to search for text inside files."
# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh

# Get all needed variables from the library
ncdb
nc_update
opensearch_install
ncdomain

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Must be root
root_check

# Nextcloud 21 is required.
lowest_compatible_nc 21

# Check if Full Text Search is already installed
if ! does_this_docker_exist nextcloud/aio-fulltextsearch && ! is_app_installed fulltextsearch
then
    # Ask for installing
    install_popup "$SCRIPT_NAME"
else
    # Ask for removal or reinstallation
    reinstall_remove_menu "$SCRIPT_NAME"
    # Reset Full Text Search to be able to index again, and also remove the app to be able to install it again
    nextcloud_occ_no_check fulltextsearch:stop
    nextcloud_occ_no_check fulltextsearch:reset
    # Drop database tables
    sudo -Hiu postgres psql "$NCDB" -c "DROP TABLE oc_fulltextsearch_ticks;"
    sudo -Hiu postgres psql "$NCDB" -c "DROP TABLE oc_fulltextsearch_index;"
    sudo -Hiu postgres psql "$NCDB" -c "DELETE FROM oc_migrations WHERE app='fulltextsearch';"
    sudo -Hiu postgres psql "$NCDB" -c "DELETE FROM oc_preferences WHERE appid='fulltextsearch';"
    APPS=(fulltextsearch fulltextsearch_elasticsearch files_fulltextsearch)
    for app in "${APPS[@]}"
    do
        if is_app_installed "$app"
        then
            nextcloud_occ app:remove "$app"
        fi
    done
    # Removal Elastichsearch Docker image
    docker_prune_this "docker.elastic.co/elasticsearch/elasticsearch"
    rm -r "$SCRIPTS"/fulltextsearch
    # Show successful uninstall if applicable
    removal_popup "$SCRIPT_NAME"
fi

# Test RAM size (4GB min) + CPUs (min 2)
ram_check 4 FullTextSearch
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

# Removal Opensearch Docker image
if does_this_docker_exist "$nc_fts" && does_this_docker_exist "$opens_fts"
then
    docker_prune_this "$nc_fts"
    docker_prune_volume "esdata"
    docker compose down "$OPNSDIR/docker-compose.yml"
    # Remove configuration files
    rm -rf "$RORDIR"
    rm -rf "$OPNSDIR"
    apt-get purge docker-compose -y
fi

# Check if the app is compatible with the current Nextcloud version
if ! install_and_enable_app fulltextsearch
then
    exit 1
fi

# Check & install docker
install_docker
set_max_count

mkdir -p "$SCRIPTS"/fulltextsearch/
cat << YML_DOCKER_COMPOSE > "$SCRIPTS/fulltextsearch/docker-compose.yaml"
version: '3'
services:
  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:8.8.1
    container_name: fulltextsearch-elasticsearch
    ports:
      - 9200:9200
      #- 9300:9300
    environment:
      - discovery.type=single-node
      - xpack.security.enabled=false
    ulimits:
      memlock:
        soft: -1
        hard: -1
      nofile:
        soft: 65536
        hard: 65536
    networks:
      - elasticsearch-network

volumes:
  elasticsearch-data:
networks:
  elasticsearch-network:
YML_DOCKER_COMPOSE

cd "$SCRIPTS"/fulltextsearch
docker compose up -d

# Check if online
until curl -sS "http://localhost:9200/_cat/health?h=status" | grep -q "green\|yellow"
do
    countdown "Waiting for ElasticSearch to come online..." "1"
done

# Already included?
# https://www.elastic.co/guide/en/elasticsearch/plugins/current/ingest-attachment.html
docker compose exec -u 0 -it fulltextsearch-elasticsearch \
    bash -c "apt-get-update; \
        export DEBIAN_FRONTEND=noninteractive; \
        apt-get install -y --no-install-recommends tzdata; \
        rm -rf /var/lib/apt/lists/*; \
        elasticsearch-plugin install --batch ingest-attachment;"

# Create custom index
curl -X PUT "http://localhost:9200/${INDEX_USER}-index" -H "Content-Type: application/json" -d

# Check logs
docker logs fulltextsearch-elasticsearch

# Check index
curl -X GET "http://localhost:9200/${INDEX_USER}-index"

sleep 10

# Get Full Text Search app for nextcloud
install_and_enable_app fulltextsearch
install_and_enable_app fulltextsearch_elasticsearch
install_and_enable_app files_fulltextsearch
chown -R www-data:www-data $NC_APPS_PATH

# Final setup
nextcloud_occ fulltextsearch:configure '{"search_platform":"OCA\\FullTextSearch_Elasticsearch\\Platform\\ElasticSearchPlatform"}'
nextcloud_occ fulltextsearch_elasticsearch:configure "{\"elastic_host\":\"http://${INDEX_USER}:${OPNSREST}@localhost:9200\",\"elastic_index\":\"${INDEX_USER}-index\"}"
nextcloud_occ files_fulltextsearch:configure "{\"files_pdf\":\"1\",\"files_office\":\"1\"}"

# Wait further for cache for index to work
countdown "Waiting for a few seconds before indexing starts..." "10"
if nextcloud_occ fulltextsearch:test
then
    if nextcloud_occ fulltextsearch:index < /dev/null
    then
        msg_box "Full Text Search was successfully installed!"
    fi
else
    msg_box "There seems to be an issue with the Full Text Search test. Please report this to $ISSUES."
fi

# Make sure the script exists
exit
