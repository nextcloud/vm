#!/bin/bash

# Tech and Me © - 2017, https://www.techandme.se/

echo "Installing Netdata..."

# shellcheck disable=2034,2059
true
# shellcheck source=lib.sh
. <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

TALK_CONF="/etc/turnserver.conf"

echo "Installing Talk..."
check_open_port 443
check_open_port 80

# Install TURN
check_command install_if_not coturn

sudo sed -i '/TURNSERVER_ENABLED/c\TURNSERVER_ENABLED=1' /etc/default/coturn

# Generate $HTTP_CONF
if [ ! -f $TALK_CONF ]
then
    touch "$TALK_CONF"
    cat << TALK_CREATE > "$TALK_CONF"
tls-listening-port=443
fingerprint
lt-cred-mech
use-auth-secret
static-auth-secret=<yourChosen/GeneratedSecret>
realm=your.domain.org
total-quota=100
bps-capacity=0
stale-nonce
cert=/path/to/your/cert.pem (same as for nextcloud itself)
pkey=/path/to/your/privkey.pem (same as for nextcloud itself)
dh-file=/path/to/your/dhparams.pem (same as nextcloud)
no-tlsv1
no-tlsv1_1
cipher-list="ECDH+AESGCM:DH+AESGCM:ECDH+AES256:DH+AES256:ECDH+AES128:DH+AES:ECDH+3DES:DH+3DES:RSA+AES:RSA+3DES:!ADH:!AECDH:!MD5"
no-loopback-peers
no-multicast-peers
TALK_CREATE
    echo "TALK_CONF was successfully created"
fi

# Retsart the TURN server
sudo systemctl restart coturn

# Install and enable app from App Store 
install_and_enable_app spreed

# occ_command for setting values in app (check with @mario which ones that are avaliable)
STUN servers: your.domain.org:<yourChosenPortNumber>
TURN server: your.domain.org:<yourChosenPortNumber>
TURN secret: <yourChosen/GeneratedSecret>
UDP and TCP

Do not add http(s):// here, this causes errors, the protocol is simply a different one. Also turn: or something as prefix is not needed. Just enter the bare domain:port.
