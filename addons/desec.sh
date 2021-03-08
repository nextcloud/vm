#!/bin/bash

# T&M Hansson IT AB © - 2020, https://www.hanssonit.se/

true
SCRIPT_NAME="deSEC Registration"
SCRIPT_EXPLAINER="This script will automatically register a domain of your liking, and set it to automatically update your external IP address."
# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh || source <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)

# Maybe move to lib

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
    fi
    # Check for SOA record
    if ! host -t SOA $DEDYNDOMAIN
    then
        msg_box "Sorry, but it seems like $DEDYNDOMAIN is taken. Please try with another domain."
    else
        break
    fi
done

# Email address
msg_box "You will now be prompted to enter an email address. It's very important that the email address you enter it a 100% valid one.

Every 6 months you will get an email asking you to confrim your domain. If deSeC doesn't get an answer within 3 weeks, you domain will be destroyed!"

VALIDEMAIL=$(input_box_flow "Please enter a valid email address. NOT a fake or a temporary one.")

msg_box "If you want to enter your account, please reset your password here:

https://desec.io/reset-password"

# Register the domain
curl -X POST https://desec.io/api/v1/auth/ \
    --header "Content-Type: application/json" --data @- <<EOF
    {
      "email": "$VALIDEMAIL",
      "password": null,
      },
      "domain": "$DEDYNDOMAIN"
    }
EOF

# Ask user to check email and confirm to get the token
msg_box "If the registration was successful you should have got an email with your auth token.

Please copy that and enter it in the next box after you hit OK."

DEDYNAUTHTOKEN=$(input_box_flow "Please enter your auth token for deSEC, please make sure it's valid!")

# Ask user if DynDNS should be added to the domain
if yesno_box_yes "Do you want to add automatic updates of your WAN IP - IPv4 and/or IPv6?"
then
    # Add DynDNS
    curl --user "$DEDYNDOMAIN":"$AUTHTOKEN" \
      https://update.dedyn.io/?myipv4="$WANIP4"\&myipv6=$WANIP6 \
      --header "Authorization: Token $DEDYNAUTHTOKEN"
fi
