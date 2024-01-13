#!/bin/bash

# T&M Hansson IT AB © - 2024, https://www.hanssonit.se/

true
SCRIPT_NAME="Main Menu"
# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Must be root
root_check

mkdir -p "$SCRIPTS"
print_text_in_color "$ICyan" "Running the main menu script..."

if network_ok
then
    # Delete, download, run
    run_script MENU main_menu
fi

exit
