#!/bin/bash

# Tech and Me © - 2018, https://www.techandme.se/

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

# Install preview generator
install_and_enable_app previewgenerator

# Run the first preview generation and add crontab
if [ -d "$NC_APPS_PATH/previewgenerator" ]
then
    # Enable previews (remove the # to enable the specific preview)
    occ_command config:system:set enable_previews --value=true --type=boolean
    occ_command config:system:set preview_libreoffice_path --value='/usr/bin/libreoffice'
#    occ_command config:system:set enabledPreviewProviders 0 --value='OC\\Preview\\PNG'
#    occ_command config:system:set enabledPreviewProviders 1 --value='OC\\Preview\\JPEG'
#    occ_command config:system:set enabledPreviewProviders 2 --value='OC\\Preview\\GIF'
#    occ_command config:system:set enabledPreviewProviders 3 --value='OC\\Preview\\BMP'
#    occ_command config:system:set enabledPreviewProviders 4 --value='OC\\Preview\\XBitmap'
#    occ_command config:system:set enabledPreviewProviders 5 --value='OC\\Preview\\MarkDown'
#    occ_command config:system:set enabledPreviewProviders 6 --value='OC\\Preview\\MP3'
#    occ_command config:system:set enabledPreviewProviders 7 --value='OC\\Preview\\TXT'
#    occ_command config:system:set enabledPreviewProviders 8 --value='OC\\Preview\\Illustrator'
#    occ_command config:system:set enabledPreviewProviders 9 --value='OC\\Preview\\Movie'
#    occ_command config:system:set enabledPreviewProviders 10 --value='OC\\Preview\\MSOffice2003'
#    occ_command config:system:set enabledPreviewProviders 11 --value='OC\\Preview\\MSOffice2007'
#    occ_command config:system:set enabledPreviewProviders 12 --value='OC\\Preview\\MSOfficeDoc'
#    occ_command config:system:set enabledPreviewProviders 13 --value='OC\\Preview\\OpenDocument'
#    occ_command config:system:set enabledPreviewProviders 14 --value='OC\\Preview\\PDF'
#    occ_command config:system:set enabledPreviewProviders 15 --value='OC\\Preview\\Photoshop'
#    occ_command config:system:set enabledPreviewProviders 16 --value='OC\\Preview\\Postscript'
#    occ_command config:system:set enabledPreviewProviders 17 --value='OC\\Preview\\StarOffice'
#    occ_command config:system:set enabledPreviewProviders 18 --value='OC\\Preview\\SVG'
#    occ_command config:system:set enabledPreviewProviders 19 --value='OC\\Preview\\TIFF'
#    occ_command config:system:set enabledPreviewProviders 20 --value='OC\\Preview\\Font'
    
    # Set aspect ratio
    occ_command config:app:set --value="32 64 1024"  previewgenerator squareSizes
    occ_command config:app:set --value="64 128 1024" previewgenerator widthSizes
    occ_command config:app:set --value="64 256 1024" previewgenerator heightSizes
    
    # Add crotab
    crontab -u www-data -l | { cat; echo "@daily php -f $NCPATH/occ preview:pre-generate >> /var/log/previewgenerator.log"; } | crontab -u www-data -
    touch /var/log/previewgenerator.log
    chown www-data:www-data /var/log/previewgenerator.log
    
    # Install needed dependencies
    install_if_not ffmpeg
    install_if_not libreoffice
    
    # Pre generate everything
    occ_command preview:generate-all
fi
