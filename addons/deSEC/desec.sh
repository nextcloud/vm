#!/bin/bash

# T&M Hansson IT AB © - 2024, https://www.hanssonit.se/

true
SCRIPT_NAME="deSEC Registration"
SCRIPT_EXPLAINER="This script will automatically register a domain of your liking, secure it with TLS, and set it to automatically update your external IP address with DDNS."
# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh


prompt_dedyn_subdomain(){
# Enter the subdomain
msg_box "Please enter the subdomain (*example*.dedyn.io) that you want to use"
while :
do
    SUBDEDYN=$(input_box_flow "Please enter the subdomain (*example*.dedyn.io) that you want to use \
The only allowed characters for the subdomain are:
'a-z', 'A-Z', and '0-9'")
    if [[ "$SUBDEDYN" == *" "* ]]
    then
        msg_box "Please don't use spaces."
    elif [ "${SUBDEDYN//[A-Za-z0-9]}" ]
    then
        msg_box "Allowed characters for the subdomain are:\na-z', 'A-Z', and '0-9'\n\nPlease try again."
    else
        DEDYNDOMAIN="$SUBDEDYN.dedyn.io"
        break
    fi
done
}

new_domain_email_info_1(){
### TODO, is it possible to check if the email address already exists with deSEC? In that case we could skip this whole info and replace it with a function instead.
# Email address
msg_box "You will now be prompted to enter an email address. It's very important that the email address you enter it a 100% valid one! deSEC will verify your email address by sending you a verification link.

Every 6 months you will get an email asking you to confirm your domain. If you don't react within a few weeks, your domain will be destroyed!

PLEASE NOTE: The email address you enter here, can not already be registered as a valid account with deSEC."
}

existing_account() {
if yesno_box_no "Do you already have an account with deSEC and are able to login?"
then
    msg_box "OK, please login to your account and add a new auth token here: https://desec.io/tokens (https://imgur.com/a/anOpe5t).

When done, please copy that token and add it in the next screen after you hit 'OK'."
else
    return 1
fi
}

prompt_email_address(){
VALIDEMAIL=$(input_box_flow "Please enter the email address that you would like to use for your deSEC account.")
}

new_domain_email_info_2(){
msg_box "If you later want to log into your deSEC account, you need to set a login password here: https://desec.io/reset-password

You don't need to do this now."
}

register_the_domain(){
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
}

received_registration_email_check(){
# Did the user get the email?
if ! yesno_box_yes "Did you receive the email?"
then
    msg_box "OK, please try again later.

Please also email support@desec.io for further support. You can refer to the use of this script."
    aborted_exit_message
else
    if ! yesno_box_yes "Great! Did you copy the token you received?"
    then
        msg_box "OK, please copy the token and enter it in the next box after you hit 'OK'"
    fi
fi
}

prompt_security_token(){
# Check if DEDYNAUTH is valid
while :
do
    DEDYNAUTHTOKEN=$(input_box_flow "Please enter your auth token (update password) for deSEC, exactly as it was displayed (use correct casing, no extra spaces).")
    if [ "$(curl -s -o /dev/null -w '%{http_code}' --header "Authorization: Token $DEDYNAUTHTOKEN" https://desec.io/api/v1/auth/account/)" -eq 401 ]
    then
        if ! yesno_box_yes "Sorry, but it seems like the auth token (update password) is incorrect. Do you want to try again?"
        then
           aborted_exit_message
        fi
    else
       msg_box "$DEDYNDOMAIN was successfully set up with deSEC! Now please continue with the DDNS and TLS setup for the subdomain."
       break
    fi
done
}

prompt_dyndns(){
# Ask user if DynDNS should be added to the subdomain
if yesno_box_yes "Do you want to add automatic updates of your WAN IP using ddclient?
Please note: this will reset any configuration that might be already in place with ddclient."
then
    export DEDYNDOMAIN
    export DEDYNAUTHTOKEN
    run_script NETWORK ddclient-configuration
fi
}

register_domain_existing_account(){
curl -X POST https://desec.io/api/v1/domains/ \
    --header "Authorization: Token $DEDYNAUTHTOKEN" \
    --header "Content-Type: application/json" --data @- <<EOF
    {
      "name": "$DEDYNDOMAIN"
    }
EOF
}

prompt_tls(){
# Ask if the user wants to add TLS (use script)
if yesno_box_yes "Do you want to set this domain as your Nextcoud domain \
and activate TLS for your Nextcloud using Let's Encrypt?"
then
    # Add DNS renewals with the deSEC hoock script
    print_text_in_color "$ICyan" "Preparing for DNS-renewals..."
    mkdir -p "$SCRIPTS"/deSEC
    curl_to_dir "https://raw.githubusercontent.com/nextcloud/vm/main/addons/deSEC" "hook.sh" "$SCRIPTS"/deSEC
    chmod +x "$SCRIPTS"/deSEC/hook.sh
    curl_to_dir "https://raw.githubusercontent.com/nextcloud/vm/main/addons/deSEC" ".dedynauth" "$SCRIPTS"/deSEC
    check_command sed -i "s|DEDYN_TOKEN=.*|DEDYN_TOKEN=$DEDYNAUTHTOKEN|g" "$SCRIPTS"/deSEC/.dedynauth
    check_command sed -i "s|DEDYN_NAME=.*|DEDYN_NAME=$DEDYNDOMAIN|g" "$SCRIPTS"/deSEC/.dedynauth
    msg_box "DNS updates for deSEC are now set. This means you don't have to open any ports (80|443) for the renewal process since deSEC TLS renewals will be run with a built in hook. \
The hook files will end up in $SCRIPTS/deSEC, please don't touch that folder unless you know what you're doing. \
You can read more about it here: https://github.com/desec-io/desec-certbot-hook

Please remember that you still need to open the port you choose to make your server publicly available.
You can read more about that here: http://shortio.hanssonit.se/ffOQOXS6Kh"

    # Run the TLS script
    run_script LETS_ENC activate-tls
fi

}

aborted_exit_message(){
    msg_box "You can run this script again at a later time by using:

sudo bash $SCRIPTS/menu.sh --> Server Configuration --> deSEC"
    exit 1
}

# The magic starts here:
while :
do
    prompt_dedyn_subdomain
    # Check for SOA record
    if host -t SOA "$DEDYNDOMAIN" >/dev/null 2>&1
    then
        # Domain is taken
        msg_box "Sorry, but it seems like $DEDYNDOMAIN is taken."
        if existing_account
        then
            # Register the domain in the existing account
            prompt_security_token
            break
        else
            # The user doesn't have an existing account, ask to try another domain
            if ! yesno_box_yes "Would you like to try another subdomain? Answering 'No' will exit the deSEC/DynDNS/TLS setup."
            then
                aborted_exit_message
            fi
        fi
    else
        # Domain is free and available to register
        if ! existing_account
        then
            # Ask for new account details
            new_domain_email_info_1
            prompt_email_address
            new_domain_email_info_2
            register_the_domain
            received_registration_email_check
            prompt_security_token
            break
        else
            # Register the domain in the existing account --> prompt_for_security_token
            prompt_security_token
            register_domain_existing_account
            break
        fi
    fi
done

# Always ask for DynDNS and TLS
prompt_dyndns
prompt_tls

# Make sure they are gone
unset DEDYNDOMAIN
unset DEDYNAUTHTOKEN
