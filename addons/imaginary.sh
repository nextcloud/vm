#!/bin/bash

# T&M Hansson IT AB © - 2023, https://www.hanssonit.se/
# GNU General Public License v3.0
# https://github.com/nextcloud/vm/blob/master/LICENSE

true
SCRIPT_NAME="Imaginary Docker"
SCRIPT_EXPLAINER="This script will install Imaginary which is a replacement for the less secure Imagick.
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
    if yesno_box_no "Do you want to remove the Imaginary docker container and settings?"
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

# Test if imaginary is working
if curl -O "http://127.0.0.1:9000/crop?width=500&height=400&url=https://raw.githubusercontent.com/h2non/imaginary/master/testdata/large.jpg"
then
    print_text_in_color "$IGreen" "imaginary seems to be working OK!"
else
    msg_box "Test failed, please report this to: $ISSUES"
    exit
fi

# Install preview generator just in case
install_and_enable_app previewgenerator

# check if the previewgenerator is installed and enabled
if is_app_enabled previewgenerator
then
    # enable previews
    nextcloud_occ config:system:set enable_previews --value=true --type=boolean

    # install needed dependency for movies
    install_if_not ffmpeg
else
    exit
fi

# Set providers
nextcloud_occ config:system:set enabledPreviewProviders 0 --value="OC\\Preview\\JPEG"
nextcloud_occ config:system:set enabledPreviewProviders 1 --value="OC\\Preview\\PNG"
nextcloud_occ config:system:set enabledPreviewProviders 2 --value="OC\\Preview\\WEBP"
nextcloud_occ config:system:set enabledPreviewProviders 3 --value="OC\\Preview\\HEIF"
nextcloud_occ config:system:set enabledPreviewProviders 4 --value="OC\\Preview\\TIFF"
nextcloud_occ config:system:set enabledPreviewProviders 5 --value="OC\\Preview\\PDF"
nextcloud_occ config:system:set enabledPreviewProviders 6 --value="OC\\Preview\\GIF"
nextcloud_occ config:system:set enabledPreviewProviders 7 --value="OC\\Preview\\SVG"
nextcloud_occ config:system:set enabledPreviewProviders 8 --value="OC\\Preview\\MP3"
nextcloud_occ config:system:set enabledPreviewProviders 9 --value="OC\\Preview\\TXT"
nextcloud_occ config:system:set enabledPreviewProviders 10 --value="OC\\Preview\\MarkDown"
nextcloud_occ config:system:set enabledPreviewProviders 11 --value="OC\\Preview\\OpenDocument"
nextcloud_occ config:system:set enabledPreviewProviders 12 --value="OC\\Preview\\Krita"
nextcloud_occ config:system:set enabledPreviewProviders 13 --value="OC\\Preview\\BMP"
nextcloud_occ config:system:set enabledPreviewProviders 14 --value="OC\\Preview\\Movie"
nextcloud_occ config:system:set enabledPreviewProviders 15 --value="OC\\Preview\\Imaginary"
nextcloud_occ config:system:set preview_imaginary_url --value="http://127.0.0.1:9000"

# Set values
nextcloud_occ config:app:set previewgenerator squareSizes --value="32 256"
nextcloud_occ config:app:set previewgenerator widthSizes  --value="256 384"
nextcloud_occ config:app:set previewgenerator heightSizes --value="256"
nextcloud_occ config:system:set preview_max_x --value="2048"
nextcloud_occ config:system:set preview_max_y --value="2048"
nextcloud_occ config:system:set jpeg_quality --value="60"
nextcloud_occ config:system:set preview_max_memory --value="128"
nextcloud_occ config:app:set preview jpeg_quality --value="60"

# Add logs
touch "$VMLOGS"/previewgenerator.log
chown www-data:www-data "$VMLOGS"/previewgenerator.log

# Rebuild
print_text_in_color "$ICyan" "Scanning Nextclouds appdata directory to rebuild all previews all previews. This will take a while..."
nextcloud_occ files:scan-app-data -vvv
nextcloud_occ preview:generate-all --verbose >> "$VMLOGS"/previewgenerator.log

# Uninstall Preview Generator, not needed anymore (?)
# nextcloud_occ app:remove previewgenerator
# reset the cronjob
# crontab -u www-data -l | grep -v 'preview:pre-generate'  | crontab -u www-data -
# rm -f "$VMLOGS"/previewgenerator.log
