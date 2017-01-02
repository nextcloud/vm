#!/bin/bash
DOMAIN=$(whiptail --title "Techandme.se Collabora" --inputbox "Nextcloud url, make sure it looks like this: cloud\.yourdomain\.com" 10 60 cloud\.yourdomain\.com 3>&1 1>&2 2>&3)
CLEANDOMAIN=$(whiptail --title "Techandme.se Collabora" --inputbox "Nextcloud url, now make sure it look normal" 10 60 cloud.yourdomain.com 3>&1 1>&2 2>&3)
EDITORDOMAIN=$(whiptail --title "Techandme.se Collabora" --inputbox "Collabora subdomain eg: office.yourdomain.com" 10 60 3>&1 1>&2 2>&3)
HTTPS_EXIST="/etc/apache2/sites-available/'$EXISTINGDOMAIN'"
HTTPS_CONF="/etc/apache2/sites-available/'$EDITORDOMAIN'"
SCRIPTS=/var/scripts

# Message
whiptail --msgbox "Please before you start make sure port 443 is directly forwarded to this machine or open!" 20 60 2

# Update & upgrade
apt update
apt upgrade -y
apt -f install -y

# Check if docker is installed
	if [ $(dpkg-query -W -f='${Status}' docker.io 2>/dev/null | grep -c "ok installed") -eq 1 ]; then
				echo "Docker.io is installed..."
else
				apt install docker.io -y
fi

	if [ $(dpkg-query -W -f='${Status}' git 2>/dev/null | grep -c "ok installed") -eq 1 ]; then
				echo "Git is installed..."
else
				apt install git -y
fi


# Install Collabora docker
docker pull collabora/code
docker run -t -d -p 127.0.0.1:9980:9980 -e "domain=$DOMAIN" --restart always --cap-add MKNOD collabora/code

# Install Apache2
	if [ $(dpkg-query -W -f='${Status}' apache2 2>/dev/null | grep -c "ok installed") -eq 1 ];
then
        echo "Apache2 is installed..."
else

    {
    i=1
    while read -r line; do
        i=$(( $i + 1 ))
        echo $i
    done < <(apt install apache2 -y)
    } | whiptail --title "Progress" --gauge "Please wait while installing Apache2" 6 60 0

fi

# Enable Apache2 module's
a2enmod proxy
a2enmod proxy_wstunnel
a2enmod proxy_http
a2enmod ssl

# Create Vhost for Collabora online in Apache2

if [ -f "$HTTPS_CONF" ];
then
        echo "Virtual Host exists"
else

	touch "$HTTPS_CONF"
        cat << HTTPS_CREATE > "$HTTPS_CONF"
<VirtualHost *:443>
  ServerName $EDITORDOMAIN

  # SSL configuration, you may want to take the easy route instead and use Lets Encrypt!
  SSLEngine on
  SSLCertificateFile /path/to/signed_certificate
  SSLCertificateChainFile /path/to/intermediate_certificate
  SSLCertificateKeyFile /path/to/private/key
  SSLProtocol             all -SSLv2 -SSLv3
  SSLCipherSuite ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA256:ECDHE-ECDSA-AES128-SHA:ECDHE-RSA-AES256-SHA384:ECDHE-RSA-AES128-SHA:ECDHE-ECDSA-AES256-SHA384:ECDHE-ECDSA-AES256-SHA:ECDHE-RSA-AES256-SHA:DHE-RSA-AES128-SHA256:DHE-RSA-AES128-SHA:DHE-RSA-AES256-SHA256:DHE-RSA-AES256-SHA:ECDHE-ECDSA-DES-CBC3-SHA:ECDHE-RSA-DES-CBC3-SHA:EDH-RSA-DES-CBC3-SHA:AES128-GCM-SHA256:AES256-GCM-SHA384:AES128-SHA256:AES256-SHA256:AES128-SHA:AES256-SHA:DES-CBC3-SHA:!DSS
  SSLHonorCipherOrder     on

  # Encoded slashes need to be allowed
  AllowEncodedSlashes On

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
  ProxyPassMatch   "/lool/(.*)/ws$"      wss://127.0.0.1:9980/lool/$1/ws
  
  # Admin Console websocket
  ProxyPass   /lool/adminws wss://127.0.0.1:9980/lool/adminws

  # Download as, Fullscreen presentation and Image upload operations
  ProxyPass           /lool https://127.0.0.1:9980/lool
ProxyPassReverse /lool https://127.0.0.1:9980/lool
</VirtualHost>
HTTPS_CREATE

if [ -f "$HTTPS_CONF" ];
then
        echo "$HTTPS_CONF was successfully created"
        sleep 2
else
	echo "Unable to create vhost, exiting..."
	exit
fi

fi

# Let's Encrypt
echo "You now need to create a SSL certificate for the subdomain that will host Collabora..."
sleep 5
wget https://raw.githubusercontent.com/nextcloud/vm/master/lets-encrypt/activate-ssl.sh -P $SCRIPTS
bash activate-ssl.sh
rm activate-ssl.sh






