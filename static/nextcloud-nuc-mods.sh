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
pm.max_children = 307
pm.start_servers = 20
pm.min_spare_servers = 10
pm.max_spare_servers = 277

# Change instructions.sh

# Change index.php

