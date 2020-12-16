#!/bin/bash

# T&M Hansson IT AB © - 2020, https://www.hanssonit.se/

true
SCRIPT_NAME="deSEC Registration"
SCRIPT_EXPLAINER="This script will automatically register a domain of your liking, and set it to automatically update your external IP address."
# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh || source <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)

# Maybe move to lib?
DEDYNPASS==$(gen_passwd "$SHUF" "a-zA-Z0-9")

# Enter the subdomain 
msg_box "Please enter the subdomain (*example*.dedyn.io) that you want to use"
while :
do
    SUBDEDYN=$(input_box_flow "Please enter the subdomain (*example*.dedyn.io) that you want to use
The only allowed characters for the username are:
'a-z', 'A-Z', and '0-9'")
    if [[ "$SUBDEDYN" == *" "* ]]
    then
        msg_box "Please don't use spaces."
    elif [ "${SUBDEDYN//[A-Za-z0-9]}" ]
    then
        msg_box "Allowed characters for the username are:\na-z', 'A-Z', and '0-9'\n\nPlease try again."
    else
        DEDYNDOMAIN=$SUBDEDYN.dedyn.io
        break
    fi
done

# Email address
msg_box "You will now be prompted to enter an email adress. It's very important that the email adress you enter it a 100% valid one.

Every 6 months you will get an email asking you to confrim your domain. If deSeC doesn't get an answer within 3 weeks, you domain will be destroyed!"

VALIDEMAIL=$(input_box_flow "Please enter a valid email adress. NOT a fake or a temporary one."

msg_box "Your account for deSEC password is $DEDYNPASS. Please write this down now."

# Register the domain
curl -X POST https://desec.io/api/v1/auth/ \
    --header "Content-Type: application/json" --data @- <<EOF
    {
      "email": "$VALIDEMAIL",
      "password": "$DEDYNPASS",
      "captcha": {
        "id": "00010203-0405-0607-0809-0a0b0c0d0e0f",
        "solution": "12H45"
      },
      "domain": "$DEDYNDOMAIN"
    }
EOF

# Ask user to check email and confirm to get the token
msg_box "If the registration was sucessful you should have got an email with your auth token.

Please copy that and enter it in the next box after you hit OK.

DEDYNAUTHTOKEN=$(input_box_flow "Please enter your auth token for deSEC, please make sure it's valid!")

# Ask user if DynDNS should be added to the domain
if ! ask_yes_no "Do you want to add automatic updates of your WAN IP (IPv4 and/or IPv6)?
then
    # Add DynDNS
    curl --user $DEDYNDOMAIN.dedyn.io:$AUTHTOKEN \
      https://update.dedyn.io/?myipv4=$WANIP4&myipv6=fd08::1234

    curl https://update6.dedyn.io/?hostname=$DEDYNDOMAIN?myipv4=$WANIP4&myipv6=fd08::1234 \
      --header "Authorization: Token $AUTHTOKEN"
fi
