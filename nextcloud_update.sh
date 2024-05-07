#!/bin/bash

# shellcheck disable=2034,2059
true
# shellcheck source=lib.sh
. <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/main/lib.sh)

# Tech and Me © - 2018, https://www.techandme.se/

msg_box "Since we migrated the 'master' branch to 'main' on Github the update script from the 'master' branch will be removed soon.

When you hit OK we will replace the current update script with the new one and then run the updater again.
This means that you don't have to change anything by yourself, but it could be a good idea to check that our migration worked anyway.

If you experience any bugs, please report them to $ISSUES."

download_script STATIC update
chmod +x $SCRIPTS/update.sh
bash $SCRIPTS/update.sh
