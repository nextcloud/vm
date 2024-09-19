#!/bin/bash

# T&M Hansson IT AB © - 2024, https://www.hanssonit.se/

true
SCRIPT_NAME="Locate Mirror"
# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh

# Must be root
root_check

# Check where the best mirrors are and update
msg_box "To make downloads as fast as possible when updating Ubuntu \
you should download mirrors that are as geographically close to you as possible.

Please note that there are no guarantees that the download mirrors \
this script finds will remain for the lifetime of this server.
Because of this, we don't recommend that you change the mirror unless you live far away from the default.

This is the method used: https://github.com/vegardit/fast-apt-mirror.sh"

# Install
install_if_not bash
install_if_not curl
install_if_not apt-transport-https
install_if_not ca-certificates
curl_to_dir https://raw.githubusercontent.com/vegardit/fast-apt-mirror.sh/v1/ fast-apt-mirror.sh /usr/local/bin
mv /usr/local/bin/fast-apt-mirror.sh /usr/local/bin/fast-apt-mirror
chmod 755 /usr/local/bin/fast-apt-mirror

# Variables
CURRENT_MIRROR=$(fast-apt-mirror current)
FIND_MIRROR=$(fast-apt-mirror find -v --healthchecks 100)
msg_box "Current mirror is $CURRENT_MIRROR"

# Ask
if ! yesno_box_no "Do you want to try to find a better mirror?"
then
    print_text_in_color "$ICyan" "Keeping $CURRENT_MIRROR as mirror..."
    sleep 1
else
    # Find
    print_text_in_color "$ICyan" "Locating the best mirrors..."
    if [ "$CURRENT_MIRROR/" != "$FIND_MIRROR" ]
    then
        if yesno_box_yes "Do you want to replace the $CURRENT_MIRROR with $FIND_MIRROR?"
        then
            # Backup
            cp -f /etc/apt/sources.list /etc/apt/sources.list.backup
            # Replace
            if fast-apt-mirror current --apply # TODO is fast-apt-mirror.sh set better here?
            then
                msg_box "Your Ubuntu repo was successfully changed to $FASTEST_MIRROR"
            fi
        fi
    else
        msg_box "You already have the fastest mirror available, congrats!"
    fi
fi
