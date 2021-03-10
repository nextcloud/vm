#!/bin/bash

# T&M Hansson IT AB © - 2021, https://www.hanssonit.se/

true
SCRIPT_NAME="deSEC Registration"
SCRIPT_EXPLAINER="This script will automatically register a domain of your liking, secure it with TLS, and set it to automatically update your external IP address with DDNS."
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
        if host -t SOA "$DEDYNDOMAIN" >/dev/null 2>&1
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

### TODO, is it possible to check if the email address already exists with deSEC? In that case we could skip this whole info and replace it with a function instead.
# Email address
msg_box "You will now be prompted to enter an email address. It's very important that the email address you enter it a 100% valid one! deSEC will verify your email address by sending you a verification link.

Every 6 months you will get an email asking you to confirm your domain. If you don't react within a few weeks, your domain will be destroyed!"

msg_box "Please note: If you already created an account with deSEC you can't use the same email adress in this script as you won't get an email with a captcha. In that case, please use your already existing account to setup your domain at the deSEC website.

Another option is to use another email address in this setup, and then email the deSEC suport that you want to merge your two accounts together, or delete the first one.

In other words, the email address used in this script has to be uniqe, and can not be registred with deSEC since before."

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

# Check if DEDYNAUTH is valid
while :
do
    DEDYNAUTHTOKEN=$(input_box_flow "Please enter your auth token (update password) for deSEC, exactly as it was displayed (use correct casing, no extra spaces).")
    if [ "$(curl -s -o /dev/null -w '%{http_code}' --header "Authorization: Token $DEDYNAUTHTOKEN" https://desec.io/api/v1/auth/account/)" -eq 401 ]
    then
        if ! yesno_box_yes "Sorry, but it seems like the auth token (update password) is incorrect. Do you want to try again?"
        then
           exit
        fi
    else
       break
    fi
done

# Ask user if DynDNS should be added to the domain
if yesno_box_yes "Do you want to add automatic updates of your WAN IP using ddclient?
Please note: this will reset any configuration that might be already in place with ddclient."
then
    # Add DynDNS
    # WANIP6=$(curl -s -k -m 5 https://ipv6bot.whatismyipaddress.com)
    # curl --user "$DEDYNDOMAIN":"$DEDYNAUTHTOKEN" \
    #   https://update.dedyn.io/?myipv4="$WANIP4"\&myipv6="$WANIP6" >/dev/null 2>&1
    export DEDYNDOMAIN
    export DEDYNAUTHTOKEN
    run_script NETWORK ddclient-configuration
fi

# Ask if the user wants to add TLS (use script)
if yesno_box_yes "Do you want to set this domain as your Nextcoud domain \
and activate TLS for your Nextcloud using Let's Encrypt?"
then
    export DEDYNDOMAIN # Not needed since already exported but added for readability
    run_script LETS_ENC activate-tls
fi

# Make sure they are gone
unset DEDYNDOMAIN
unset DEDYNAUTHTOKEN
