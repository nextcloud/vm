#!/bin/bash

# T&M Hansson IT AB © - 2020, https://www.hanssonit.se/

# shellcheck disable=2034,2059
true
# shellcheck source=lib.sh
. <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Check if root
root_check

# Test RAM size (3 GB min) + CPUs (min 2)
ram_check 3 Bitwarden
cpu_check 2 Bitwarden

# Check if Bitwarden is already installed
print_text_in_color "$ICyan" "Checking if Bitwarden is already installed..."
if is_docker_running
then
    if docker ps -a --format '{{.Names}}' | grep -Eq "bitwarden";
    then
        if is_this_installed apache2
        then
            if [ -d /root/bwdata ]
            then
                msg_box "It seems like 'Bitwarden' is already installed.\n\nYou cannot run this script twice, because you would loose all your passwords."
                exit 1
            fi
        fi
    fi
fi

print_text_in_color "$ICyan" "Installing Bitwarden password manager..."

msg_box "Bitwarden is a password manager that is seperate from Nextcloud, though we provide this service because it's self hosted and secure.

If you on the other hand want to run this on a subdomain, then please create a DNS record and point it to this server.
In the process of setting up Bitwarden you will be asked to generate an TLS cert with Let's Enrypt so no need to get your own prior to this setup.

The script is based on this documentation: https://help.bitwarden.com/article/install-on-premise/
It's a good idea to read that before you start this script.

Please also report any issues regarding this script setup to $ISSUES"

msg_box "The necessary preparations to run expose Bitwarden to the internet are:
1. Please open port 443 and 80 and point to this server.
2. Please create a DNS record for your subdomain and point that to this server.
3. Raise the amount of RAM to this server to at least 3 GB."

if [[ "no" == $(ask_yes_or_no "Have you made the necessary preparations?") ]]
then
msg_box "OK, please do the necessary preparations before you run this script and then simply run it again once you're done.

To run this script again, execute $SCRIPTS/menu.sh and choose Additional Apps --> Bitwarden"
    exit
fi

msg_box "ATTENTION!

You will see in the next step a setup which is provided by bitwarden.
You have to make your choices based on the following instructions, 
otherwise things can go wrong since we have no influence on those scripts.
Best is if you take a picture of those instructions so that you remember them later on.
And please don't worry: we will create a valid SSL certificate afterwards ourselves.

1. Enter your subdomain like e.g. 'bitwarden.example.com'
2. You will be asked if you want to use 'lets encrypt'; Please type in no: 'n'
3. Enter your installation ID, which you must get on https://bitwarden.com/host
4. Enter your installation key, which you will also get there
5. You will be asked if you have a SSL certificate which you want to use; Please type in no: 'n'
6. You will be asked if you want to generate a self-signed SSL certificate; Please type in no: 'n'"

# Install Docker
install_docker
install_if_not docker-compose

# Stop Apache to not conflict when LE is run
check_command systemctl stop apache2.service

# Install Bitwarden 
install_if_not curl
cd /root
curl_to_dir "https://raw.githubusercontent.com/bitwarden/core/master/scripts" "bitwarden.sh" "/root"
chmod +x /root/bitwarden.sh
check_command ./bitwarden.sh install
sed -i "s|http_port.*|http_port: 5178|g" /root/bwdata/config.yml
sed -i "s|https_port.*|https_port: 5179|g" /root/bwdata/config.yml
# Get Subdomain from config.yml and change it to https
SUBDOMAIN=$(grep ^url /root/bwdata/config.yml)
SUBDOMAIN=${SUBDOMAIN##*url: http://}
sed -i "s|^url: .*|url: https://$SUBDOMAIN|g" /root/bwdata/config.yml
sed -i 's|http://|https://|g' /root/bwdata/env/global.override.env
check_command ./bitwarden.sh rebuild
check_command ./bitwarden.sh start
check_command ./bitwarden.sh updatedb

# Produce reverse-proxy config and get lets-encrypt certificate

# Curl the lib another time to get the correct HTTPS_CONF
. <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)

# Check if $SUBDOMAIN exists and is reachable
print_text_in_color "$ICyan" "Checking if $SUBDOMAIN exists and is reachable..."
domain_check_200 "$SUBDOMAIN"

# Check open ports with NMAP
check_open_port 80 "$SUBDOMAIN"
check_open_port 443 "$SUBDOMAIN"

# Install Apache2
install_if_not apache2

# Enable Apache2 module's
a2enmod proxy
a2enmod proxy_wstunnel
a2enmod proxy_http
a2enmod ssl

if [ -f "$HTTPS_CONF" ]
then
    a2dissite "$SUBDOMAIN.conf"
    rm -f "$HTTPS_CONF"
fi

if [ ! -f "$HTTPS_CONF" ];
then
    cat << HTTPS_CREATE > "$HTTPS_CONF"
<VirtualHost *:443>
    ServerName $SUBDOMAIN:443
    SSLEngine on
    ServerSignature On
    SSLHonorCipherOrder on
    SSLCertificateChainFile $CERTFILES/$SUBDOMAIN/chain.pem
    SSLCertificateFile $CERTFILES/$SUBDOMAIN/cert.pem
    SSLCertificateKeyFile $CERTFILES/$SUBDOMAIN/privkey.pem
    SSLOpenSSLConfCmd DHParameters $DHPARAMS_SUB
    
    SSLProtocol             all -SSLv2 -SSLv3
    SSLCipherSuite ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA256:ECDHE-ECDSA-AES128-SHA:ECDHE-RSA-AES256-SHA384:ECDHE-RSA-AES128-SHA:ECDHE-ECDSA-AES256-SHA384:ECDHE-ECDSA-AES256-SHA:ECDHE-RSA-AES256-SHA:DHE-RSA-AES128-SHA256:DHE-RSA-AES128-SHA:DHE-RSA-AES256-SHA256:DHE-RSA-AES256-SHA:ECDHE-ECDSA-DES-CBC3-SHA:ECDHE-RSA-DES-CBC3-SHA:EDH-RSA-DES-CBC3-SHA:AES128-GCM-SHA256:AES256-GCM-SHA384:AES128-SHA256:AES256-SHA256:AES128-SHA:AES256-SHA:DES-CBC3-SHA:!DSS
    LogLevel warn
    CustomLog ${APACHE_LOG_DIR}/access.log combined
    ErrorLog ${APACHE_LOG_DIR}/error.log
    # Just in case - see below
    SSLProxyEngine On
    SSLProxyVerify None
    SSLProxyCheckPeerCN Off
    SSLProxyCheckPeerName Off
    # contra mixed content warnings
    RequestHeader set X-Forwarded-Proto "https"
    # basic proxy settings
    ProxyRequests off
    ProxyPassMatch (.*)(\/websocket)$ "ws://127.0.0.1:5178/$1$2"
    ProxyPass / "http://127.0.0.1:5178/"
    ProxyPassReverse / "http://127.0.0.1:5178/"
        
    <Location />
        ProxyPassReverse /
    </Location>
</VirtualHost>
HTTPS_CREATE

    if [ -f "$HTTPS_CONF" ];
    then
        print_text_in_color "$IGreen" "$HTTPS_CONF was successfully created."
        sleep 1
    else
        print_text_in_color "$IRed" "Unable to create vhost, exiting..."
        print_text_in_color "$IRed" "Please report this issue here $ISSUES"
        exit 1
    fi
fi

# Install certbot (Let's Encrypt)
install_certbot

# Generate certs and  auto-configure  if successful
if generate_cert  "$SUBDOMAIN"
then
    # Generate DHparams chifer
    if [ ! -f "$DHPARAMS_SUB" ]
    then
        openssl dhparam -dsaparam -out "$DHPARAMS_SUB" 4096
    fi
    print_text_in_color "$IGreen" "Certs are generated!"
    a2ensite "$SUBDOMAIN.conf"
    restart_webserver
else
    last_fail_tls "$SCRIPTS"/apps/tmbitwarden.sh
fi

# Add prune command
{
echo "#!/bin/bash"
echo "docker system prune -a --force"
echo "exit"
} > "$SCRIPTS/dockerprune.sh"
chmod a+x "$SCRIPTS/dockerprune.sh"
crontab -u root -l | { cat; echo "@weekly $SCRIPTS/dockerprune.sh"; } | crontab -u root -
print_text_in_color "$ICyan" "Docker automatic prune job added."
check_command systemctl start apache2.service

msg_box "Bitwarden was sucessfully installed! Please visit $SUBDOMAIN to setup your account.

# After the account it setup, please disable user registration by running sudo bash $SCRIPTS/menu.sh and choose:
# Additional Apps --> Bitwarden Registration"

exit
