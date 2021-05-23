#!/bin/bash

# T&M Hansson IT AB © - 2021, https://www.hanssonit.se/
# SwITNet Ltd © - 2021, https://switnet.net/

true
SCRIPT_NAME="deSEC Subdomain"
SCRIPT_EXPLAINER="This script enables you to add a subdomain to your existing deSEC domain.

You need to have a deSEC account already configured for this to work. If you don't already have an account configured, please run:
sudo bash $SCRIPTS/menu.sh --> Server Configuration --> deSEC"
# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh || source <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Must be root
root_check

if [ ! -f "$SCRIPTS"/deSEC/.dedynauth ]
then
    if [ ! -f /etc/ddclient.conf ]
    then
        DEDYN_TOKEN=$(grep DEDYN_TOKEN "$SCRIPTS"/deSEC/.dedynauth | cut -d '=' -f2)
        DEDYN_NAME=$(grep DEDYN_NAME "$SCRIPTS"/deSEC/.dedynauth | cut -d '=' -f2)
    else
        msg_box "It seems like deSEC isn't configured on this server.
Please run sudo bash $SCRIPTS/menu.sh --> Server Configuration --> deSEC to configure it."
        exit 1
    fi
fi

# Function for adding a RRset (subddomain)
add_desec_subdomain() {
curl -X POST https://desec.io/api/v1/domains/"$DEDYN_NAME"/rrsets/ \
        --header "Authorization: Token $DEDYN_TOKEN" \
        --header "Content-Type: application/json" --data @- <<EOF
    {
      "subname": "$SUBDOMAIN",
      "type": "A",
      "ttl": 60,
      "records": ["127.0.0.1"]
    }
EOF
}

delete_desec_subdomain() {
curl -X DELETE https://desec.io/api/v1/domains/"$DEDYN_NAME"/rrsets/ \
    --header "Authorization: Token DEDYN_TOKEN" \
    --header "Content-Type: application/json" --data @- <<EOF
    {
      "subname": "$SUBDOMAIN",
      "type": "A",
      "ttl": 60,
      "records": [""]},
    }
EOF
}

# Both deSEC and ddclient are required for this to work
if ! curl -X GET https://desec.io/api/v1/domains/"$DEDYN_NAME"/ \
    --header "Authorization: Token $DEDYN_TOKEN"
then
    # Ask for installing
    install_popup "$SCRIPT_NAME"
else
    # Ask for removal or reinstallation
    reinstall_remove_menu "$SCRIPT_NAME"
    # Ask for subdomain to delete
    SUBDOMAIN=$(input_box_flow "Please enter the subdomain you want to delete, e.g: yoursubdomain")
    # Delete the subdomain, but wait for throttling if it's there
    while :
    do
        if grep -r "throttled" | delete_desec_subdomain
        then
            print_text_in_color "$IRed" "Still throttling..."
            msg_box "To avoid throttling, we're now waiting for 5 minutes to be able to delete the domain..."
            countdown "Waiting for throttling to end, please wait for the script to continue..." "600"
            delete_desec_subdomain
        else
            break
        fi
    done
    # Show successful uninstall if applicable
    removal_popup "$SCRIPT_NAME"
fi

# Ask for subdomain to add
SUBDOMAIN=$(input_box_flow "Please enter the subdomain you want to add, e.g: yoursubdomain")

# Add the subdomain, but wait for throttling if it's there
while :
do
    if grep -r "throttled" | add_desec_subdomain
    then
        print_text_in_color "$IRed" "Still throttling..."
        msg_box "To avoid throttling, we're now waiting for 5 minutes to be able to add the domain..."
        countdown "Waiting for throttling to end, please wait for the script to continue..." "600"
        add_desec_subdomain
    else
        break
    fi
done

# Export the final subdomain for use in other scripts
export FINAL_SUBDOMAIN="$SUBDOMAIN.$DEDYN_NAME"

# Add domain to ddclient
if grep -q "$DEDYN_NAME" /etc/ddclient.conf
then
    echo "$FINAL_SUBDOMAIN" >> /etc/ddclient.conf
    systemctl restart ddclient
    if ddclient -syslog -noquiet -verbose -force
    then
        msg_box "$FINAL_SUBDOMAIN was successfully added and updated."
    else
        msg_box "$FINAL_SUBDOMAIN failed to update, please report this to $ISSUES"
        exit
    fi
fi
