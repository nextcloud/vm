#!/bin/bash

#2022-04-10 platima: Added option to correct date using birthday instead of current system time, failing back to change date if birthday missing
#2022-04-10 platima: Added additional output when using 'list' mode
#2022-04-10 platima: Addded verbose option
#2022-04-11 platima: Updated to confirm to code style and wrapped other outputs in verbose qualifier
#2023-05-04 Customized it to fit the Nextcloud VM

# Usage: ./solvable_files.sh <data_dir> <mysql|pgsql> <db_host> <db_user> <db_pwd> <db_name> <fix,list> <scan,noscan> <use_birthday,dont_use_birthday> <verbose,noverbose>

source /var/scripts/fetch_lib.sh

ncdb

export data_dir="$(realpath "$NCDATA")"
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
function correct_mtime() {
        filepath="$1"

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
                if [ "$db_type" == "mysql" ]
                then
                        mtime_in_db=$(
                                mysql \
                                        --skip-column-names \
                                        --silent \
                                        --host="$db_host" \
                                        --user="$db_user" \
                                        --password="$db_pwd" \
                                        --default-character-set=utf8 \
                                        --execute="\
                                                SELECT mtime
                                                FROM ${dbtableprefix}storages JOIN ${dbtableprefix}filecache ON ${dbtableprefix}storages.numeric_id = ${dbtableprefix}filecache.storage \
                                                WHERE ${dbtableprefix}storages.id='local::$data_dir/' AND ${dbtableprefix}filecache.path=FROM_BASE64('$base64_relative_filepath')" \
                                        "$db_name"
                        )
                elif [ "$db_type" == "pgsql" ]
                then
                        mtime_in_db=$(sudo -u postgres psql nextcloud_db --tuples-only --no-align -c "SELECT mtime FROM ${dbtableprefix}storages JOIN ${dbtableprefix}filecache ON ${dbtableprefix}storages.numeric_id = ${dbtableprefix}filecache.storage WHERE ${dbtableprefix}storages.id='home::$username' AND ${dbtableprefix}filecache.path=CONVERT_FROM(DECODE('$base64_relative_filepath_without_username', 'base64'), 'UTF-8')")
                fi
        else
                if [ "$db_type" == "mysql" ]
                then
                        mtime_in_db=$(
                                mysql \
                                        --skip-column-names \
                                        --silent \
                                        --host="$db_host" \
                                        --user="$db_user" \
                                        --password="$db_pwd" \
                                        --default-character-set=utf8 \
                                        --execute="\
                                                SELECT mtime
                                                FROM ${dbtableprefix}storages JOIN ${dbtableprefix}filecache ON ${dbtableprefix}storages.numeric_id = ${dbtableprefix}filecache.storage \
                                                WHERE ${dbtableprefix}storages.id='home::$username' AND ${dbtableprefix}filecache.path=FROM_BASE64('$base64_relative_filepath_without_username')" \
                                        "$db_name"
                        )
                elif [ "$db_type" == "pgsql" ]
                then
                        mtime_in_db=$(sudo -u postgres psql nextcloud_db --tuples-only --no-align -c "SELECT mtime FROM ${dbtableprefix}storages JOIN ${dbtableprefix}filecache ON ${dbtableprefix}storages.numeric_id = ${dbtableprefix}filecache.storage WHERE ${dbtableprefix}storages.id='home::$username' AND ${dbtableprefix}filecache.path=CONVERT_FROM(DECODE('$base64_relative_filepath_without_username', 'base64'), 'UTF-8')")
                fi
        fi

        if [ "$mtime_in_db" == "" ]
        then
                if [ "$verbose" == "verbose" ]
                then
                        echo "No mtime in database. File not indexed. Skipping $filepath"
                fi
                return
        fi

        if [ "$mtime_in_db" != "$mtime_on_fs" ]
        then
                echo "mtime in database do not match fs mtime (fs: $mtime_on_fs, db: $mtime_in_db). Skipping $filepath"
                return
        fi

        if [ "$action" == "fix" ] && [ -e "$filepath" ]
        then
                if [ "$use_birthday" == "use_birthday" ]
                then
                        newdate=$(stat -c "%w" "$filepath")

                        if [ "$newdate" == "-" ]
                        then
                                if [ "$verbose" == "verbose" ]
                                then
                                        echo "$filepath has no birthday. Using change date."
                                fi

                                newdate=$(stat -c "%z" "$filepath")
                        fi

                        touch -c -d "$newdate" "$filepath"
                else
                        touch -c "$filepath"
                fi

                if [ "$verbose" == "verbose" ]
                then
                        echo mtime for \"$filepath\" updated to \"$(stat -c "%y" "$filepath")\"
                fi

                if [ "$scan_action" == "scan" ]
                then
                        if [ ! -e "./occ" ]
                        then
                                echo "Please run this from the directory containing the 'occ' script if using the 'scan' option"
                                return
                        fi
                        sudo -u "$(stat -c '%U' ./occ)" php ./occ files:scan --quiet --path="$relative_filepath"
                fi
        elif [ "$action" == "list" ] && [ -e "$filepath" ]
        then
                echo -n Would update \"$filepath\" to\
                if [ $use_birthday == "use_birthday" ]
                then
                        echo birthday
                else
                        echo today
                fi
        elif [ ! -e "$filepath" ]
        then
                echo "File or directory $filepath does not exist. Skipping."
                return
        fi
}
export -f correct_mtime

find "$data_dir" -type f ! -newermt "@86400" -exec bash -c 'correct_mtime "$0"' {} \;
