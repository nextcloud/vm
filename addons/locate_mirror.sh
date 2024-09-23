#!/bin/bash

# T&M Hansson IT AB © - 2024, https://www.hanssonit.se/

true
SCRIPT_NAME="Locate mirror"
# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh
SCRIPT_EXPLAINER="To make downloads as fast as possible when updating Ubuntu \
you should download mirrors that are as geographically close to you as possible.

Please note that there are no guarantees that the download mirrors \
this script finds will remain for the lifetime of this server.
Because of this, we don't recommend that you change the mirror unless you live far away from the default.

This is the method used: https://github.com/vegardit/fast-apt-mirror.sh"

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Must be root
root_check

# Check if Locate Mirror is already installed
if ! [ -f /usr/local/bin/fast-apt-mirror ]
then
    # Ask for installing
    install_popup "$SCRIPT_NAME"
else
    # Ask for removal or reinstallation
    reinstall_remove_menu "$SCRIPT_NAME"
    # Removal
    rm -f /usr/local/bin/fast-apt-mirror
    rm -f /etc/apt/sources.list.backup
    # Show successful uninstall if applicable
    removal_popup "$SCRIPT_NAME"
fi

# Install
install_if_not bash
install_if_not curl
install_if_not apt-transport-https
install_if_not ca-certificates
curl_to_dir https://raw.githubusercontent.com/vegardit/fast-apt-mirror.sh/v1/ fast-apt-mirror.sh /usr/local/bin
mv /usr/local/bin/fast-apt-mirror.sh /usr/local/bin/fast-apt-mirror
chmod 755 /usr/local/bin/fast-apt-mirror

# Check current mirror
CURRENT_MIRROR="$(fast-apt-mirror current)"
msg_box "Current mirror is $CURRENT_MIRROR"

# Ask
if ! yesno_box_no "Do you want to try to find a better mirror?"
then
    print_text_in_color "$ICyan" "Keeping $CURRENT_MIRROR as mirror..."
    sleep 1
else
   if [[ "$KEYBOARD_LAYOUT" =~ ,|/|_ ]]
    then
        msg_box "Your keymap (country code) contains more than one language, or a special character. ($KEYBOARD_LAYOUT)
This script can only handle one keymap at the time.\nThe default mirror ($CURRENT_MIRROR) will be kept."
        exit 1
    fi
    # Find
    FIND_MIRROR="$(fast-apt-mirror find -v --healthchecks 100 --speedtests 10 --country "$KEYBOARD_LAYOUT")"
    print_text_in_color "$ICyan" "Locating the best mirrors..."
    if [ "$CURRENT_MIRROR" != "$FIND_MIRROR" ]
    then
        if yesno_box_yes "Do you want to replace the $CURRENT_MIRROR with $FIND_MIRROR?"
        then
            # Backup
            cp -f /etc/apt/sources.list /etc/apt/sources.list.backup
            # Replace
            if fast-apt-mirror set "$FIND_MIRROR"
            then
                msg_box "Your Ubuntu repo was successfully changed to $FIND_MIRROR"
            fi
        fi
    else
        msg_box "You already have the fastest mirror available, congrats!"
    fi
fi
