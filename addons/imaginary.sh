#!/bin/bash

# T&M Hansson IT AB © - 2023, https://www.hanssonit.se/
# GNU General Public License v3.0
# https://github.com/nextcloud/vm/blob/master/LICENSE

true
SCRIPT_NAME="Imaginary Docker"
SCRIPT_EXPLAINER="This script will install Imaginay which is a replacement for the less secure Imagick. 
It can speedup the loading of previews in Nextcloud a lot."
# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Check if root
root_check

# Compatible with NC24 and above
lowest_compatible_nc 24

# Only applies if previewgenerator is installed
if ! is_app_installed previewgenerator
then
    msg_box "Imaginary is only needed if your use the Preview Generator app, no need to run this script."
    exit
fi

# Check if Imaginary is already installed
if ! does_this_docker_exist nextcloud/aio-imaginary
then
    # Ask for installing
    install_popup "$SCRIPT_NAME"
else
    # Ask for removal or reinstallation
    reinstall_remove_menu "$SCRIPT_NAME"
    # Removal
    if yesno_box_no "Do you want to remove all Imaginary?"
    then
        docker-compose_down "$SCRIPTS"/imaginary-docker/docker-compose.yml
        nextcloud_occ config:system:delete enabledPreviewProviders
        nextcloud_occ config:system:delete preview_imaginary_url
        rm -rf "$SCRIPTS"/imaginary-docker
    fi
    nextcloud_occ app:remove recognize
    # Show successful uninstall if applicable
    removal_popup "$SCRIPT_NAME"
fi

# Generate docker-compose.yml
mkdir -p "$SCRIPTS"/imaginary-docker
if [ ! -f "$SCRIPTS/imaginary-docker/docker-compose.yml" ]
then
    touch "$SCRIPTS/imaginary-docker/docker-compose.yml"
    cat << IMAGINARY_DOCKER_CREATE > "$SCRIPTS"/imaginary-docker/docker-compose.yml
version: '3.1'
services:
  imaginary:
    image: nextcloud/aio-imaginary:latest
    container_name: imaginary
    restart: always
    environment:
       PORT: 9000
    command: -concurrency 50 -enable-url-source -log-level debug
    ports:
      -  127.0.0.1:9000:9000
IMAGINARY_DOCKER_CREATE

    print_text_in_color "$IGreen" "SCRIPTS/imaginary-docker/docker-compose.yml was successfully created."
fi

# Start the container
docker compose -p imaginary -f "$SCRIPTS"/imaginary-docker/docker-compose.yml up -d

# Replace imagick
nextcloud_occ config:system:set enabledPreviewProviders 0 --value="OC\\Preview\\Imaginary"
nextcloud_occ config:system:set preview_imaginary_url --value="http://127.0.0.1:9000"

### Test if it's working
if curl -O "http://127.0.0.1:9000/crop?width=500&height=400&url=https://raw.githubusercontent.com/h2non/imaginary/master/testdata/large.jpg"
then
    print_text_in_color "$IGreen" "Imaginary seems to be working OK!"
else
    msg_box "Test failed, please report this to: $ISSUES"
    exit
fi

# Rebuild
nextcloud_occ files:scan-app-data
nextcloud_occ preview:generate-all --verbose

# Uninstall Preview Generator, not needed anymore (?)
# nextcloud_occ app:remove previewgenerator
