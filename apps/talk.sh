check_open_port 443
check_open_port 80

## Put talk on a subdomain? E.g. talk.domain.com?

install_if_not coturn

sudo sed -i '/TURNSERVER_ENABLED/c\TURNSERVER_ENABLED=1' /etc/default/coturn

cat EOF /etc/turnserver.conf (WITH TLS)
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
cipher-list="ECDH+AESGCM:DH+AESGCM:ECDH+AES256:DH+AES256:ECDH+AES128:DH+AES:ECDH+3DES:DH+3DES:RSA+AES:RSA+3DES:!ADH:!AECDH:!MD5"
no-loopback-peers
no-multicast-peers
dh-file=/path/to/your/dhparams.pem (same as nextcloud)
no-tlsv1
no-tlsv1_1
---- end of EOF -------

sudo systemctl restart coturn



Configure Nextcloud Talk to use your TURN server
Go to Nextcloud admin panel > Talk settings. Btw. if you already have your own TURN server, you can and may want to use it as STUN server as well:

STUN servers: your.domain.org:<yourChosenPortNumber>
TURN server: your.domain.org:<yourChosenPortNumber>
TURN secret: <yourChosen/GeneratedSecret>
UDP and TCP

Do not add http(s):// here, this causes errors, the protocol is simply a different one. Also turn: or something as prefix is not needed. Just enter the bare domain:port.
