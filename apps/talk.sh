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

TALK_CONF="/etc/turnserver.conf"

echo "Installing Talk..."
check_open_port 443 $TALKDOMAIN
check_open_port 80 $TALKDOMAIN

# Install Apache2
install_if_not apache2

# Enable Apache2 module's
a2enmod proxy
a2enmod proxy_wstunnel
a2enmod proxy_http
a2enmod ssl

# Create Vhost for Talk online in Apache2 (Taken from Collabora, edit values later)
if [ ! -f "$TALKPROXY_CONF" ];
then
    cat << TALKPROXY_CREATE > "$TALKPROXY_CONF"
<VirtualHost *:443>
  ServerName $TALKDOMAIN:443
  
  <Directory /var/www>
  Options -Indexes
  </Directory>
  # SSL configuration, you may want to take the easy route instead and use Lets Encrypt!
  SSLEngine on
  SSLCertificateChainFile $CERTFILES/$TALKSUBDOMAIN/chain.pem
  SSLCertificateFile $CERTFILES/$TALKSUBDOMAIN/cert.pem
  SSLCertificateKeyFile $CERTFILES/$TALKSUBDOMAIN/privkey.pem
  SSLOpenSSLConfCmd DHParameters $DHPARAMS
  SSLProtocol             all -SSLv2 -SSLv3
  SSLCipherSuite ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA256:ECDHE-ECDSA-AES128-SHA:ECDHE-RSA-AES256-SHA384:ECDHE-RSA-AES128-SHA:ECDHE-ECDSA-AES256-SHA384:ECDHE-ECDSA-AES256-SHA:ECDHE-RSA-AES256-SHA:DHE-RSA-AES128-SHA256:DHE-RSA-AES128-SHA:DHE-RSA-AES256-SHA256:DHE-RSA-AES256-SHA:ECDHE-ECDSA-DES-CBC3-SHA:ECDHE-RSA-DES-CBC3-SHA:EDH-RSA-DES-CBC3-SHA:AES128-GCM-SHA256:AES256-GCM-SHA384:AES128-SHA256:AES256-SHA256:AES128-SHA:AES256-SHA:DES-CBC3-SHA:!DSS
  SSLHonorCipherOrder     on
  SSLCompression off
  # Encoded slashes need to be allowed
  AllowEncodedSlashes NoDecode
  # Container uses a unique non-signed certificate
  SSLProxyEngine On
  SSLProxyVerify None
  SSLProxyCheckPeerCN Off
  SSLProxyCheckPeerName Off
  # keep the host
  ProxyPreserveHost On
  # static html, js, images, etc. served from loolwsd
  # loleaflet is the client part of LibreOffice Online
  ProxyPass           /loleaflet https://127.0.0.1:9980/loleaflet retry=0
  ProxyPassReverse    /loleaflet https://127.0.0.1:9980/loleaflet
  # WOPI discovery URL
  ProxyPass           /hosting/discovery https://127.0.0.1:9980/hosting/discovery retry=0
  ProxyPassReverse    /hosting/discovery https://127.0.0.1:9980/hosting/discovery
  # Main websocket
  ProxyPassMatch "/lool/(.*)/ws$" wss://127.0.0.1:9980/lool/\$1/ws nocanon
  # Admin Console websocket
  ProxyPass   /lool/adminws wss://127.0.0.1:9980/lool/adminws
  # Download as, Fullscreen presentation and Image upload operations
  ProxyPass           /lool https://127.0.0.1:9980/lool
  ProxyPassReverse    /lool https://127.0.0.1:9980/lool
</VirtualHost>
TALKPROXY_CREATE

    if [ -f "$TALKPROXY_CONF" ];
    then
        echo "$TALKPROXY_CONF was successfully created"
        sleep 1
    else
        echo "Unable to create vhost, exiting..."
        echo "Please report this issue here $ISSUES"
        exit 1
    fi
fi

# Generate certs
if le_subdomain
then
    # Generate DHparams chifer
    if [ ! -f "$DHPARAMS" ]
    then
        openssl dhparam -dsaparam -out "$DHPARAMS" 4096
    fi
    printf "${ICyan}\n"
    printf "Certs are generated!\n"
    printf "${Color_Off}\n"
    a2ensite "$TALKDOMAIN.conf"
    service apache2 restart
# Install Collabora App
    occ_command app:install spreed
else
    printf "${ICyan}\nIt seems like no certs were generated, please report this issue here: $ISSUES\n"
    any_key "Press any key to continue... "
    service apache2 restart
fi

# Enable Spreed (Talk)
if [ -d "$NC_APPS_PATH"/spreed ]
then
# Enable Talk
    occ_command app:enable spreed
    # occ_command for setting values in app
    #STUN servers: your.domain.org:<yourChosenPortNumber>
    #TURN server: your.domain.org:<yourChosenPortNumber>
    #TURN secret: <yourChosen/GeneratedSecret>
    #UDP and TCP
    chown -R www-data:www-data "$NC_APPS_PATH"
    occ_command config:system:set trusted_domains 4 --value="$SUBDOMAIN"
fi

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
cert=$CERTFILES/$TALKSUBDOMAIN/cert.pem
pkey=$CERTFILES/$TALKSUBDOMAIN/privkey.pem
dh-file=$DHPARAMS
no-tlsv1
no-tlsv1_1
cipher-list="ECDH+AESGCM:DH+AESGCM:ECDH+AES256:DH+AES256:ECDH+AES128:DH+AES:ECDH+3DES:DH+3DES:RSA+AES:RSA+3DES:!ADH:!AECDH:!MD5"
no-loopback-peers
no-multicast-peers
TALK_CREATE
    echo "TALK_CONF was successfully created"
fi

# Restart the TURN server
check_command systemctl restart coturn
