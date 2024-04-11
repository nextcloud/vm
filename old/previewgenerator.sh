#!/bin/bash

# T&M Hansson IT AB © - 2024, https://www.hanssonit.se/

true
SCRIPT_NAME="Preview Generator"
SCRIPT_EXPLAINER="This script will install the Preview Generator. 
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

# PHP 7.x is needed
if is_this_installed php5.6-common || is_this_installed php5.5-common
then
    msg_box "At least PHP 7.X is required, please upgrade your PHP version: \
https://shop.hanssonit.se/product/upgrade-php-version-including-dependencies/"
    exit
fi

# Encryption may not be enabled
if is_app_enabled encryption || is_app_enabled end_to_end_encryption
then
    msg_box "It seems like you have encryption enabled which is unsupported when using the Preview Generator"
    exit
fi

# Check if previewgenerator is already installed
if ! is_app_installed previewgenerator
then
    # Ask for installing
    install_popup "$SCRIPT_NAME"
else
    # Ask for removal or reinstallation
    reinstall_remove_menu "$SCRIPT_NAME"
    # Removal
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
    rm -rf /etc/ImageMagick-6
    if yesno_box_no "Do you want to remove all previews that were generated until now?
This will most likely clear a lot of space but your server will need to re-generate the previews \
if you should opt to re-enable previews again."
    then
        countdown "Removing the preview folder. This can take a while..." "5"
        rm -rfv "$NCDATA"/appdata_*/preview
        print_text_in_color "$ICyan" "Scanning Nextclouds appdata directory after removing all previews. \
This can take a while..."
        nextcloud_occ files:scan-app-data -vvv
        msg_box "All previews were successfully removed."
    fi
    # Show successful uninstall if applicable
    removal_popup "$SCRIPT_NAME"
fi

# Install preview generator
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

msg_box "In the next step you can choose to install a package called imagick \
to speed up the generation of previews and add support for more filetypes.

The currently supported filetypes are:
* PNG
* JPEG
* GIF
* BMP
* MarkDown
* MP3
* TXT
* Movie
* Photoshop (needs imagick)
* SVG (needs imagick)
* TIFF (needs imagick)"

msg_box "IMPORTANT NOTE!!

Imagick will put your server at risk as it's is known to have several flaws.
You can check this issue to understand why: https://github.com/nextcloud/vm/issues/743

Please note: If you choose not to install imagick, it will get removed now."
if yesno_box_no "Do you want to install imagick?"
then
    check_php
    # Install imagick
    install_if_not php"$PHPVER"-imagick
    if version 24.04 "$DISTRO" 24.04.10
    then
        install_if_not libmagickcore-6.q16-6-extra
    elif version 22.04 "$DISTRO" 22.04.10
    then
        install_if_not libmagickcore-6.q16-3-extra
    fi
    # Memory tuning
    sed -i 's|policy domain="resource" name="memory" value=.*|policy domain="resource" name="memory" value="512MiB"|g' /etc/ImageMagick-6/policy.xml
    sed -i 's|policy domain="resource" name="map" value=.*|policy domain="resource" name="map" value="1024MiB"|g' /etc/ImageMagick-6/policy.xml
    sed -i 's|policy domain="resource" name="area" value=.*|policy domain="resource" name="area" value="256MiB"|g' /etc/ImageMagick-6/policy.xml
    sed -i 's|policy domain="resource" name="disk" value=.*|policy domain="resource" name="disk" value="8GiB"|g' /etc/ImageMagick-6/policy.xml
    
    # Choose file formats fo the case when imagick is installed.
    # for additional previews please look at the Nextcloud documentation. But these probably won't work.
    choice=$(whiptail --title "$TITLE - Choose file formats" --checklist \
"Now you can choose for which file formats you would like to generate previews for
$CHECKLIST_GUIDE\n\n$RUN_LATER_GUIDE" "$WT_HEIGHT" "$WT_WIDTH" 4 \
"PNG" "" ON \
"JPEG" "" ON \
"GIF" "" ON \
"BMP" "" ON \
"MarkDown" "" ON \
"MP3" "" ON \
"TXT" "" ON \
"Movie" "" ON \
"Photoshop" "" ON \
"SVG" "" ON \
"TIFF" "" ON 3>&1 1>&2 2>&3)

    case "$choice" in
        *"PNG"*)
            nextcloud_occ config:system:set enabledPreviewProviders 0 --value="OC\\Preview\\PNG"
        ;;&
        *"JPEG"*)
            nextcloud_occ config:system:set enabledPreviewProviders 1 --value="OC\\Preview\\JPEG"
        ;;&
        *"GIF"*)
            nextcloud_occ config:system:set enabledPreviewProviders 2 --value="OC\\Preview\\GIF"
        ;;&
        *"BMP"*)
            nextcloud_occ config:system:set enabledPreviewProviders 3 --value="OC\\Preview\\BMP"
        ;;&
        *"MarkDown"*)
            nextcloud_occ config:system:set enabledPreviewProviders 4 --value="OC\\Preview\\MarkDown"
        ;;&
        *"MP3"*)
            nextcloud_occ config:system:set enabledPreviewProviders 5 --value="OC\\Preview\\MP3"
        ;;&
        *"TXT"*)
            nextcloud_occ config:system:set enabledPreviewProviders 6 --value="OC\\Preview\\TXT"
        ;;&
        *"Movie"*)
            nextcloud_occ config:system:set enabledPreviewProviders 7 --value="OC\\Preview\\Movie"
        ;;&
        *"Photoshop"*)
            nextcloud_occ config:system:set enabledPreviewProviders 8 --value="OC\\Preview\\Photoshop"
        ;;&
        *"SVG"*)
            nextcloud_occ config:system:set enabledPreviewProviders 9 --value="OC\\Preview\\SVG"
        ;;&
        *"TIFF"*)
            nextcloud_occ config:system:set enabledPreviewProviders 10 --value="OC\\Preview\\TIFF"
        ;;&
        *)
        ;;
    esac
else
    # check if imagick is installed and remove it
    if is_this_installed php-imagick
    then
        apt-get purge php-imagick -y
    elif is_this_installed php"$PHPVER"-imagick
    then
        apt-get purge php"$PHPVER"-imagick -y
    fi
    # check if libmagickcore is installed and remove it
    if is_this_installed libmagickcore-6.q16-3-extra
    then
        apt-get purge libmagickcore-6.q16-3-extra -y
    fi
    # Choose file formats fo the case when imagick is not installed.
    # for additional previews please look at the Nextcloud documentation. But these probably won't work.
    choice=$(whiptail --title "$TITLE - Choose file formats" --checklist \
"Now you can choose for which file formats you would like to generate previews for
$CHECKLIST_GUIDE\n\n$RUN_LATER_GUIDE" "$WT_HEIGHT" "$WT_WIDTH" 4 \
"PNG" "" ON \
"JPEG" "" ON \
"GIF" "" ON \
"BMP" "" ON \
"MarkDown" "" ON \
"MP3" "" ON \
"TXT" "" ON \
"Movie" "" ON 3>&1 1>&2 2>&3)

    case "$choice" in
        *"PNG"*)
            nextcloud_occ config:system:set enabledPreviewProviders 11 --value="OC\\Preview\\PNG"
        ;;&
        *"JPEG"*)
            nextcloud_occ config:system:set enabledPreviewProviders 12 --value="OC\\Preview\\JPEG"
        ;;&
        *"GIF"*)
            nextcloud_occ config:system:set enabledPreviewProviders 13 --value="OC\\Preview\\GIF"
        ;;&
        *"BMP"*)
            nextcloud_occ config:system:set enabledPreviewProviders 14 --value="OC\\Preview\\BMP"
        ;;&
        *"MarkDown"*)
            nextcloud_occ config:system:set enabledPreviewProviders 15 --value="OC\\Preview\\MarkDown"
        ;;&
        *"MP3"*)
            nextcloud_occ config:system:set enabledPreviewProviders 16 --value="OC\\Preview\\MP3"
        ;;&
        *"TXT"*)
            nextcloud_occ config:system:set enabledPreviewProviders 17 --value="OC\\Preview\\TXT"
        ;;&
        *"Movie"*)
            nextcloud_occ config:system:set enabledPreviewProviders 18 --value="OC\\Preview\\Movie"
        ;;&
        *)
        ;;
    esac
fi

# Set aspect ratio
nextcloud_occ config:app:set previewgenerator squareSizes --value="32 256"
nextcloud_occ config:app:set previewgenerator widthSizes  --value="256 384"
nextcloud_occ config:app:set previewgenerator heightSizes --value="256"
nextcloud_occ config:system:set preview_max_x --value="2048"
nextcloud_occ config:system:set preview_max_y --value="2048"
nextcloud_occ config:system:set jpeg_quality --value="60"
nextcloud_occ config:system:set preview_max_memory --value="128"
nextcloud_occ config:app:set preview jpeg_quality --value="60"

# Add crontab for www-data
if ! crontab -u www-data -l | grep -q 'preview:pre-generate'
then
    print_text_in_color "$ICyan" "Adding crontab for $SCRIPT_NAME"
    crontab -u www-data -l | { cat; echo "*/10 * * * * php -f $NCPATH/occ preview:pre-generate >> $VMLOGS/previewgenerator.log"; } | crontab -u www-data -
    touch "$VMLOGS"/previewgenerator.log
    chown www-data:www-data "$VMLOGS"/previewgenerator.log
fi

msg_box "In the last step you can define a specific Nextcloud user for \
which will be the user that runs the Preview Generation.

The default behavior (just hit [ENTER]) is to run with the \
system user 'www-data' which will generate previews for all users.

If you on the other hand choose to use a specific user, previews will ONLY be generated for that specific user."

if ! yesno_box_no "Do you want to choose a specific Nextcloud user to generate previews?"
then
    print_text_in_color "$ICyan" "Using www-data (all Nextcloud users) for generating previews..."

    # Pre generate everything
    nextcloud_occ preview:generate-all
else
    while :
    do
        PREVIEW_USER=$(input_box "Enter the Nextcloud user for \
which you want to run the Preview Generation (as a scheduled task)")
        if [ -z "$(nextcloud_occ user:list | grep "$PREVIEW_USER" | awk '{print $3}')" ]
        then
            msg_box "It seems like the user you entered ($PREVIEW_USER) doesn't exist, please try again."
        else
            break
        fi
    done

    # Pre generate everything
    nextcloud_occ preview:generate-all "$PREVIEW_USER"
fi

msg_box "Previewgenerator was successfully installed."
