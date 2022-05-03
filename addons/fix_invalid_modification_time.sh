#!/bin/bash

# T&M Hansson IT AB © - 2022, https://www.hanssonit.se/

true
SCRIPT_NAME="Fix 'Could not update metadata due to invalid modified time'."
# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh || source <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)

# Check if root
root_check

msg_box "This is an attempt to automate a fix for the nasty bug from the Desktop Client:
https://github.com/nextcloud/desktop/wiki/How-to-fix-the-error-invalid-or-negative-modification-date#-how-to-fix-it

Please only run this if you made a backup."

if ! yesno_box_no "Have you made a backup?"
then
    exit 1
fi

msg_box "OK, let's go! 

Please note, this script might take several hours to run, depening on the size of your datadir. Don't abort it!"

# Download the script
curl_to_dir https://raw.githubusercontent.com/nextcloud-gmbh/mtime_fixer_tool_kit/master solvable_files.sh $NCPATH

# Run all the needed variables
ncdb

if [[ $NCDBTYPE = mysql ]]
then
    msg_box "We only support PostgreSQL, sorry!"
    exit
fi

# Run the script and remove it
print_text_in_color "$ICyan" "Running the scan and fixing broken files..."
bash "$NCPATH"/solvable_files.sh "$NCDATA" "$NCDBTYPE" "$NCDBHOST" "$NCDBUSER" "$NCDBPASS" "$NCDB" fix use_birthday verbose
rm "$NCPATH"/solvable_files.sh

# Scan all files
nextcloud_occ files:scan --all
