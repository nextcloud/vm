#!/bin/bash

# T&M Hansson IT AB © - 2021, https://www.hanssonit.se/
# SwITNet Ltd © - 2021, https://switnet.net/

true
SCRIPT_NAME="Full Text Search"
SCRIPT_EXPLAINER="Full Text Search provides Elasticsearch for Nextcloud, which makes it possible to search for text inside files."
# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh || source <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)

# Get all needed variables from the library
ncdb
nc_update
opensearch_install

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
if ! does_this_docker_exist "$opens_fts" || ! is_app_installed fulltextsearch
then
    # Ask for installing
    install_popup "$SCRIPT_NAME"
    NCDOMAIN=$(nextcloud_occ_no_check config:system:get overwrite.cli.url | sed 's|https://||;s|/||')
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
    docker_prune_this "$opens_fts"
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

# Check if the app is compatible with the current Nextcloud version
if ! install_and_enable_app fulltextsearch
then
    exit 1
fi

# Check & install docker
install_docker
install_docker_compose
set_max_count
mkdir -p "$OPNSDIR"
docker pull "$opens_fts"
BCRYPT_HASH=`docker run -it $opens_fts \
       bash -c "plugins/opensearch-security/tools/hash.sh -p $OPNSREST"`

# Create configurations YML
# opensearch.yml
cat << YML_OPENSEARCH > $OPNSDIR/opensearch.yml
cluster.name: docker-cluster
# Avoid Docker assigning IP.
network.host: 0.0.0.0

# Declaring single node cluster.
discovery.type: single-node

######## Start Security Configuration ########
plugins.security.ssl.transport.pemcert_filepath: node.pem
plugins.security.ssl.transport.pemkey_filepath: node-key.pem
plugins.security.ssl.transport.pemtrustedcas_filepath: root-ca.pem
plugins.security.ssl.transport.enforce_hostname_verification: false

#Disable ssl at REST as Fulltextsearch can't accept self-signed CA certs.
plugins.security.ssl.http.enabled: false
#plugins.security.ssl.http.pemcert_filepath: node.pem
#plugins.security.ssl.http.pemkey_filepath: node-key.pem
#plugins.security.ssl.http.pemtrustedcas_filepath: root-ca.pem
plugins.security.allow_unsafe_democertificates: false
plugins.security.allow_default_init_securityindex: true
plugins.security.authcz.admin_dn:
  - 'CN=ADMIN,OU=FTS,O=OPENSEARCH,L=VM,ST=NEXTCLOUD,C=CA'
plugins.security.nodes_dn:
  - 'CN=${NCDOMAIN},OU=FTS,O=OPENSEARCH,L=VM,ST=NEXTCLOUD,C=CA'

plugins.security.audit.type: internal_opensearch
plugins.security.enable_snapshot_restore_privilege: true
plugins.security.check_snapshot_restore_write_privileges: true
plugins.security.restapi.roles_enabled: ["all_access", "security_rest_api_access"]
plugins.security.system_indices.enabled: true
plugins.security.system_indices.indices: [".opendistro-alerting-config", ".opendistro-alerting-alert*", ".opendistro-anomaly-results*", ".opendistro-anomaly-detector*", ".opendistro-anomaly-checkpoints", ".opendistro-anomaly-detection-state", ".opendistro-reports-*", ".opendistro-notifications-*", ".opendistro-notebooks", ".opensearch-observability", ".opendistro-asynchronous-search-response*", ".replication-metadata-store"]
node.max_local_storage_nodes: 1
######## End Security Configuration ########
YML_OPENSEARCH

cat << YML_INTERNAL_USERS > $OPNSDIR/internal_users.yml.yml
_meta:
  type: "internalusers"
  config_version: 2
  
${INDEX_USER}:
  hash: "${BCRYPT_HASH}"
  reserved: true
  backend_roles:
  - "admin"
  description: "admin user for fts at opensearch."
YML_INTERNAL_USERS

cat << YML_ROLES_MAPPING > $OPNSDIR/roles_mapping.yml
_meta:
  type: "rolesmapping"
  config_version: 2

# Roles mapping
all_access:
  reserved: false
  backend_roles:
  - "admin"
  description: "Maps admin to all_access"
YML_ROLES_MAPPING

# Prepare certs
create_certs opensearch_certs.sh

# Set permissions
chown 1000:1000 -R  $OPNSDIR
chmod ug+rwx -R  $OPNSDIR

# Launch docker-compose
cd $OPNSDIR
docker-compose up -d

# Wait for bootstrapping
docker restart $fts_node
if [ "$(nproc)" -gt 2 ]
then
    countdown "Waiting for Docker bootstrapping..." "30"
else
    countdown "Waiting for Docker bootstrapping..." "120"
fi
docker logs $fts_node

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
if nextcloud_occ fulltextsearch:index < /dev/null
then
    msg_box "Full Text Search was successfully installed!"
fi

# Make sure the script exists
exit
