#!/bin/bash

# T&M Hansson IT AB © - 2020, https://www.hanssonit.se/
# SwITNet Ltd © - 2020, https://switnet.net/

# shellcheck disable=2034,2059
true
# shellcheck source=lib.sh
NCDB=1 && NC_UPDATE=1 && ES_INSTALL=1 . <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)
unset NC_UPDATE
unset ES_INSTALL
unset NCDB

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Must be root
root_check

# Nextcloud 18 is required.
lowest_compatible_nc 18

# Test RAM size (2GB min) + CPUs (min 2)
ram_check 2 FullTextSearch
cpu_check 2 FullTextSearch

# Check if fulltextsearch is already installed
print_text_in_color "$ICyan" "Checking if Fulltextsearch is already installed..."
if does_this_docker_exist "$nc_fts"
then
    choice=$(whiptail --radiolist "It seems like 'Fulltextsearch' is already installed.\nChoose what you want to do.\nSelect by pressing the spacebar and ENTER" "$WT_HEIGHT" "$WT_WIDTH" 4 \
    "Uninstall Fulltextsearch" "" OFF \
    "Reinstall Fulltextsearch" "" ON 3>&1 1>&2 2>&3)

    case "$choice" in
        "Uninstall Fulltextsearch")
            print_text_in_color "$ICyan" "Uninstalling Fulltextsearch..."
            # Reset database table
            check_command sudo -Hiu postgres psql "$NCCONFIGDB" -c "TRUNCATE TABLE oc_fulltextsearch_ticks;"
            # Reset Full Text Search to be able to index again, and also remove the app to be able to install it again
            if is_app_installed fulltextsearch
            then
                print_text_in_color "$ICyan" "Removing old version of Full Text Search and resetting the app..."
                occ_command_no_check fulltextsearch:reset
                occ_command app:remove fulltextsearch
            fi
            if is_app_installed fulltextsearch_elasticsearch
            then
                occ_command app:remove fulltextsearch_elasticsearch
            fi
            if is_app_installed files_fulltextsearch
            then
                occ_command app:remove files_fulltextsearch
            fi
            # Remove nc_fts docker if installed
            docker_prune_this "$nc_fts"

            msg_box "Fulltextsearch was successfully uninstalled."
            exit
        ;;
        "Reinstall Fulltextsearch")
            print_text_in_color "$ICyan" "Reinstalling FullTextSearch..."

            # Reset Full Text Search to be able to index again, and also remove the app to be able to install it again
            if is_app_installed fulltextsearch
            then
                print_text_in_color "$ICyan" "Removing old version of Full Text Search and resetting the app..."
                # Reset database table
                check_command sudo -Hiu postgres psql "$NCCONFIGDB" -c "TRUNCATE TABLE oc_fulltextsearch_ticks;"
                # Reset Full Text Search to be able to index again, and also remove the app to be able to install it again
                occ_command_no_check fulltextsearch:reset
                occ_command app:remove fulltextsearch
            fi
            if is_app_installed fulltextsearch_elasticsearch
            then
                occ_command app:remove fulltextsearch_elasticsearch
            fi
            if is_app_installed files_fulltextsearch
            then
                occ_command app:remove files_fulltextsearch
            fi

            # Remove nc_fts docker if installed
            docker_prune_this "$nc_fts"
        ;;
        *)
        ;;
    esac
else
    print_text_in_color "$ICyan" "Installing Fulltextsearch..."
fi

# Make sure there is an Nextcloud installation
if ! [ "$(occ_command -V)" ]
then
    msg_box "It seems there is no Nextcloud server installed, please check your installation."
    exit 1
fi

# Disable and remove Nextant + Solr
if is_app_installed nextant
then
    # Remove Nextant
    msg_box "We will now remove Nextant + Solr and replace it with Full Text Search"
    occ_command app:remove nextant

    # Remove Solr
    systemctl stop solr.service
    rm -rf /var/solr
    rm -rf /opt/solr*
    rm /etc/init.d/solr
    deluser --remove-home solr
    deluser --group solr
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
-e ES_JAVA_OPTS="-Xms512M -Xmx512M" \
-i -t $nc_fts

# Wait for bootstraping
docker restart $fts_es_name
countdown "Waiting for docker bootstraping..." "20"
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

# Make sure the script exists
exit
