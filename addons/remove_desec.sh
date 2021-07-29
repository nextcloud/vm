#!/bin/bash

# T&M Hansson IT AB © - 2021, https://www.hanssonit.se/

true
SCRIPT_NAME="deSEC Removal"
SCRIPT_EXPLAINER="This script lets you remove your deSEC account.\n\nMaybe you want to re-add it again with another domain? In that case this is what you need to run first, since the install script only can handle one email address at the time."
# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh || source <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Must be root
root_check

# Check if desec is installed
if ! is_desec_installed
then
    exit
fi

# Check if account exists
if ! curl -sfX GET https://desec.io/api/v1/auth/account/ \
    --header "Authorization: Token $DEDYN_TOKEN"
then
    msg_box "It seems like your account doesn't exist.
Please run 'sudo bash $SCRIPTS/menu.sh --> Server Configuration --> deSEC' to configure it."
else
    msg_box "Your deSEC account information:\n\n$(curl -X GET https://desec.io/api/v1/auth/account/ --header "Authorization: Token $DEDYN_TOKEN")

Please copy the email address."
fi

# Ask for email and password
VALIDEMAIL=$(input_box_flow "Please enter the email address (from the previous screen) for your deSEC account.")
VALIDPASSWD=$(input_box_flow "Please enter the password for your deSEC account.")

# Just some info
msg_box "If the correct password has been provided, the server will send you an email with a link of the form https://desec.io/api/v1/v/delete-account/<code>/. To finish the deletion, click on that link (which will direct you to deSEC frontend).

The link expires after 12 hours. It is also invalidated by certain other account-related activities, such as changing your email address or password.

If your account still contains domains, the server will respond with 409 Conflict and not delete your account."

exit

# Do the actual removal
while :
do
    if ! curl -X POST https://desec.io/api/v1/auth/account/delete/ --header "Content-Type: application/json" --data @- <<< '{"email": "$VALIDEMAIL", "password": "$VALIDPASSWD"}'
    then
        msg_box "It seems like the password is wrong. You will now be able to try again."
        countdown "Please press CTRL+C to stop trying..." "5"
    fi
done
