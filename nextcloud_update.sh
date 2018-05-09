#!/bin/bash

# shellcheck disable=2034,2059
true
# shellcheck source=lib.sh
. <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)

# Tech and Me © - 2018, https://www.techandme.se/

network_ok

exit 1

msg_box "Since we migrated the PosgreSQL branch to master on Github the update script from the PostgreSQL branch will be removed soon.
You can read the release note here: https://www.techandme.se/release-note-nextcloud-13-0-2/

When you hit OK we will replace the current update script with the new one and then run the updater again.
This means that you don't have to change anything by yourself, but it could be a good idea to check that our migration worked anyway.

If you experience any bugs, please report them to $ISSUES."

if rm -f $SCRIPTS/update.sh
then
msg_box "The old update.sh couldn't be removed.
Please report this to $ISSUES
fi

download_static_script update

bash $SCRIPTS/update.sh

