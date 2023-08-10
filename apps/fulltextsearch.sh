#!/bin/bash

# T&M Hansson IT AB © - 2023, https://www.hanssonit.se/
# SwITNet Ltd © - 2023, https://switnet.net/

true
SCRIPT_NAME="Full Text Search"
SCRIPT_EXPLAINER="Full Text Search provides OpenSearch for Nextcloud, which makes it possible to search for text inside files."
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
if ! does_this_docker_exist "$nc_fts" && ! does_this_docker_exist "$opens_fts" && ! is_app_installed fulltextsearch
then
    # Ask for installing
    if [ "${CURRENTVERSION%%.*}" -ge "25" ]
    then
        msg_box "Sorry, it's not possible to install FTS anymore since Nextcloud decided to remove support for OpenSearch. Read more in this issue: https://github.com/nextcloud/fulltextsearch_elasticsearch/issues/271"
        exit 1
    fi
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
    # Removal Docker image
    docker_prune_this "$nc_fts"
    docker_prune_volume "esdata"
    docker-compose_down "$OPNSDIR/docker-compose.yml"
    # Remove configuration files
    rm -rf "$RORDIR"
    rm -rf "$OPNSDIR"
    # Show successful uninstall if applicable
    removal_popup "$SCRIPT_NAME"
    apt-get purge docker-compose -y
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

# Check if the app is compatible with the current Nextcloud version
if ! install_and_enable_app fulltextsearch
then
    exit 1
fi

# Check & install docker
install_docker
install_if_not docker-compose
set_max_count
mkdir -p "$OPNSDIR"

# Temporary solution, use AIO for now.
docker pull nextcloud/aio-fulltextsearch
docker run -t -d -p 127.0.0.1:9200 --restart always --name fulltextsearch nextcloud/aio-fulltextsearch –cap-add=sys_nice -log-level debug

# Wait for bootstrapping
if [ "$(nproc)" -gt 2 ]
then
    countdown "Waiting for Docker bootstrapping..." "60"
else
    countdown "Waiting for Docker bootstrapping..." "120"
fi

# For the future, use this in the docker. Maybe elasticsearch can be run directly?
#docker exec -it aio-fulltextsearch \
#    bash -c "cd \
#        set -ex; \
#        \
#        export DEBIAN_FRONTEND=noninteractive; \
#        apt-get update; \
#        apt-get install -y --no-install-recommends \
#        tzdata \
#        ; \
#        rm -rf /var/lib/apt/lists/*; \
#        elasticsearch-plugin install --batch ingest-attachment

docker logs aio-fulltextsearch

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
