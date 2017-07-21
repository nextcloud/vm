#!/bin/bash

# Tech and Me © - 2017, https://www.techandme.se/

# shellcheck disable=2034,2059
true
# shellcheck source=lib.sh
. <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/postgresql/lib.sh)

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

exists="$(crontab -l -u www-data | grep -q 'preview'  && echo 'yes' || echo 'no')"
if [ "$exists" = "yes" ]
then
    sleep 1
else
    # Install preview generator
    run_app_script previewgenerator
    bash $SECURE & spinner_loading
fi

exit
