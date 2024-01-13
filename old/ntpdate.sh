#!/bin/bash

# T&M Hansson IT AB © - 2024, https://www.hanssonit.se/

true
SCRIPT_NAME="Ntpdate"
# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

if network_ok
then
    if is_this_installed ntpdate
    then
        ntpdate -s 1.se.pool.ntp.org
    fi
fi
exit
