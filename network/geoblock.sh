#!/bin/bash

# T&M Hansson IT AB © - 2023, https://www.hanssonit.se/
# Copyright © 2021 Simon Lindner (https://github.com/szaimen)

true
SCRIPT_NAME="GeoBlock"
SCRIPT_EXPLAINER="This script lets you restrict access to your webserver, only allowing the countries you choose.\n
Attention!
Geoblock can break the certificate renewal via \"Let's encrypt!\" if done too strict!
If you have problems with \"Let's encrypt!\", please uninstall geoblock first to see if that fixes those issues!"
# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Must be root
root_check

# Check if it is already configured
if ! grep -q "^#Geoip-block" /etc/apache2/apache2.conf
then
    # Ask for installing
    install_popup "$SCRIPT_NAME"
else
    # Ask for removal or reinstallation
    reinstall_remove_menu "$SCRIPT_NAME"
    # Removal
    find /var/scripts -type f -regex \
"$SCRIPTS/202[0-9]-[01][0-9]-Maxmind-Country-IPv[46]\.dat" -delete
    if is_this_installed libapache2-mod-geoip
    then
        a2dismod geoip
        apt-get purge libapache2-mod-geoip -y
    fi
    apt-get autoremove -y
    sed -i "/^#Geoip-block-start/,/^#Geoip-block-end/d" /etc/apache2/apache2.conf
    check_command systemctl restart apache2
    # Show successful uninstall if applicable
    removal_popup "$SCRIPT_NAME"
fi

# Install needed tools
install_if_not libapache2-mod-geoip

# Enable apache mod
check_command a2enmod geoip rewrite
check_command systemctl restart apache2

# Download newest dat files
find /var/scripts -type f -regex \
"$SCRIPTS/202[0-9]-[01][0-9]-Maxmind-Country-IPv[46]\.dat" -delete
get_newest_dat_files

# Restrict to countries and/or continents
choice=$(whiptail --title "$TITLE"  --checklist \
"Do you want to restrict to countries and/or continents?
$CHECKLIST_GUIDE\n\n$RUN_LATER_GUIDE" "$WT_HEIGHT" "$WT_WIDTH" 4 \
"Countries" "" ON \
"Continents" "" ON 3>&1 1>&2 2>&3)
if [ -z "$choice" ]
then
    exit 1
fi

# Countries
if [[ "$choice" = *"Countries"* ]]
then
    # Download csv file
    if ! curl_to_dir "https://dev.maxmind.com/csv-files/codes" "iso3166.csv" "$SCRIPTS"
    then
        msg_box "Could not download the iso3166.csv file.
Please report this to $ISSUES"
        exit 1
    fi

    # Get country names
    COUNTRY_NAMES=$(sed 's|.*,"||;s|"$||' "$SCRIPTS/iso3166.csv")
    mapfile -t COUNTRY_NAMES <<< "$COUNTRY_NAMES"

    # Get country codes
    COUNTRY_CODES=$(sed 's|,.*||' "$SCRIPTS/iso3166.csv")
    mapfile -t COUNTRY_CODES <<< "$COUNTRY_CODES"

    # Remove the csv file since no longer needed
    check_command rm "$SCRIPTS/iso3166.csv"

    # Check if both arrays match
    if [ "${#COUNTRY_NAMES[@]}" != "${#COUNTRY_CODES[@]}" ]
    then
        msg_box "Somethings is wrong. The names length is not equal to the codes length.
Please report this to $ISSUES"
        exit 1
    fi

    # Create checklist
    args=(whiptail --title "$TITLE - $SUBTITLE" --separate-output --checklist \
"Please select all countries that shall have access to your server.
All countries that aren't selected will *not* have access to your server. \
To allow them you have to choose the specific continent.
$CHECKLIST_GUIDE\n\n$RUN_LATER_GUIDE" "$WT_HEIGHT" "$WT_WIDTH" 4)
    count=0
    while [ "$count" -lt "${#COUNTRY_NAMES[@]}" ]
    do
        args+=("${COUNTRY_CODES[$count]}" "${COUNTRY_NAMES[$count]}" OFF)
        ((count++))
    done

    # Let the user choose the countries
    selected_options=$("${args[@]}" 3>&1 1>&2 2>&3)
    if [ -z "$selected_options" ]
    then
        unset selected_options
    fi
fi

# Continents
if [[ "$choice" = *"Continents"* ]]
then
    # Restrict to continents
    choice=$(whiptail --title "$TITLE" --separate-output --checklist \
"Please choose all continents that shall have access to your server.
All countries on not selected continents will not have access to your server \
if you haven't explicitly chosen them in the countries menu before.
$CHECKLIST_GUIDE\n\n$RUN_LATER_GUIDE" "$WT_HEIGHT" "$WT_WIDTH" 4 \
"AF" "Africa" OFF \
"AN" "Antarctica" OFF \
"AS" "Asia" OFF \
"EU" "Europe" OFF \
"NA" "North America" OFF \
"OC" "Oceania" OFF \
"SA" "South America" OFF 3>&1 1>&2 2>&3)
    if [ -z "$choice" ]
    then
        unset choice
    fi
else
    unset choice
fi

# Exit if nothing chosen
if [ -z "$selected_options" ] && [ -z "$choice" ]
then
    exit 1
fi

# Convert to array
if [ -n "$selected_options" ]
then
    mapfile -t selected_options <<< "$selected_options"
fi
if [ -n "$choice" ]
then
    mapfile -t choice <<< "$choice"
fi

GEOIP_CONF="#Geoip-block-start - Please don't remove or change this line
<IfModule mod_geoip.c>
  GeoIPEnable On
  GeoIPDBFile /usr/share/GeoIP/GeoIP.dat
  GeoIPDBFile /usr/share/GeoIP/GeoIPv6.dat
</IfModule>
<Location />\n"
for continent in "${choice[@]}"
do
    GEOIP_CONF+="  SetEnvIf GEOIP_CONTINENT_CODE    $continent AllowCountryOrContinent\n"
    GEOIP_CONF+="  SetEnvIf GEOIP_CONTINENT_CODE_V6 $continent AllowCountryOrContinent\n"
done
for country in "${selected_options[@]}"
do
    GEOIP_CONF+="  SetEnvIf GEOIP_COUNTRY_CODE    $country AllowCountryOrContinent\n"
    GEOIP_CONF+="  SetEnvIf GEOIP_COUNTRY_CODE_V6 $country AllowCountryOrContinent\n"
done
GEOIP_CONF+="  Allow from env=AllowCountryOrContinent
  Allow from 127.0.0.1/8
  Allow from 192.168.0.0/16
  Allow from 172.16.0.0/12
  Allow from 10.0.0.0/8
  Allow from scan.nextcloud.com
  # Allow scans from observatory.mozilla.org:
  Allow from 63.245.208.0/24
  Order Deny,Allow
  Deny from all
</Location>
#Geoip-block-end - Please don't remove or change this line"

# Write everything to the file
echo -e "$GEOIP_CONF" >> /etc/apache2/apache2.conf

check_command systemctl restart apache2

msg_box "GeoBlock was successfully configured"

exit
