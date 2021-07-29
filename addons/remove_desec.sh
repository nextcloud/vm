#!/bin/bash

# T&M Hansson IT AB © - 2021, https://www.hanssonit.se/

true
SCRIPT_NAME="deSEC Registration"
SCRIPT_EXPLAINER="This script will automatically register a domain of your liking, secure it with TLS, and set it to automatically update your external IP address with DDNS."
# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh || source <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)




# Do the actual removal
curl -X POST https://desec.io/api/v1/auth/account/delete/ \
    --header "Content-Type: application/json" --data @- <<< \
    '{"email": "youremailaddress@example.com", "password": "yourpassword"}'
