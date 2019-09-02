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

# Must be root
root_check

# Channge PHP-FPM (16 GB RAM)
check_command sed -i "s|pm.max_children.*|pm.max_children = 307|g" $PHP_POOL_DIR/nextcloud.conf
check_command sed -i "s|pm.start_servers.*|pm.start_servers = 20|g" $PHP_POOL_DIR/nextcloud.conf
check_command sed -i "s|pm.min_spare_servers.*|pm.min_spare_servers = 30|g" $PHP_POOL_DIR/nextcloud.conf
check_command sed -i "s|pm.max_spare_servers.*|pm.max_spare_servers = 257|g" $PHP_POOL_DIR/nextcloud.conf
restart_webserver

# Change instruction.sh 
# not working ## check_command "s|Thanks for downloading this Nextcloud VM by the Nextcloud Community|Thanks for purchasing the Nextcloud Home/SME Server by T&M Hansson IT AB|g" $SCRIPTS/instruction.sh

# Change nextcloud-startup-script.sh
check_command sed -i "s|VM|Home/SME Server|g" $SCRIPTS/nextcloud-startup-script.sh

# Change index.php
# Change everything

# Make a new quick instructions to replace apache default page
