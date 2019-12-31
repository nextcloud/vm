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

msg_box "This script will install the previewgerator. 

It can speedup the feel of Nextcloud by a lot."
if [[ "no" == $(ask_yes_or_no "So do you want to install the previewgenerator?") ]]
then
    exit
else
    # Install preview generator and ffmpeg
    install_and_enable_app previewgenerator
    occ_command config:system:set enable_previews --value=true --type=boolean
    install_if_not ffmpeg
fi

msg_box "In the next step you can choose to install a package called imagick to speed up the generation of previews and get support for more filetypes. 

Please note that this will put your server at risk as imagick is known to have several flaws.

You can check this issue to understand why: https://github.com/nextcloud/vm/issues/743"
if [[ "yes" == $(ask_yes_or_no "Do you want to install imagick?") ]]
then
    # Install imagick
    install_if_not php-imagick
    install_if_not libmagickcore-6.q16-3-extra
    
    # Choose file formats fo the case when imagick is installed.
    whiptail --title "Choose file formats" --checklist --separate-output "Now you can choose for which file formats you would like to generate previews\nSelect or unselect by pressing the spacebar" "$WT_HEIGHT" "$WT_WIDTH" 4 \
    "PNG" ON \
    "JPEG" ON \
    "GIF" ON \
    "BMP" ON \
    "MarkDown" ON \
    "MP3" ON \
    "TXT" ON \
    "Movie" OFF \
    "Photoshop" OFF \
    "SVG" OFF \
    "TIFF" OFF 2>results
    
    while read -r -u 9 choice
    do
        case $choice in
            PNG)
                clear
                occ_command config:system:set enabledPreviewProviders 0 --value="OC\\Preview\\PNG"
            ;;

            JPEG)
                clear
                occ_command config:system:set enabledPreviewProviders 1 --value="OC\\Preview\\JPEG"
            ;;

            GIF)
                clear
                occ_command config:system:set enabledPreviewProviders 2 --value="OC\\Preview\\GIF"
            ;;

            BMP)
                clear
                occ_command config:system:set enabledPreviewProviders 3 --value="OC\\Preview\\BMP"
            ;;

            MarkDown)
                clear
                occ_command config:system:set enabledPreviewProviders 5 --value="OC\\Preview\\MarkDown"
            ;;

            MP3)
                clear
                occ_command config:system:set enabledPreviewProviders 6 --value="OC\\Preview\\MP3"
            ;;

            TXT)
                clear
                occ_command config:system:set enabledPreviewProviders 7 --value="OC\\Preview\\TXT"
            ;;

            Movie)
                clear
                occ_command config:system:set enabledPreviewProviders 9 --value="OC\\Preview\\Movie"
            ;;

            Photoshop)
                clear
                occ_command config:system:set enabledPreviewProviders 15 --value="OC\\Preview\\Photoshop"
            ;;

            SVG)
                clear
                occ_command config:system:set enabledPreviewProviders 18 --value="OC\\Preview\\SVG"
            ;;

            TIFF)
                clear
                occ_command config:system:set enabledPreviewProviders 19 --value="OC\\Preview\\TIFF"
            ;;

            *)
            ;;
        esac
    done 9< results
    rm -f results
    clear      

else
    # Choose file formats fo the case when imagick is not installed.
    whiptail --title "Choose file formats" --checklist --separate-output "Now you can choose for which file formats you would like to generate previews\nSelect or unselect by pressing the spacebar" "$WT_HEIGHT" "$WT_WIDTH" 4 \
    "PNG" ON \
    "JPEG" ON \
    "GIF" ON \
    "BMP" ON \
    "MarkDown" ON \
    "MP3" ON \
    "TXT" ON \
    "Movie" OFF 2>results

    while read -r -u 9 choice
    do
        case $choice in
            PNG)
                clear
                occ_command config:system:set enabledPreviewProviders 0 --value="OC\\Preview\\PNG"
            ;;

            JPEG)
                clear
                occ_command config:system:set enabledPreviewProviders 1 --value="OC\\Preview\\JPEG"
            ;;

            GIF)
                clear
                occ_command config:system:set enabledPreviewProviders 2 --value="OC\\Preview\\GIF"
            ;;

            BMP)
                clear
                occ_command config:system:set enabledPreviewProviders 3 --value="OC\\Preview\\BMP"
            ;;

            MarkDown)
                clear
                occ_command config:system:set enabledPreviewProviders 5 --value="OC\\Preview\\MarkDown"
            ;;

            MP3)
                clear
                occ_command config:system:set enabledPreviewProviders 6 --value="OC\\Preview\\MP3"
            ;;

            TXT)
                clear
                occ_command config:system:set enabledPreviewProviders 7 --value="OC\\Preview\\TXT"
            ;;

            Movie)
                clear
                occ_command config:system:set enabledPreviewProviders 9 --value="OC\\Preview\\Movie"
            ;;

            *)
            ;;
        esac
    done 9< results
    rm -f results
    clear
fi

# Enable additional previews (most likely not working; remove the # to enable the specific preview)
#occ_command config:system:set preview_libreoffice_path --value="/usr/bin/libreoffice"
#occ_command config:system:set enabledPreviewProviders 4 --value="OC\\Preview\\XBitmap"
#occ_command config:system:set enabledPreviewProviders 8 --value="OC\\Preview\\Illustrator"
#occ_command config:system:set enabledPreviewProviders 10 --value="OC\\Preview\\MSOffice2003"
#occ_command config:system:set enabledPreviewProviders 11 --value="OC\\Preview\\MSOffice2007"
#occ_command config:system:set enabledPreviewProviders 12 --value="OC\\Preview\\MSOfficeDoc"
#occ_command config:system:set enabledPreviewProviders 13 --value="OC\\Preview\\OpenDocument"
#occ_command config:system:set enabledPreviewProviders 14 --value="OC\\Preview\\PDF"
#occ_command config:system:set enabledPreviewProviders 16 --value="OC\\Preview\\Postscript"
#occ_command config:system:set enabledPreviewProviders 17 --value="OC\\Preview\\StarOffice"
#occ_command config:system:set enabledPreviewProviders 20 --value="OC\\Preview\\Font"
#occ_command config:system:set enabledPreviewProviders 21 --value="OC\\Preview\\HEIC"

# check if the previewgenerator is installed and enabled
if [ -d "$NC_APPS_PATH/previewgenerator" ]
then
    # Set aspect ratio
    occ_command config:app:set previewgenerator squareSizes --value="32 256"
    occ_command config:app:set previewgenerator widthSizes  --value="256 384"
    occ_command config:app:set previewgenerator heightSizes --value="256"
    occ_command config:system:set preview_max_x --value="2048"
    occ_command config:system:set preview_max_y --value="2048"
    occ_command config:system:set jpeg_quality --value="60"
    occ_command config:app:set preview jpeg_quality --value="60"
    
    msg_box "In the last step you can define a nextcloud-user for which you want to run the preview-generation. "
    if [[ "yes" == $(ask_yes_or_no "So do you want to choose a nextcloud-user?") ]]
    then
        nextcloud_user=$(whiptail --inputbox "Enter the nextcloud-user for which you want to run the preview-generation" 10 30 3>&1 1>&2 2>&3)
        export nextcloud_user
        if [[ "yes" == $(ask_yes_or_no "Is this correct? $nextcloud_user") ]]
        then
            sleep 1
        fi
    else
        sleep 1
    fi
    
    # Add crontab
    crontab -u www-data -l | { cat; echo "0 4 * * * php -f $NCPATH/occ preview:pre-generate $nextcloud_user >> /var/log/previewgenerator.log"; } | crontab -u www-data -
    touch /var/log/previewgenerator.log
    chown www-data:www-data /var/log/previewgenerator.log

    # Pre generate everything
    occ_command preview:generate-all $nextcloud_user

fi

exit
