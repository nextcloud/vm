#!/bin/bash

# T&M Hansson IT AB © - 2024, https://www.hanssonit.se/

true
SCRIPT_NAME="deSEC Subdomain"
SCRIPT_EXPLAINER="This script enables you to add a subdomain to your existing deSEC domain.

You can also remove existing subdomains (RRsets) with this script. If you want to remove, please choose 'Uninstall' in the next menu."
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

# Check if the subdomain is valid
while :
do
    # Ask for subdomain
    if [ -z "$SUBDOMAIN" ]
    then
        SUBDOMAIN=$(input_box_flow "Please enter the subdomain you want to add or delete, e.g: yoursubdomain")
        # Check if subdomain contains a dot
        if echo "$SUBDOMAIN" | grep '\.' >/dev/null 2>&1
        then
            msg_box "Please *only* enter the subomain name like 'yoursubdomain', not 'yoursubdomain.yourdomain.io'."
        else
            break
        fi
    else
        break
    fi
done

# Function for adding an RRset (subddomain)
add_desec_subdomain() {
curl -X POST https://desec.io/api/v1/domains/"$DEDYN_NAME"/rrsets/ \
        --header "Authorization: Token $DEDYN_TOKEN" \
        --header "Content-Type: application/json" --data @- <<EOF
    {
      "subname": "$SUBDOMAIN",
      "type": "CNAME",
      "ttl": 3600,
      "records": ["$DEDYN_NAME."]
    }
EOF
}

# Function for deleting an RRset (subddomain)
delete_desec_subdomain() {
curl -X DELETE https://desec.io/api/v1/domains/"$DEDYN_NAME"/rrsets/"$SUBDOMAIN"/CNAME/ \
    --header "Authorization: Token $DEDYN_TOKEN"
}

# Function for checking if an RRset (subddomain) exists
check_desec_subdomain() {
curl https://desec.io/api/v1/domains/"$DEDYN_NAME"/rrsets/"$SUBDOMAIN"/CNAME/ \
    --header "Authorization: Token $DEDYN_TOKEN"
}

## Reinstall menu BEGIN
# Check the subdomain exist within the domain
if check_desec_subdomain | grep -qPo "Not found"
then
    # Ask for installing
    install_popup "$SCRIPT_NAME"
else
    # Ask for removal or reinstallation
    reinstall_remove_menu "$SCRIPT_NAME"
    # Delete the subdomain, but wait for throttling if it's there
    while :
    do
        if delete_desec_subdomain | grep -qPo "throttled"
        then
            print_text_in_color "$IRed" "Still throttling..."
            msg_box "To avoid throttling, we're now waiting for 5 minutes to be able to delete $SUBDOMAIN.$DEDYN_NAME..."
            countdown "Waiting for throttling to end, please wait for the script to continue..." "600"
        else
            break
        fi
    done
    # Remove from DDclient
    ddclientdomain="$(grep "$SUBDOMAIN" /etc/ddclient.conf)"
    for delete in $ddclientdomain
        do sed -i "/$delete/d" /etc/ddclient.conf
    done
    systemctl restart ddclient
    # Revoke cert if any
    if [ -f "$CERTFILES/$SUBDOMAIN.$DEDYN_NAME/cert.pem" ]
    then
        yes no | certbot revoke --cert-path "$CERTFILES/$SUBDOMAIN.$DEDYN_NAME/cert.pem"
        REMOVE_OLD="$(find "$LETSENCRYPTPATH/" -name "$SUBDOMAIN*")"
        for remove in $REMOVE_OLD
            do rm -rf "$remove"
        done
    fi
    # Remove from final subdomain
    final_subdomain="$(grep "$SUBDOMAIN" "$SCRIPTS"/deSEC/.subdomain)"
    for delete in $final_subdomain
        do sed -i "/$delete/d" "$SCRIPTS"/deSEC/.subdomain
    done
    # Show successful uninstall if applicable
    removal_popup "$SCRIPT_NAME"
fi
## Reinstall menu END

# Add the subdomain, but wait for throttling if it's there
while :
do
    if add_desec_subdomain | grep -qPo "throttled"
    then
        print_text_in_color "$IRed" "Still throttling..."
        msg_box "To avoid throttling, we're now waiting for 5 minutes to be able to add $SUBDOMAIN.$DEDYN_NAME..."
        countdown "Waiting for throttling to end, please wait for the script to continue..." "600"
    else
        break
    fi
done

# Export the final subdomain for use in other scripts
FINAL_SUBDOMAIN="$SUBDOMAIN.$DEDYN_NAME"
echo "FINAL_SUBDOMAIN=$SUBDOMAIN.$DEDYN_NAME" >> "$SCRIPTS"/deSEC/.subdomain

# Restart and force update of DDNS
if grep -q "$DEDYN_NAME" /etc/ddclient.conf
then
    systemctl restart ddclient
    if ddclient -syslog -noquiet -verbose -force
    then
        msg_box "$FINAL_SUBDOMAIN was successfully added and updated."
    else
        msg_box "$FINAL_SUBDOMAIN failed to update, please report this to $ISSUES"
        exit
    fi
fi

# Add TLS
if yesno_box_yes "Would you like to secure $FINAL_SUBDOMAIN with TLS?"
then
    if generate_desec_cert "$FINAL_SUBDOMAIN"
    then
        msg_box "Congrats! You should now be able to use $FINAL_SUBDOMAIN for setting up Talk, Collabora, OnlyOffice and other apps in Nextcloud.

Please remember to add the port number to the domain, if you chose a custom one, like this: $FINAL_SUBDOMAIN:portnumber"
    fi
fi
