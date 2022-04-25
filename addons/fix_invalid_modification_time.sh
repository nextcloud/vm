#!/bin/bash

# T&M Hansson IT AB © - 2022, https://www.hanssonit.se/

true
SCRIPT_NAME="Fix 'Could not update metadata due to invalid modified time'."
# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh || source <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)

# Check if root
root_check

# Download the script
curl_to_dir https://raw.githubusercontent.com/nextcloud-gmbh/mtime_fixer_tool_kit/master solvable_files.sh $NCPATH

# Run all the needed variables
ncdb

if [[ $NCDBTYPE = mysql ]]
then
    msg_box "We only support PostgreSQL, sorry!"
    exit
fi

# Run the script
./$NCPATH/solvable_files.sh $NCDATA "$NCDBTYPE" "$DBHOST" "$NCCONFIGDBUSER" "$NCCONFIGDBPASS" "$NCCONFIGDB" fix use_birthday verbose

# Scan all files
nextcloud_occ files:scan --all
