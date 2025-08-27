#!/bin/bash

# T&M Hansson IT AB © - 2024, https://www.hanssonit.se/
true
SCRIPT_NAME="Check for 0-Byte files"
# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh

filesystems[0]="$NCDATA"
cd "$NCDATA"

emSub="Warning: Nextcloud contains 0-Byte files!"

# Info
msg_box "We will now scan $NCDATA for files that are 0-Byte.

A 0-Byte file means that it's empty and probably corrupted/not usable. If you see files that are of importance in this list, you should report it immediately to $ISSUES.

The scan may take very long time depending on the speed of your disks, and the amount of files."

countdown "The scan starts in 3 seconds..." "3"

print_text_in_color "$ICyan" "Scan in progress, please be patient..."

# Function
for fs in "${filesystems[@]}"
do
    while IFS= read -d '' -r
    do
        arr+=( "$REPLY" )
    done < <(find "$fs" -mindepth 3 -size 0 -print0)
done


# TODO
# Remove known 0-byte files
# Everything in appdata isn't important
# NEWARR="$(echo ${arr[*]} | sed s/'appdata'//)"

# Notify!
if [ -n "${arr[*]}" ]
then
    send_mail "$emSub" "${arr[*]}"
    msg_box "$emSub

Please see files in red when you hit OK."
    for each in "${arr[@]}"
    do
      print_text_in_color "$IRed" "$each"
    done
else
    msg_box "No 0-byte files found. *peew*"
fi
