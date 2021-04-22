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

msg_box "Please note: If you already created an account with deSEC you can't use the same email address in this script as you won't get an email with a captcha. In that case, please use your already existing account to set up your domain at the deSEC website.

Another option is to use another email address in this setup, and then email the deSEC support that you want to merge your two accounts together, or delete the first one.

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
msg_box "If the registration was successful you should have got an email with a link to configure your auth token.

Please wait up to 5 minutes for the email to arrive."

# Did the user get the email?
if ! yesno_box_yes "Did you receive the email?"
then
    msg_box "OK, please try again later by executing the deSEC script like this:

sudo bash $SCRIPTS/menu.sh --> Server Configuration --> deSEC

Please also email support@desec.io for further support, maybe the subdomain is already in use?"
    exit 1
else
    if ! yesno_box_yes "Great! Did you copy the token you received?"
    then
        msg_box "OK, please copy the token and enter it in the next box after you hit 'OK'"
    fi
fi

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
       msg_box "$DEDYNDOMAIN was successfully set up with deSEC! Now please continue with the DDNS and TLS setup for the domain."
       break
    fi
done

# Ask user if DynDNS should be added to the domain
if yesno_box_yes "Do you want to add automatic updates of your WAN IP using ddclient?
Please note: this will reset any configuration that might be already in place with ddclient."
then
    export DEDYNDOMAIN
    export DEDYNAUTHTOKEN
    run_script NETWORK ddclient-configuration
fi

# Ask if the user wants to add TLS (use script)
if yesno_box_yes "Do you want to set this domain as your Nextcoud domain \
and activate TLS for your Nextcloud using Let's Encrypt?"
then
    # Add DNS renewals with the deSEC hoock script
    print_text_in_color "$ICyan" "Preparing for DNS-renewals..."
    mkdir -p "$SCRIPTS"/deSEC
    curl_to_dir "https://raw.githubusercontent.com/desec-io/desec-certbot-hook/master" "hook.sh" "$SCRIPTS"/deSEC
    chmod +x "$SCRIPTS"/deSEC/hook.sh
    curl_to_dir "https://raw.githubusercontent.com/desec-io/desec-certbot-hook/master" ".dedynauth" "$SCRIPTS"/deSEC
    check_command sed -i "s|DEDYN_TOKEN=.*|DEDYN_TOKEN=$DEDYNAUTHTOKEN|g" "$SCRIPTS"/deSEC/.dedynauth
    check_command sed -i "s|DEDYN_NAME=.*|DEDYN_NAME=$DEDYNDOMAIN|g" "$SCRIPTS"/deSEC/.dedynauth
    msg_box "DNS updates for deSEC are now set. This means you don't have to open any ports (80|443) since deSEC TLS renewals will be run with a built in hook. \
The hook files will end up in $SCRIPTS/deSEC, please don't touch that folder unless you know what you're doing. \
You can read more about it here: https://github.com/desec-io/desec-certbot-hook"

    # Run the TLS script
    run_script LETS_ENC activate-tls
fi

# Make sure they are gone
unset DEDYNDOMAIN
unset DEDYNAUTHTOKEN
