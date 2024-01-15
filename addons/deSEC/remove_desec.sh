#!/bin/bash

# T&M Hansson IT AB © - 2024, https://www.hanssonit.se/

true
SCRIPT_NAME="deSEC Removal"
SCRIPT_EXPLAINER="This script lets you remove your deSEC account.\n\nMaybe you want to re-add it again with another domain? In that case this is what you need to run first, since the install script only can handle one email address at the time."
# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh

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

# Final warning before destruction!
msg_box "WARNING!

We will now delete your deSEC account and all the domains that are registered with it. This action is irreversible!

You will now be given the chance to opt out if you wish."

if ! yesno_box_no "Would you like to delete your deSEC account together with $DEDYN_NAME?"
then
    print_text_in_color "$ICyan" "*Peeew* Everything is still intact! :)"
    exit
fi

# Remove domain
print_text_in_color "$ICyan" "Removing $DEDYN_NAME..."
curl -X DELETE https://desec.io/api/v1/domains/"$DEDYN_NAME"/ \
    --header "Authorization: Token $DEDYN_TOKEN"

# Ask for email and password
VALIDEMAIL=$(input_box_flow "Please enter the email address (from the previous screen) for your deSEC account.")
VALIDPASSWD=$(input_box_flow "Please enter the password for your deSEC account.")

# Just some info
msg_box "If the correct credentials has been provided, the server will send you an email with a link of the form:
https://desec.io/api/v1/v/delete-account/<code>/. 

To finish the deletion, click on that link, which then will take you to the deSEC frontend.

The link expires after 12 hours. It is also invalidated by certain other account-related activities, such as changing your email address or password."

# Do the actual removal of the account
while :
do
    if ! curl -fX POST https://desec.io/api/v1/auth/account/delete/ --header "Content-Type: application/json" --data @- <<DELETEACC
    {
      "email": "$VALIDEMAIL",
      "password": "$VALIDPASSWD"
    }
DELETEACC
    then
        msg_box "It seems like the credentials you entered is wrong. You will now be able to try again."
        countdown "Please press CTRL+C to stop trying..." "5"
        # Ask for email and password
        VALIDEMAIL=$(input_box_flow "Please enter the email address for your deSEC account.")
        VALIDPASSWD=$(input_box_flow "Please enter the password for your deSEC account.")
    else
        rm -Rf "$SCRIPTS"/deSEC
        if [ -f "$SITES_AVAILABLE"/"$DEDYN_NAME".conf ]
        then
            a2dissite "$DEDYN_NAME".conf
            service apache2 reload
            rm -f "$SITES_AVAILABLE"/"$DEDYN_NAME".conf
        fi
        msg_box "$DEDYN_NAME, the deSEC account, and the Apache2 config was successfully removed.

If you used a certain port during installation, you can remove that as well in:
/etc/apache2/ports.conf"
        break
    fi
done

# Do you want to install it again?
msg_box "Remember, you can always install deSEC again by running:
sudo bash $SCRIPTS/menu.sh --> Server Configuration --> deSEC"
