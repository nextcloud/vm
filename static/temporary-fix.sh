#!/bin/bash

# T&M Hansson IT AB © - 2020, https://www.hanssonit.se/

# shellcheck disable=2015,2034,2059
true
# shellcheck source=lib.sh
[ -f /var/scripts/main/lib.sh ] && source /var/scripts/main/lib.sh || . <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Must be root
root_check

# Fix SMB issues (https://github.com/nextcloud/server/issues/20622)
# git_apply_patch 20941 server 18.0.4

if [ -d "$NC_APPS_PATH"/files_external/3rdparty/icewind/smb ]
then
    print_text_in_color "$ICyan" "Adding temporary fix for SMB bug..."
    rm -Rf "$NC_APPS_PATH"/files_external/3rdparty/icewind/smb
    cd "$NC_APPS_PATH"/files_external/3rdparty/icewind/
    install_if_not git
    git clone https://github.com/icewind1991/SMB.git smb
    bash "$SECURE"
fi
exit
