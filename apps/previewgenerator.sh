#!/bin/bash

# T&M Hansson IT AB © - 2023, https://www.hanssonit.se/
# GNU General Public License v3.0
# https://github.com/nextcloud/vm/blob/master/LICENSE

true
SCRIPT_NAME="Fix LEGACY Preview Generator"
# shellcheck source=lib.sh
source <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)

####### TEMPORARY 2023-04-01 ####### 

run_script APP imaginary
