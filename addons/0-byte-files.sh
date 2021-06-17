#!/bin/bash

# T&M Hansson IT AB © - 2021, https://www.hanssonit.se/
true
SCRIPT_NAME="Check for 0-Byte files"
# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh || source <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)

filesystems[0]="$NCDATA"
cd "$NCDATA"

emSub="Warning: Nextcloud contains 0-Byte files!"

# Function
for fs in "${filesystems[@]}"
do
    while read -d '' -r
    do
        arr+=( "$REPLY\n" )
    done < <(find "$fs" -mindepth 3 -size 0 -print0)
done

# TODO
# Remove known 0-byte files
# Everything in appdata isn't important
# NEWARR="$(echo ${arr[*]} | sed s/'appdata'//)"

# Notify!
if [[ -n "${arr[*]}" ]]
then
    notify_admin_gui "$emSub" "${arr[*]}"
    msg_box "$emSub

Please see files in red when you hit OK."
    print_text_in_color "$IRed" "${arr[*]}"
fi
