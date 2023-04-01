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
    if yesno_box_yes "Do you want to remove the Imaginary docker container and settings?"
    then
        # Remove docker container
        docker_prune_this 'nextcloud/aio-imaginary'
        # reset the preview formats
        nextcloud_occ config:system:delete "preview_imaginary_url"
        nextcloud_occ config:system:delete "enabledPreviewProviders"
        nextcloud_occ config:system:delete "preview_max_x"
        nextcloud_occ config:system:delete "preview_max_y"
        nextcloud_occ config:system:delete "jpeg_quality"
        nextcloud_occ config:system:delete "preview_max_memory"
        nextcloud_occ config:system:delete "enable_previews"
        # Remove everything that is related to previewgenerator --> LEGACY
        nextcloud_occ_no_check app:remove previewgenerator
        # Reset the cronjob
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
        # Remove FFMPEG
        if is_this_installed ffmpeg && ! is_app_installed integration_whiteboard
        then
            apt-get purge ffmpeg -y
            apt-get autoremove -y
        fi
        # Remove previews
        if yesno_box_yes "Do you want to remove all previews that were generated until now?
This will most likely clear a lot of space! Also, pre-generated previews are not needed anymore once Imaginary are installed."
        then
            countdown "Removing the preview folder. This can take a while..." "5"
            rm -rfv "$NCDATA"/appdata_*/preview
            print_text_in_color "$ICyan" "Scanning Nextclouds appdata directory after removing all previews. \
This can take a while..."
            nextcloud_occ files:scan-app-data preview -vvv
            msg_box "All previews were successfully removed."
        fi
        # Remove log
        rm -f "$VMLOGS"/previewgenerator.log
        # Show successful uninstall if applicable
        removal_popup "$SCRIPT_NAME"
    fi
fi

# Install Docker
install_docker

# Pull and start
docker pull nextcloud/aio-imaginary:latest
docker run -t -d -p 127.0.0.1:9000:9000 --restart always --name imaginary nextcloud/aio-imaginary -concurrency 50 -enable-url-source -log-level debug

# Test if imaginary is working
countdown "Testing if it works in 3 sedonds" "3"
if curl -O "http://127.0.0.1:9000/crop?width=500&height=400&url=https://raw.githubusercontent.com/h2non/imaginary/master/testdata/large.jpg"
then
    print_text_in_color "$IGreen" "imaginary seems to be working OK!"
    rm -f large.jpg
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
nextcloud_occ config:system:set enabledPreviewProviders 0 --value="OC\\Preview\\Imaginary"
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
