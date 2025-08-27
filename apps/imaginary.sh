#!/bin/bash

# T&M Hansson IT AB © - 2024, https://www.hanssonit.se/
# GNU General Public License v3.0
# https://github.com/nextcloud/vm/blob/main/LICENSE

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
# If we can calculate the cpu and ram, then set it to the lowest possible, if not, then hardcode it to a recomended minimum.
if which nproc >/dev/null 2>&1
then
    ram_check 2 Imaginary
    cpu_check 2 Imaginary
else
    ram_check 4 Imaginary
    cpu_check 2 Imaginary
fi

# Compatible with NC24 and above
lowest_compatible_nc 26

# Check if Imaginary is already installed
if ! does_this_docker_exist nextcloud/aio-imaginary && ! does_this_docker_exist ghcr.io/nextcloud-releases/aio-imaginary
then
    # Ask for installing
    install_popup "$SCRIPT_NAME"
else
    # Ask for removal or reinstallation
    reinstall_remove_menu "$SCRIPT_NAME"
    # Removal
    if yesno_box_yes "Do you want to remove the Imaginary and all it's settings?"
    then
        # Remove docker container
        docker_prune_this 'nextcloud/aio-imaginary' 'imaginary'
        docker_prune_this 'ghcr.io/nextcloud-releases/aio-imaginary' 'imaginary'
        # reset the preview formats
        nextcloud_occ config:system:delete "preview_imaginary_url"
        nextcloud_occ config:system:delete "enabledPreviewProviders"
        nextcloud_occ config:system:delete "preview_max_x"
        nextcloud_occ config:system:delete "preview_max_y"
        nextcloud_occ config:system:delete "jpeg_quality"
        nextcloud_occ config:system:delete "preview_max_memory"
        nextcloud_occ config:system:delete "enable_previews"
        nextcloud_occ config:system:delete "preview_concurrency_new"
        nextcloud_occ config:system:delete "preview_concurrency_all"
        # Remove FFMPEG
        if is_this_installed ffmpeg && ! is_app_installed integration_whiteboard
        then
            apt-get purge ffmpeg -y
            apt-get autoremove -y
        fi
        # Show successful uninstall if applicable
        removal_popup "$SCRIPT_NAME"
    fi
fi

# Remove everything that is related to previewgenerator
if crontab -u www-data -l | grep -q "preview:pre-generate"
then
    if yesno_box_yes "We noticed that you have Preview Generator enabled. Imagniary replaces this, and the old app Preview Generator is now legacy.\nWe recommend you to remove it. Do you want to do that?"
    then
        # Remove the app
        nextcloud_occ_no_check app:remove previewgenerator
        # Remove the cronjob
        crontab -u www-data -l | grep -v 'preview:pre-generate'  | crontab -u www-data -
        # Remove dependecies
        DEPENDENCY=(php-imagick php"$PHPVER"-imagick libmagickcore-6.q16-3-extra imagemagick-6.q16-extra)
        for installeddependency in "${DEPENDENCY[@]}"
        do
            if is_this_installed "$installeddependency"
            then
                # --allow-change-held-packages in case running on Ondrejs PPA and it's held
                apt-get purge "$installeddependency" -y --allow-change-held-packages
            fi
        done
        # Remove custom config
        rm -rf /etc/ImageMagick-6
        # Remove previews
        if yesno_box_yes "Do you want to remove all previews that were generated until now?
This will most likely clear a lot of space! Also, pre-generated previews are not needed anymore once Imaginary are installed."
        then
            countdown "Removing the preview folder. This can take a while..." "5"
            rm -rfv "$NCDATA"/appdata_*/preview/*
            print_text_in_color "$ICyan" "Scanning Nextclouds appdata directory after removing all previews. \
This can take a while..."
            # Don't execute the update before all cronjobs are finished
            check_running_cronjobs
            nextcloud_occ files:scan-app-data preview -vvv
            print_text_in_color "$IGreen" "All previews were successfully removed."
        fi
        # Remove log
        rm -f "$VMLOGS"/previewgenerator.log
    fi
fi
# Install Docker
install_docker

# Pull and start
docker pull ghcr.io/nextcloud-releases/aio-imaginary:latest
docker run -t -d -p 127.0.0.1:9000:9000 --restart always --name imaginary ghcr.io/nextcloud-releases/aio-imaginary –cap-add=sys_nice -concurrency 50 -enable-url-source -return-size -log-level debug

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

# Install dependencies
check_php
install_if_not php"$PHPVER"-sysvsem
install_if_not ffmpeg

# Calculate CPU cores
# https://docs.nextcloud.com/server/latest/admin_manual/configuration_server/config_sample_php_parameters.html#previews
if which nproc >/dev/null 2>&1
then
    nextcloud_occ config:system:set preview_concurrency_new --value="$(nproc)"
    nextcloud_occ config:system:set preview_concurrency_all --value="$(("$(nproc)"*2))"
else
    nextcloud_occ config:system:set preview_concurrency_new --value="2"
    nextcloud_occ config:system:set preview_concurrency_all --value="4"
fi

# Set providers (https://github.com/nextcloud/server/blob/master/lib/private/Preview/Imaginary.php#L60)
# https://github.com/nextcloud/vm/issues/2465
# Already enabled: https://github.com/nextcloud/server/blob/5e96228eb1f7999a327dacab22055ec2aa8e28a3/lib/private/Preview/Imaginary.php#L60
nextcloud_occ config:system:set enabledPreviewProviders 0 --value="OC\\Preview\\Imaginary"
nextcloud_occ config:system:set enabledPreviewProviders 1 --value="OC\\Preview\\Image"
nextcloud_occ config:system:set enabledPreviewProviders 2 --value="OC\\Preview\\MarkDown"
nextcloud_occ config:system:set enabledPreviewProviders 3 --value="OC\\Preview\\MP3"
nextcloud_occ config:system:set enabledPreviewProviders 4 --value="OC\\Preview\\TXT"
nextcloud_occ config:system:set enabledPreviewProviders 5 --value="OC\\Preview\\OpenDocument"
nextcloud_occ config:system:set enabledPreviewProviders 6 --value="OC\\Preview\\Movie"
nextcloud_occ config:system:set enabledPreviewProviders 7 --value="OC\\Preview\\Krita"
nextcloud_occ config:system:set enabledPreviewProviders 8 --value="OC\Preview\ImaginaryPDF"
nextcloud_occ config:system:set preview_imaginary_url --value="http://127.0.0.1:9000"

# Set general values
nextcloud_occ config:system:set preview_max_x --value="2048"
nextcloud_occ config:system:set preview_max_y --value="2048"
nextcloud_occ config:system:set preview_max_memory --value="256"
nextcloud_occ config:system:set preview_format --value="webp"
nextcloud_occ config:app:set preview webp_quality --value="65"

if docker logs imaginary
then
    msg_box "Imaginary was successfully installed!"
else
    msg_box "It seems that something is wrong. Please post the full installation output to $ISSUES"
fi
