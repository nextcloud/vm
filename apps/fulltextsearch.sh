#!/bin/bash

# T&M Hansson IT AB © - 2024, https://www.hanssonit.se/
# SwITNet Ltd © - 2024, https://switnet.net/

true
SCRIPT_NAME="Full Text Search"
SCRIPT_EXPLAINER="Full Text Search provides ElastichSearch for Nextcloud, which makes it possible to search for text inside files."
# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh

# Get all needed variables from the library
nc_update
ncdb
fulltextsearch_install

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Must be root
root_check

# Nextcloud 26 is required.
lowest_compatible_nc 26

# Check if Full Text Search is already installed
if ! does_this_docker_exist docker.elastic.co/elasticsearch/elasticsearch && ! is_app_installed fulltextsearch
then
    # Ask for installing
    install_popup "$SCRIPT_NAME"
else
    # Ask for removal or reinstallation
    reinstall_remove_menu "$SCRIPT_NAME"
    # Remove live service
    systemctl stop "$FULLTEXTSEARCH_SERVICE"
    systemctl disable "$FULLTEXTSEARCH_SERVICE"
    rm -f "$FULLTEXTSEARCH_SERVICE"
    # Reset Full Text Search to be able to index again, and also remove the app to be able to install it again
    nextcloud_occ_no_check fulltextsearch:stop
    install_if_not expect
    REMOVE_FTS_INDEX=$(expect -c "
    set timeout 3
    spawn sudo -u www-data php $NCPATH/occ fulltextsearch:reset
    expect \"Do you really want to reset your indexed documents ? (y/N)\"
    send \"y\r\"
    expect \"Please confirm this destructive operation by typing 'reset ALL ALL':\"
    send \"reset ALL ALL\r\"
    expect eof
    ")
    echo "$REMOVE_FTS_INDEX"
    apt -y purge expect
    # Drop database tables
    sudo -Hiu postgres psql "$NCDB" -c "DROP TABLE oc_fulltextsearch_ticks;"
    sudo -Hiu postgres psql "$NCDB" -c "DROP TABLE oc_fulltextsearch_index;"
    sudo -Hiu postgres psql "$NCDB" -c "DELETE FROM oc_migrations WHERE app='fulltextsearch';"
    sudo -Hiu postgres psql "$NCDB" -c "DELETE FROM oc_preferences WHERE appid='fulltextsearch';"
    # Remove apps
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
    if docker network ls | grep "$FULLTEXTSEARCH_IMAGE_NAME"-network
    then
        docker network rm "$FULLTEXTSEARCH_IMAGE_NAME"-network
    fi
    rm -rf "$FULLTEXTSEARCH_DIR"
    # Show successful uninstall if applicable
    removal_popup "$SCRIPT_NAME"
fi

# Check if version tag is available
if [ -z "$FULLTEXTSEARCH_IMAGE_NAME_LATEST_TAG" ]
then
    msg_box "The Elasticsearch version tag is not available, please report this to $ISSUES"
    exit 1
fi

# Test RAM size (6GB min) + CPUs (min 2)
ram_check 6 FullTextSearch
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
if does_this_docker_exist "$nc_fts" || does_this_docker_exist "$opens_fts"
then
    docker_prune_this "$nc_fts"
    docker_prune_this "$opens_fts"
    docker_prune_volume "esdata"
    nextcloud_occ fulltextsearch:migration:24
    if docker network ls | grep opensearch_fts_os-net
    then
        docker network rm opensearch_fts_os-net
    fi
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

mkdir -p "$FULLTEXTSEARCH_DIR"
cat << YML_DOCKER_COMPOSE > "$FULLTEXTSEARCH_DIR/docker-compose.yaml"
services:
  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:$FULLTEXTSEARCH_IMAGE_NAME_LATEST_TAG
    container_name: $FULLTEXTSEARCH_IMAGE_NAME
    restart: always
    ports:
      - 127.0.0.1:9200:9200
    environment:
      - discovery.type=single-node
      - xpack.security.enabled=true
      - xpack.security.http.ssl.enabled=false
      - "ES_JAVA_OPTS=-Xms2g -Xmx2g"
      - ELASTIC_PASSWORD=$ELASTIC_USER_PASSWORD
    ulimits:
      memlock:
        soft: -1
        hard: -1
      nofile:
        soft: 65536
        hard: 65536
    networks:
      - $FULLTEXTSEARCH_IMAGE_NAME-network

volumes:
  $FULLTEXTSEARCH_IMAGE_NAME-data:
networks:
  $FULLTEXTSEARCH_IMAGE_NAME-network:
YML_DOCKER_COMPOSE

# Start the docker image
cd "$FULLTEXTSEARCH_DIR"
docker compose up -d

# Check if online
until curl -sS "http://elastic:$ELASTIC_USER_PASSWORD@localhost:9200/_cat/health?h=status" | grep -q "green\|yellow"
do
    countdown "Waiting for ElasticSearch to come online, please don't abort..." "10"
done

# Check logs
print_text_in_color "$ICyan" "Checking logs..."
docker logs "$FULLTEXTSEARCH_IMAGE_NAME"

countdown "Waiting a bit more before testing..." "10"

# Get Full Text Search app for nextcloud
install_and_enable_app fulltextsearch
install_and_enable_app fulltextsearch_elasticsearch
install_and_enable_app files_fulltextsearch
chown -R www-data:www-data "$NC_APPS_PATH"

# Final setup
nextcloud_occ fulltextsearch:configure '{"search_platform":"OCA\\FullTextSearch_Elasticsearch\\Platform\\ElasticSearchPlatform"}'
nextcloud_occ fulltextsearch_elasticsearch:configure "{\"elastic_host\":\"http://elastic:$ELASTIC_USER_PASSWORD@localhost:9200\",\"elastic_index\":\"${NEXTCLOUD_INDEX}\"}"
nextcloud_occ files_fulltextsearch:configure "{\"files_pdf\":\"1\",\"files_office\":\"1\"}"

# Add SystemD service for live indexing
cat << SYSTEMCTL_FTS > "/etc/systemd/system/$FULLTEXTSEARCH_SERVICE"
[Unit]
Description=Elasticsearch Worker for Nextcloud FullTextSearch
After=network.target

[Service]
User=www-data
Group=www-data
WorkingDirectory=$NCPATH
ExecStart=/usr/bin/php $NCPATH/occ fulltextsearch:live -q
ExecStop=/usr/bin/php $NCPATH/occ fulltextsearch:stop
Nice=19
Restart=always

[Install]
WantedBy=multi-user.target
SYSTEMCTL_FTS

# Wait further for cache for index to work
countdown "Waiting for a few seconds before indexing starts..." "10"
if nextcloud_occ fulltextsearch:test
then
    # Turn off swap temporarily https://www.elastic.co/guide/en/elasticsearch/reference/current/setup-configuration-memory.html
    print_text_in_color "Turning of swap temporarily..."
    swapoff -a
    if nextcloud_occ fulltextsearch:index < /dev/null
    then
        msg_box "Full Text Search was successfully installed!"
        # Enable the live service
        systemctl enable "$FULLTEXTSEARCH_SERVICE"
        systemctl start "$FULLTEXTSEARCH_SERVICE"
    fi
else
    msg_box "There seems to be an issue with the Full Text Search test. Please report this to $ISSUES."
fi

# Turn on swap again
swapon -a

# Make sure the script exists
exit
