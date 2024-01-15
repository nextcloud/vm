#!/bin/bash

# T&M Hansson IT AB © - 2024, https://www.hanssonit.se/

true
SCRIPT_NAME="Not-supported Menu"
# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Must be root
root_check

print_text_in_color "$ICyan" "Running the Not-supported Menu script..."

if network_ok
then
    # Delete, download, run
    run_script NOT_SUPPORTED_FOLDER not-supported_menu
fi

exit
