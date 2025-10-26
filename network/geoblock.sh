#!/bin/bash

# T&M Hansson IT AB © - 2024, https://www.hanssonit.se/
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
if [ ! -f "$GEOBLOCK_MOD_CONF" ] && [ ! -f "$GEOBLOCK_MOD" ] && ! grep -q "^#Geoip-block" /etc/apache2/apache2.conf
then
    # Ask for installing
    install_popup "$SCRIPT_NAME"
else
    # Ask for removal or reinstallation
    reinstall_remove_menu "$SCRIPT_NAME"
    # Remove Apache mod config
    rm -f "$GEOBLOCK_MOD_CONF"
    # Remove old database files
    find /var/scripts -type f -regex \
"$SCRIPTS/202[0-9]-[01][0-9]-Maxmind-Country-IPv[46]\.dat" -delete
    find "$GEOBLOCK_DIR" -type f -regex \
"*.dat" -delete
    rm -f "$GEOBLOCK_DIR"/IPInfo-Country.mmdb
    # Remove Apache2 mod
    if [ -f "$GEOBLOCK_MOD" ]
    then
        a2dismod maxminddb
        rm -f "$GEOBLOCK_MOD"
        rm -f /usr/lib/apache2/modules/mod_maxminddb.so
    fi
    if is_this_installed libapache2-mod-geoip
    then
        a2dismod geoip
        apt-get purge libapache2-mod-geoip -y
    fi
    # Remove PPA
    if grep ^ /etc/apt/sources.list /etc/apt/sources.list.d/* | grep maxmind-ubuntu-ppa
    then
        install_if_not ppa-purge
        yes | ppa-purge maxmind/ppa
        rm -f /etc/apt/sources.list.d/maxmind*
    fi
    # Remove  Apache config
    if grep "Geoip-block-start" /etc/apache2/apache2.conf
    then
        sed -i "/^#Geoip-block-start/,/^#Geoip-block-end/d" /etc/apache2/apache2.conf
    fi
    if [ -f "$GEOBLOCK_MOD_CONF" ]
    then
        a2disconf geoblock
        rm -f "$GEOBLOCK_MOD_CONF"
    fi
    # Show successful uninstall if applicable
    removal_popup "$SCRIPT_NAME"
    # Make sure it's clean from unused packages and files
    apt-get purge libmaxminddb0* libmaxminddb-dev* mmdb-bin* apache2-dev* -y
    apt-get autoremove -y
    check_command systemctl restart apache2
fi

# Download GeoIP Databases
if ! download_geoip_mmdb
then
   exit 1
fi

##### GeoIP script (Apache Setup)
# Install requirements
yes | add-apt-repository ppa:maxmind/ppa
apt-get update -q4 & spinner_loading
install_if_not libmaxminddb0
install_if_not libmaxminddb-dev
install_if_not mmdb-bin

# Install apache2-dev with dependency resolution
# Handle conflicts with Sury PPA packages
print_text_in_color "$ICyan" "Installing apache2-dev (this may take a moment)..."
if ! apt-get install -y apache2-dev 2>&1 | tee /tmp/apache2-dev-install.log
then
    print_text_in_color "$IYellow" "Warning: apache2-dev installation encountered issues."
    print_text_in_color "$ICyan" "Attempting to resolve dependency conflicts..."
    
    # Try to fix broken dependencies
    if apt-get install -f -y
    then
        print_text_in_color "$IGreen" "Dependencies fixed, retrying apache2-dev installation..."
        if ! apt-get install -y apache2-dev
        then
            msg_box "Failed to install apache2-dev even after fixing dependencies.

This is likely due to conflicts with PHP PPA packages (e.g., Sury PPA).
The error log has been saved to /tmp/apache2-dev-install.log

Please report this issue to: $ISSUES
Include the contents of /tmp/apache2-dev-install.log"
            exit 1
        fi
    else
        msg_box "Could not resolve apache2-dev dependency conflicts.

The error log has been saved to /tmp/apache2-dev-install.log

Please report this issue to: $ISSUES
Include the contents of /tmp/apache2-dev-install.log"
        exit 1
    fi
fi

# Verify apxs is available before attempting compilation
if ! command -v apxs2 >/dev/null 2>&1 && ! command -v apxs >/dev/null 2>&1
then
    msg_box "Error: apxs/apxs2 tool not found even after installing apache2-dev.

This tool is required to compile the MaxMindDB Apache module.
Please report this issue to: $ISSUES"
    exit 1
fi

print_text_in_color "$IGreen" "apache2-dev and apxs successfully installed!"

# maxminddb_module https://github.com/maxmind/mod_maxminddb
cd /tmp
curl_to_dir https://github.com/maxmind/mod_maxminddb/releases/download/1.2.0/ mod_maxminddb-1.2.0.tar.gz /tmp
tar -xzf mod_maxminddb-1.2.0.tar.gz
cd mod_maxminddb-1.2.0

print_text_in_color "$ICyan" "Compiling MaxMindDB Apache module..."
if ./configure
then
    if make
    then
        if make install
        then
            print_text_in_color "$IGreen" "MaxMindDB Apache module compiled and installed successfully!"
        else
            msg_box "Failed to install MaxMindDB module. Please report this to $ISSUES"
            exit 1
        fi
    else
        msg_box "Failed to compile MaxMindDB module. Please report this to $ISSUES"
        exit 1
    fi
    
    # Delete conf made by module
    rm -f /etc/apache2/mods-enabled/maxminddb.conf
    
    # Check if module is enabled
    if ! apachectl -M | grep -i "maxminddb"
    then
       msg_box "Couldn't load the Apache module for MaxMind after installation. Please report this to $ISSUES"
       exit 1
    fi
    
    print_text_in_color "$IGreen" "MaxMindDB module loaded in Apache successfully!"
    
    # Cleanup
    cd /tmp
    rm -rf mod_maxminddb-1.2.0 mod_maxminddb-1.2.0.tar.gz
else
    msg_box "Failed to configure MaxMindDB module compilation.
    
This usually means apxs/apxs2 is not properly installed.
Please report this issue to: $ISSUES"
    exit 1
fi

# Enable modules
check_command a2enmod rewrite remoteip maxminddb
# Delete conf made by module
rm -f /etc/apache2/mods-enabled/maxminddb.conf
check_command systemctl restart apache2

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
    if ! curl_to_dir "https://dev.maxmind.com/static/csv/codes" "iso3166.csv" "$SCRIPTS"
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

# Create conf
cat << GEOBLOCKCONF_CREATE > "$GEOBLOCK_MOD_CONF"
<IfModule mod_maxminddb.c>
  MaxMindDBEnable On

  # Check for IPinfo mmdb
  <IfFile "$GEOBLOCK_DIR/IPInfo-Country.mmdb">
    MaxMindDBFile DB $GEOBLOCK_DIR/IPInfo-Country.mmdb
    MaxMindDBEnv MM_CONTINENT_CODE DB/continent
    MaxMindDBEnv MM_COUNTRY_CODE DB/country
  </IfFile>
  # Check for Maxmind mmdb
  <IfFile "$GEOBLOCK_DIR/GeoLite2-Country.mmdb">
    MaxMindDBFile DB $GEOBLOCK_DIR/GeoLite2-Country.mmdb
    MaxMindDBEnv MM_CONTINENT_CODE DB/continent/code
    MaxMindDBEnv MM_COUNTRY_CODE DB/country/iso_code
  </IfFile>
</IfModule>

  # Geoblock rules
GEOBLOCKCONF_CREATE

# Add <Location> parameters to maxmind conf
echo "<Location />" >> "$GEOBLOCK_MOD_CONF"
for continent in "${choice[@]}"
do
    echo "  SetEnvIf MM_CONTINENT_CODE    $continent AllowCountryOrContinent" >> "$GEOBLOCK_MOD_CONF"
done
for country in "${selected_options[@]}"
do
    echo "  SetEnvIf MM_COUNTRY_CODE    $country AllowCountryOrContinent" >> "$GEOBLOCK_MOD_CONF"
done
echo "  Allow from env=AllowCountryOrContinent" >> "$GEOBLOCK_MOD_CONF"

# Add allow rules to maxmind conf
cat << GEOBLOCKALLOW_CREATE >> "$GEOBLOCK_MOD_CONF"

  # Specifically allow this
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

  # Logs
  LogLevel info
  CustomLog "$VMLOGS/geoblock_access.log" common
GEOBLOCKALLOW_CREATE

# Enable config
check_command a2enconf geoblock

if check_command systemctl restart apache2
then
    msg_box "GeoBlock was successfully configured"
else
    msg_box "Something went wrong, please check Apache error logs."
fi
