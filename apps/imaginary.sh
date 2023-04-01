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

# Check recources
ram_check 4
cpu_check 4

# Compatible with NC24 and above
lowest_compatible_nc 26

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
        if docker-compose_down "$SCRIPTS"/imaginary-docker/docker-compose.yml
        then
            countdown "Waiting for the Docker image to be destroyed" "5"
            nextcloud_occ config:system:delete enabledPreviewProviders
            nextcloud_occ config:system:delete preview_imaginary_url
            rm -rf "$SCRIPTS"/imaginary-docker
            docker system prune -a -f
        fi
    fi
    # Remove everything that's related to previewgenerator - it's now legacy
    nextcloud_occ app:remove previewgenerator
    # reset the preview formats
    nextcloud_occ_no_check config:system:delete "enabledPreviewProviders"
    nextcloud_occ config:system:delete preview_max_x
    nextcloud_occ config:system:delete preview_max_y
    nextcloud_occ config:system:delete jpeg_quality
    nextcloud_occ config:system:delete preview_max_memory
    nextcloud_occ config:system:delete enable_previews
    # reset the cronjob
    crontab -u www-data -l | grep -v 'preview:pre-generate'  | crontab -u www-data -
    # Remove apps
    APPS=(php-imagick libmagickcore-6.q16-3-extra imagemagick-6.q16-extra)
    for app in "${APPS[@]}"
    do
        if is_this_installed "$app"
        then
            apt-get purge "$app" -y
        fi
    done
    if is_this_installed ffmpeg && ! is_app_installed integration_whiteboard
    then
        apt-get purge ffmpeg -y
    fi
    apt-get autoremove -y
    if yesno_box_yes "Do you want to remove all previews that were generated until now?
This will most likely clear a lot of space! Also, pre-generated previews are not needed anymore once Imaginary are installed."
    then
        countdown "Removing the preview folder. This can take a while..." "5"
        rm -rfv "$NCDATA"/appdata_*/preview
        print_text_in_color "$ICyan" "Scanning Nextclouds appdata directory after removing all previews. \
This can take a while..."
        nextcloud_occ files:scan-app-data -vvv
        msg_box "All previews were successfully removed."
    fi
    # Remove log
    rm -f "$VMLOGS"/previewgenerator.log
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
countdown "Testing if it works in 3 sedonds" "3"
if curl -O "http://127.0.0.1:9000/crop?width=500&height=400&url=https://raw.githubusercontent.com/h2non/imaginary/master/testdata/large.jpg"
then
    print_text_in_color "$IGreen" "imaginary seems to be working OK!"
else
    msg_box "Test failed, please report this to: $ISSUES"
    exit
fi

# Install dependencies for Imaginary
check_php
install_if_not php"$PHPVER"-sysvsem

# Set default limits
# https://github.com/nextcloud/server/pull/18210/files#diff-3bbe91e1f85eec5dbd0031642dfb0ad6749b550fc3b94af7aa68a98210b78738R1121
nextcloud_occ config:system:set preview_concurrency_all --value="8"
nextcloud_occ config:system:set preview_concurrency_new --value="4"

# Set providers (https://github.com/nextcloud/server/blob/master/lib/private/Preview/Imaginary.php#L60)
# https://github.com/nextcloud/vm/pull/2464#discussion_r1155074227
# This is handled by Imagniary itself
nextcloud_occ config:system:set enabledPreviewProviders --value="OC\\Preview\\Imaginary"
nextcloud_occ config:system:set preview_imaginary_url --value="http://127.0.0.1:9000"

# Set general values
nextcloud_occ config:system:set preview_max_x --value="2048"
nextcloud_occ config:system:set preview_max_y --value="2048"
nextcloud_occ config:system:set jpeg_quality --value="60"
nextcloud_occ config:system:set preview_max_memory --value="256"
nextcloud_occ config:app:set preview jpeg_quality --value="60"

if docker logs imaginary
then
    msg_box "Imaginary was successfully installed!"
else
    msg_box "It seems that something is wrong. Please post the full installation output to $ISSUES"
fi
