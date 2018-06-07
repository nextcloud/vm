#!/bin/bash

# Tech and Me © - 2018, https://www.techandme.se/

# shellcheck disable=2034,2059
true
# shellcheck source=lib.sh
. <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Move to lib.sh
TURN_CONF="/etc/turnserver.conf"
TURN_PORT=587 
TURN_SECRET="$(cat /dev/urandom | tr -dc a-zA-Z0-9 | fold -w 64 | head -n 1)"
TURN_DOMAIN="$(occ_command config:system:get overwrite.cli.url | sed 's#https://##;s#/##')"

# Check if Nextcloud is installed
echo "Checking if Nextcloud is installed..."
if ! curl -s https://"${NCDOMAIN//\\/}"/status.php | grep -q 'installed":true'
then
msg_box "It seems like Nextcloud is not installed or that you don't use https on:
${NCDOMAIN//\\/}.
Please install Nextcloud and make sure your domain is reachable, or activate SSL
on your domain to be able to run this script.
If you use the Nextcloud VM you can use the Let's Encrypt script to get SSL and activate your Nextcloud domain.
When SSL is activated, run these commands from your terminal:
sudo wget $APP/talk.sh
sudo bash talk.sh"
    exit 1
fi

echo "Installing Talk..."
check_open_port "$TURN_PORT" "$TURN_DOMAIN"

# Enable Spreed (Talk)
if [ -d "$NC_APPS_PATH"/spreed ]
then
# Enable Talk
    occ_command app:enable spreed
    STUN_SERVERS_STRING="[\"$TURN_DOMAIN:$TURN_PORT\"]"
    TURN_SERVERS_STRING="[{\"server\":\"$TURN_DOMAIN:$TURN_PORT\",\"secret\":\"$TURN_SECRET\",\"protocols\":\"udp,tcp\"}]"
    occ_command config:app:set spreed stun_servers --value="$STUN_SERVERS_STRING" --update-only --output json
    occ_command config:app:set spreed turn_servers --value="$TURN_SERVERS_STRING" --update-only --output json
    chown -R www-data:www-data "$NC_APPS_PATH"
fi

# Install TURN
check_command install_if_not coturn
sudo sed -i '/TURNSERVER_ENABLED/c\TURNSERVER_ENABLED=1' /etc/default/coturn

# Generate $TURN_CONF
cat << TURN_CREATE > "$TURN_CONF"
tls-listening-port=$TURN_PORT
fingerprint
lt-cred-mech
use-auth-secret
static-auth-secret=$TURN_SECRET
realm=$TURN_DOMAIN
total-quota=100
bps-capacity=0
stale-nonce
cert=$CERTFILES/$TURN_DOMAIN/cert.pem
pkey=$CERTFILES/$TURN_DOMAIN/privkey.pem
dh-file=$CERTFILES/$TURN_DOMAIN/dhparam.pem
cipher-list="ECDH+AESGCM:DH+AESGCM:ECDH+AES256:DH+AES256:ECDH+AES128:DH+AES:ECDH+3DES:DH+3DES:RSA+AES:RSA+3DES:!ADH:!AECDH:!MD5"
no-loopback-peers
no-multicast-peers
no-tlsv1
no-tlsv1_1
no-stdout-log
simple-log
log-file=/var/log/turnserver.log
TURN_CREATE
echo "TURN_CONF was successfully created"

# Restart the TURN server
check_command systemctl restart coturn
