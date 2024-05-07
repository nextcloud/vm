#!/bin/bash

# Based on: https://raw.githubusercontent.com/nextcloud-gmbh/mtime_fixer_tool_kit/main/solvable_files.sh

true
SCRIPT_NAME="Fix 'Could not update metadata due to invalid modified time'."
# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh

# Get needed variables for database management
ncdb

# Check if root
root_check

#2023-05-04 Customized the original script to fit the Nextcloud VM users setup. Also fixed some shellcheck issues.

data_dir="$(realpath "$NCDATA")"
export data_dir
export db_type=$NCDBTYPE
export db_host=$NCDBHOST
export db_user=$NCDBUSER
export db_pwd=$NCDBPASS
export db_name=$NCDB
export action=fix
export scan_action=noscan
export use_birthday=use_birthday
export verbose=verbose

# In case you're using a different database table prefix, set this to your config's `dbtableprefix` value.
export dbtableprefix="oc_"

# 1. Return if fs mtime <= 86400
# 2. Compute username from filepath
# 3. Query mtime from the database with the filename and the username
# 4. Return if mtime_on_fs != mtime_in_db
# 5. Correct the fs mtime with touch (optionally using the files change date/timestamp)
correct_mtime() {
        filepath=$NCDATA

        if [ ! -e "$filepath" ]
        then
            echo "File or directory $filepath does not exist. Skipping."
            return
        fi

        relative_filepath="${filepath/#$data_dir\//}"
        mtime_on_fs="$(stat -c '%Y' "$filepath")"

        username=$relative_filepath
        while [ "$(dirname "$username")" != "." ]
        do
            username=$(dirname "$username")
        done

        relative_filepath_without_username="${relative_filepath/#$username\//}"

        base64_relative_filepath="$(printf '%s' "$relative_filepath" | base64)"
        base64_relative_filepath_without_username="$(printf '%s' "$relative_filepath_without_username" | base64)"

        if [ "$username" == "__groupfolders" ]
        then
            mtime_in_db=$(sudo -u postgres psql nextcloud_db --tuples-only --no-align -c "SELECT mtime FROM ${dbtableprefix}storages JOIN ${dbtableprefix}filecache ON ${dbtableprefix}storages.numeric_id = ${dbtableprefix}filecache.storage WHERE ${dbtableprefix}storages.id='local::$data_dir/' AND ${dbtableprefix}filecache.path=CONVERT_FROM(DECODE('$base64_relative_filepath', 'base64'), 'UTF-8')")
        else
            mtime_in_db=$(sudo -u postgres psql nextcloud_db --tuples-only --no-align -c "SELECT mtime FROM ${dbtableprefix}storages JOIN ${dbtableprefix}filecache ON ${dbtableprefix}storages.numeric_id = ${dbtableprefix}filecache.storage WHERE ${dbtableprefix}storages.id='home::$username' AND ${dbtableprefix}filecache.path=CONVERT_FROM(DECODE('$base64_relative_filepath_without_username', 'base64'), 'UTF-8')")
        fi

        if [ "$mtime_in_db" == "" ]
        then
            echo "No mtime in database. File not indexed. Skipping $filepath"
            return
        fi

        if [ "$mtime_in_db" != "$mtime_on_fs" ]
        then
            echo "mtime in database do not match fs mtime (fs: $mtime_on_fs, db: $mtime_in_db). Skipping $filepath"
            return
        fi

        if [ -e "$filepath" ]
        then
            newdate=$(stat -c "%w" "$filepath")
            if [ "$newdate" == "-" ]
            then
                newdate=$(stat -c "%z" "$filepath")
                touch -c -d "$newdate" "$filepath"
            else
                touch -c "$filepath"
            fi
            echo mtime for "$filepath" updated to "$(stat -c "%y" "$filepath")"
        elif [ ! -e "$filepath" ]
        then
            echo "File or directory $filepath does not exist. Skipping."
            return
        fi
}
export -f correct_mtime

find "$data_dir" -type f ! -newermt "@86400" -exec bash -c 'correct_mtime "$0"' {} \;
