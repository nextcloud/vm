#!/bin/bash
# Collabora auto installer

## Variable's
# Docker URL
DOMAIN=$(whiptail --title "Techandme.se Collabora" --inputbox "Nextcloud url, make sure it looks like this: cloud\\.yourdomain\\.com" "$WT_HEIGHT" "$WT_WIDTH" cloud\\.yourdomain\\.com 3>&1 1>&2 2>&3)
# Letsencrypt domains (we need to find a solution to add this Letsencrypt request to the main request for the NC domain)
CLEANDOMAIN=$(whiptail --title "Techandme.se Collabora" --inputbox "Nextcloud url, now make sure it look normal" "$WT_HEIGHT" "$WT_WIDTH" cloud.yourdomain.com 3>&1 1>&2 2>&3)
EDITORDOMAIN=$(whiptail --title "Techandme.se Collabora" --inputbox "Collabora subdomain eg: office.yourdomain.com" "$WT_HEIGHT" "$WT_WIDTH" 3>&1 1>&2 2>&3)
# Vhosts
HTTPS_EXIST="/etc/apache2/sites-available/$CLEANDOMAIN.conf"
HTTPS_CONF="/etc/apache2/sites-available/$EDITORDOMAIN.conf"
# Letsencrypt
LETSENCRYPTPATH=/etc/letsencrypt
CERTFILES=$LETSENCRYPTPATH/live
# WANIP
WANIP4=$(dig +short myip.opendns.com @resolver1.opendns.com)
# Misc
SCRIPTS=/var/scripts

# Whiptail auto size
calc_wt_size() {
  WT_HEIGHT=17
  WT_WIDTH=$(tput cols)

  if [ -z "$WT_WIDTH" ] || [ "$WT_WIDTH" -lt 60 ]; then
    WT_WIDTH=80
  fi
  if [ "$WT_WIDTH" -gt 178 ]; then
    WT_WIDTH=120
  fi
  WT_MENU_HEIGHT=$((WT_HEIGHT-7))
}

# Notification
whiptail --msgbox "Please before you start make sure port 443 is directly forwarded to this machine or open!" "$WT_HEIGHT" "$WT_WIDTH"

# Check if 443 is open using nmap, if not notify the user
if [ $(dpkg-query -W -f='${Status}' nmap 2>/dev/null | grep -c "ok installed") -eq 1 ]; then
      echo "nmap is already installed..."
      clear
else
    apt install nmap -y
fi

if [ $(nmap -sS -p 443 "$WANIP4" | grep -c "open") -eq 1 ]; then
  echo "Port is open"
  apt remove --purge nmap -y
else
  whiptail --msgbox "Port 443 is not open..." "$WT_HEIGHT" "$WT_WIDTH"
  apt remove --purge nmap -y
  exit
fi

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
  ServerName $EDITORDOMAIN:443

  # SSL configuration, you may want to take the easy route instead and use Lets Encrypt!
  SSLEngine on
  SSLCertificateChainFile $CERTFILES/$CLEANDOMAIN/chain.pem
  SSLCertificateFile $CERTFILES/$CLEANDOMAIN/cert.pem
  SSLCertificateKeyFile $CERTFILES/$CLEANDOMAIN/privkey.pem
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

# Stop Apache to aviod port conflicts
a2dissite 000-default.conf
sudo service apache2 stop

############################### Still need to rewrite test-new-config.sh for collabora domain and add more tries for letsencrypt
# Generate certs
cd /etc
git clone https://github.com/certbot/certbot.git
cd /etc/certbot
./letsencrypt-auto certonly --agree-tos --standalone -d $CLEANDOMAIN
# Check if $certfiles exists
if [ -d "$HTTPS_CONF" ]
then
    echo -e "\e[96m"
    echo -e "Certs are generated!"
else
    echo -e "\e[96m"
    echo -e "It seems like no certs were generated, please upload your logs to https://github.com/nextcloud/vm"
    echo -e "\e[32m"
    read -p "Press any key to continue... " -n1 -s
    echo -e "\e[0m"
fi
