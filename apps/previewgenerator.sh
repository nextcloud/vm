#!/bin/bash

# T&M Hansson IT AB © - 2019, https://www.hanssonit.se/

# shellcheck disable=2034,2059
true
# shellcheck source=lib.sh
. <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Check if root
root_check

# PHP 7.x is needed
if is_this_installed php5.6-common
then
    msg_box "At least PHP 7.X is supported, please upgrade your PHP version: https://shop.hanssonit.se/product/upgrade-php-version-including-dependencies/"
    exit
elif is_this_installed php5.5-common
then
    msg_box "At least PHP 7.X is supported, please upgrade your PHP version: https://shop.hanssonit.se/product/upgrade-php-version-including-dependencies/"
    exit
fi

# Encryption may not be enabled #### encryption will always list, check if it's enabled by grepping the version number
#if occ_command app:list | grep encryption
#then
#    msg_box "It seems like you have encryption enabled which is unsupported when using the preview generator"
#    exit
#fi

msg_box "This script will install the previewgerator. 

It can speedup the loading of previews in Nextcloud a lot.

Please note: If you continue, all your current previewgenerator settings will be lost, if any."
if [[ "yes" == $(ask_yes_or_no "Do you want to install the previewgenerator?") ]]
then
    # Install preview generator
    echo "install the preview generator"
    install_and_enable_app previewgenerator
    
    # check if the previewgenerator is installed and enabled
    if [ -d "$NC_APPS_PATH/previewgenerator" ]
    then
        # enable previews
        occ_command config:system:set enable_previews --value=true --type=boolean
        
        # install needed dependency for movies
        install_if_not ffmpeg
        
        # reset the preview formats
        occ_command config:system:delete "enabledPreviewProviders"
        
        # reset the cronjob
        print_text_in_color "$ICyan" "Resetting the cronjob for the preview-generation"
        crontab -u www-data -l | grep -v 'preview:generate-all'  | crontab -u www-data -
    else
        exit
    fi
else
    exit
fi

msg_box "In the next step you can choose to install a package called imagick to speed up the generation of previews and get support for more filetypes.

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
if [[ "yes" == $(ask_yes_or_no "Do you want to install imagick?") ]]
then
    # Install imagick
    install_if_not php-imagick
    install_if_not libmagickcore-6.q16-3-extra
    
    # Choose file formats fo the case when imagick is installed.
    # for additional previews please look at the nextcloud documentation. But these probably won't work.
    whiptail --title "Choose file formats" --checklist --separate-output "Now you can choose for which file formats you would like to generate previews\nSelect or unselect by pressing the spacebar" "$WT_HEIGHT" "$WT_WIDTH" 4 \
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
    "TIFF" "" ON 2>results
    
    while read -r -u 11 choice
    do
        case $choice in
            "PNG")
                occ_command config:system:set enabledPreviewProviders 0 --value="OC\\Preview\\PNG"
            ;;

            "JPEG")
                occ_command config:system:set enabledPreviewProviders 1 --value="OC\\Preview\\JPEG"
            ;;

            "GIF")
                occ_command config:system:set enabledPreviewProviders 2 --value="OC\\Preview\\GIF"
            ;;

            "BMP")
                occ_command config:system:set enabledPreviewProviders 3 --value="OC\\Preview\\BMP"
            ;;

            "MarkDown")
                occ_command config:system:set enabledPreviewProviders 4 --value="OC\\Preview\\MarkDown"
            ;;

            "MP3")
                occ_command config:system:set enabledPreviewProviders 5 --value="OC\\Preview\\MP3"
            ;;

            "TXT")
                occ_command config:system:set enabledPreviewProviders 6 --value="OC\\Preview\\TXT"
            ;;

            "Movie")
                occ_command config:system:set enabledPreviewProviders 7 --value="OC\\Preview\\Movie"
            ;;

            "Photoshop")
                occ_command config:system:set enabledPreviewProviders 8 --value="OC\\Preview\\Photoshop"
            ;;

            "SVG")
                occ_command config:system:set enabledPreviewProviders 9 --value="OC\\Preview\\SVG"
            ;;

            "TIFF")
                occ_command config:system:set enabledPreviewProviders 10 --value="OC\\Preview\\TIFF"
            ;;

            *)
            ;;
        esac
    done 11< results
    rm -f results
else
    # check if imagick ist installed and remove it
    if is_this_installed imagick
    then
        apt purge php-imagick -y
    fi
    # check if libmagickcore is installed and remove it
    if is_this_installed libmagickcore-6.q16-3-extra
    then
        apt purge libmagickcore-6.q16-3-extra -y
    fi    
    # Choose file formats fo the case when imagick is not installed.
    # for additional previews please look at the nextcloud documentation. But these probably won't work.
    whiptail --title "Choose file formats" --checklist --separate-output "Now you can choose for which file formats you would like to generate previews\nSelect or unselect by pressing the spacebar" "$WT_HEIGHT" "$WT_WIDTH" 4 \
    "PNG" "" ON \
    "JPEG" "" ON \
    "GIF" "" ON \
    "BMP" "" ON \
    "MarkDown" "" ON \
    "MP3" "" ON \
    "TXT" "" ON \
    "Movie" "" ON 2>results

    while read -r -u 8 choice
    do
        case $choice in
            "PNG")
                occ_command config:system:set enabledPreviewProviders 11 --value="OC\\Preview\\PNG"
            ;;

            "JPEG")
                occ_command config:system:set enabledPreviewProviders 12 --value="OC\\Preview\\JPEG"
            ;;

            "GIF")
                occ_command config:system:set enabledPreviewProviders 13 --value="OC\\Preview\\GIF"
            ;;

            "BMP")
                occ_command config:system:set enabledPreviewProviders 14 --value="OC\\Preview\\BMP"
            ;;

            "MarkDown")
                occ_command config:system:set enabledPreviewProviders 15 --value="OC\\Preview\\MarkDown"
            ;;

            "MP3")
                occ_command config:system:set enabledPreviewProviders 16 --value="OC\\Preview\\MP3"
            ;;

            "TXT")
                occ_command config:system:set enabledPreviewProviders 17 --value="OC\\Preview\\TXT"
            ;;

            "Movie")
                occ_command config:system:set enabledPreviewProviders 18 --value="OC\\Preview\\Movie"
            ;;

            *)
            ;;
        esac
    done 8< results
    rm -f results
fi

# Set aspect ratio
occ_command config:app:set previewgenerator squareSizes --value="32 256"
occ_command config:app:set previewgenerator widthSizes  --value="256 384"
occ_command config:app:set previewgenerator heightSizes --value="256"
occ_command config:system:set preview_max_x --value="2048"
occ_command config:system:set preview_max_y --value="2048"
occ_command config:system:set jpeg_quality --value="60"
occ_command config:app:set preview jpeg_quality --value="60"

msg_box "In the last step you can define a specific Nextcloud user for which will be the user that runs the preview-generation. 

The default behavoiur (just hit [ENTER]) is to run with the system user 'www-data' which will generate previews for all users. 

If you on the other hand choose to use a specific user, previews will ONLY be generated for that specific user."
if [[ "no" == $(ask_yes_or_no "Do you want to choose a specific Nextcloud user to generate previews?") ]]
then
    # Add crontab for www-data
    crontab -u www-data -l | { cat; echo "0 4 * * * php -f $NCPATH/occ preview:pre-generate >> $VMLOGS/previewgenerator.log"; } | crontab -u www-data -
    touch "$VMLOGS"/previewgenerator.log
    chown www-data:www-data "$VMLOGS"/previewgenerator.log
    
    # Pre generate everything
    occ_command preview:generate-all
else
    while true
    do
        PREVIEW_USER=$(whiptail --inputbox "Enter the Nextcloud user for which you want to run the preview-generation" "$WT_HEIGHT" "$WT_WIDTH" 3>&1 1>&2 2>&3)
        if [ -z "$(occ_command user:list | grep "$PREVIEW_USER" | awk '{print $3}')" ]
        then
            msg_box "It seems like the user you entered ($PREVIEW_USER) doesn't exist, please try again."
        else
            break
        fi
    done
     # Add crontab for $PREVIEW_USER
     crontab -u www-data -l | { cat; echo "0 4 * * * php -f $NCPATH/occ preview:pre-generate $PREVIEW_USER >> $VMLOGS/previewgenerator.log"; } | crontab -u www-data -
     touch "$VMLOGS"/previewgenerator.log
     chown www-data:www-data "$VMLOGS"/previewgenerator.log
     
     # Pre generate everything
     occ_command preview:generate-all "$PREVIEW_USER"
fi
