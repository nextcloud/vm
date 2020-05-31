#!/bin/bash

# T&M Hansson IT AB © - 2020, https://www.hanssonit.se/

# shellcheck disable=2015,2034,2059
true
# shellcheck source=lib.sh
[ -f /var/scripts/main/lib.sh ] && source /var/scripts/main/lib.sh || . <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)

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
    run_script STATIC main_menu
fi

exit
