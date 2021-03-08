#!/bin/bash

# T&M Hansson IT AB © - 2020, https://www.hanssonit.se/

true
SCRIPT_NAME="deSEC Registration"
SCRIPT_EXPLAINER="This script will automatically register a domain of your liking, and set it to automatically update your external IP address."
# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh || source <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)

# Enter the subdomain
msg_box "Please enter the subdomain (*example*.dedyn.io) that you want to use"
while :
do
    SUBDEDYN=$(input_box_flow "Please enter the subdomain (*example*.dedyn.io) that you want to use \
The only allowed characters for the username are:
'a-z', 'A-Z', and '0-9'")
    if [[ "$SUBDEDYN" == *" "* ]]
    then
        msg_box "Please don't use spaces."
    elif [ "${SUBDEDYN//[A-Za-z0-9]}" ]
    then
        msg_box "Allowed characters for the username are:\na-z', 'A-Z', and '0-9'\n\nPlease try again."
    else
        DEDYNDOMAIN="$SUBDEDYN.dedyn.io"
        # Check for SOA record
        if host -t SOA $DEDYNDOMAIN
        then
            if ! yesno_box_yes "Sorry, but it seems like $DEDYNDOMAIN is taken. Do you want to try again?"
            then
               exit
            fi
        else
            break
        fi
    fi
done

# Email address
msg_box "You will now be prompted to enter an email address. It's very important that the email address you enter it a 100% valid one. deSEC will verify your email address by sending you a verification link.

Every 6 months you will get an email asking you to confrim your domain. If you do not react within a few weeks, your domain will be destroyed!"

VALIDEMAIL=$(input_box_flow "Please enter a valid email address. NOT a fake or a temporary one.")

msg_box "If you later want to log into your deSEC account, you need to set a login password here: https://desec.io/reset-password

You don't need to do this now."

# Register the domain
curl -X POST https://desec.io/api/v1/auth/ \
    --header "Content-Type: application/json" --data @- <<EOF
    {
      "email": "$VALIDEMAIL",
      "password": null,
      "domain": "$DEDYNDOMAIN"
    }
EOF

# Ask user to check email and confirm to get the token
msg_box "If the registration was successful you should have got an email with your auth token.

Please copy that and enter it in the next box after you hit OK."

# Check if DEYNAUTH is valid
while :
do
    DEDYNAUTHTOKEN=$(input_box_flow "Please enter your auth token (update password) for deSEC, exactly as it was displayed (use correct casing, no extra spaces).")
    if [ $(curl -s -o /dev/null -w '%{http_code}' --header "Authorization: Token $DEDYNAUTHTOKEN" https://desec.io/api/v1/auth/account/) -eq 401 ]
    then
        if ! yesno_box_yes "Sorry, but it seems like the auth token (update password) is incorrect. Do you want to try again?"
        then
           exit
        fi
    else
       break
    fi
done

WANIP6=$(curl -s -k -m 5 https://ipv6bot.whatismyipaddress.com)

# Ask user if DynDNS should be added to the domain
if yesno_box_yes "Do you want to add automatic updates of your WAN IP - IPv4 and/or IPv6?"
then
    # Add DynDNS
    curl --user "$DEDYNDOMAIN":"$DEDYNAUTHTOKEN" \
      https://update.dedyn.io/?myipv4="$WANIP4"\&myipv6="$WANIP6"
fi
