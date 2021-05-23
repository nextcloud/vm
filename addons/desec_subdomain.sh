source /var/scripts/fetch_lib.sh

if [ -f "$SCRIPTS"/deSEC/.dedynauth ] && [ -f /etc/ddclient.conf ]
then
    DEDYN_TOKEN=$(grep DEDYN_TOKEN "$SCRIPTS"/deSEC/.dedynauth | cut -d '=' -f2)
    DEDYN_NAME=$(grep DEDYN_NAME "$SCRIPTS"/deSEC/.dedynauth | cut -d '=' -f2)
else
    msg_box "It seems like deSEC isn't configured on this server.
Please run sudo bash $SCRIPTS/menu.sh --> Server Configuration --> deSEC to configure it."
    exit 1
fi

# Ask for subdomain
SUBDOMAIN=$(input_box_flow "Please enter the subdomain you are using for $1, e.g: yoursubdomain")

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
        msg_box "$FINAL_SUBDOMAIN was successfully updated."
    else
        msg_box "$FINAL_SUBDOMAIN failed to update, please report this to $ISSUES"
        exit
fi
