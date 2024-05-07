#!/bin/bash
true
SCRIPT_NAME="Test Connection (old)"
# shellcheck source=lib.sh
source <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/main/lib.sh)

# This is needed since we removed this from the startup script, or changed name so it can't be downloaded anymore
msg_box "You are running an outdated release.

You see this message only to make it possible to run the first \
startup script, but as time goes, more and more will we incompatible.

We urge you to download the latest version as soon as possible: https://github.com/nextcloud/vm/releases"

exit
