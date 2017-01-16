#!/bin/bash

SSL_CONF=/etc/apache2/sites-available/nextcloud_ssl_domain_self_signed.conf
LETSENCRYPTPATH=/etc/letsencrypt
CERTFILES=$LETSENCRYPTPATH/live
WANIP4=$(dig +short myip.opendns.com @resolver1.opendns.com)

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

echo "Are you gonna use Let's Encrypt for your server?"
read answer
if [[ $answer == y* ]]; then
    echo "Great. You'll need domain DNS settings preconfigured."
	# Get domain for cleandomain and editordomain
	echo "Have you preconfigured DNS for your domain already?"
	read answer
	if [[ $answer == y* ]]; then
		echo "Great. You'll need domain DNS settings preconfigured."
		echo "Please set nextcloud server domain (e.g. my.nextcloudserver.com):"
		read cleandomain
		echo "Please set CODE domain (e.g. office.nextcloudserver.com):"
		read editordomain
			#Check if DNS resolves to IP server - Fails :-/
			echo "Let's check if this resolves DNS"
			#if [ grep -q -P "$WANIP4" < <(dig +short $cleandomain ) ] && [ grep -q -P "$WANIP4" < <(dig +short $editordomain ) ]; then
				#echo -e "Your IP and DNS for: \n$cleandomain\n$editordomain\nseems valid."
				#Get Let's encrypt & certs
				service apache2 stop
				cd /etc
				git clone https://github.com/certbot/certbot.git
				cd /etc/certbot
				./letsencrypt-auto certonly --apache --agree-tos --standalone -d $editordomain -d $cleandomain
				
			#	else
			#		echo "Your IP and DNS doesn't match, or requieres more time to propagate."
			#		echo "Please check those settings before continuing. Exiting."
			#	exit 0
			#fi
	else
		echo "Need to configure it before we start. Exiting."
		exit
	fi    
else
    #Use own domain SSL certs
    echo "Do you have an Internet domain and SSL certs already setup?"
	read answer
	if [[ $answer == y* ]]; then
		echo "Great. You'll need domain DNS settings preconfigured."
		echo "Please set nextcloud server domain (e.g. my.nextcloudserver.com):"
		read cleandomain
		echo "Please set CODE domain (e.g. office.nextcloudserver.com):"
		read editordomain
			#Check if DNS resolves to IP server
			echo "Let's check if this resolves DNS"
			#if [ grep -q -P "$WANIP4" < <(dig +short $cleandomain ) ] || [ grep -q -P "$WANIP4" < <(dig +short $editordomain ) ]; then
			#		echo -e "Your IP and DNS for: \n$cleandomain\n$editordomain\nseems valid."
					#Get certs path
					echo "Please write the location of the $cleandomain SSL Cert (.crt/.pem)"
					read CLEANDOMAIN_CERT
					echo "Please write the location of the $cleandomain SSL Key (.key/.pem)"
					read CLEANDOMAIN_KEY
					echo "Please write the location of the $cleandomain SSL Bundle (.pem)"
					read CLEANDOMAIN_BUNDLE
			#		if [ -f $CLEANDOMAIN_CERT ] || [ -f $CLEANDOMAIN_KEY ] || [ -f $CLEANDOMAIN_BUNDLE ]; then
						echo "The ssl certs for $cleandomain seems to be there"
					fi
					echo "Please write the path for $editordomain SSL Cert (.crt/.pem)"
					read EDITORDOMAIN_CERT
					echo "Please write the path for $editordomain SSL Key (.key/.pem)"
					read EDITORDOMAIN_KEY
					echo "Please write the path for $editordomain SSL Bundle (.pem)"
					read EDITORDOMAIN_BUNDLE
					if [ -f $EDITORDOMAIN_CERT ] || [ -f $EDITORDOMAIN_KEY ] || [ -f $EDITORDOMAIN_BUNDLE ]; then
						echo "The ssl certs for $EDITORDOMAIN seems to be there. We're done cheking for certs. Let's continue."
					fi
				else
					echo "Your IP and DNS doesn't match, or requieres more time to propagate."
					echo "Please check those settings. Exiting."
				exit 0
			fi
	else
		echo "Need to configure it before we start. Exiting."
		exit
	fi
    
fi

HTTPS_EXIST=/etc/apache2/sites-available/$cleandomain.conf
HTTPS_CONF=/etc/apache2/sites-available/$editordomain.conf

# Enable Apache2 module's
a2enmod proxy
a2enmod proxy_wstunnel
a2enmod proxy_http
a2enmod ssl

# Create Vhost for Collabora online in Apache2
if [ -f "$HTTPS_CONF" ]; then
        echo "Virtual Host exists"
else
	if [ -f "$EDITORDOMAIN_CERT" ] || [ -f "$EDITORDOMAIN_KEY" ] || [ -f "$EDITORDOMAIN_BUNDLE" ]; then
	EditorSSLCert="  SSLCertificateChainFile $EDITORDOMAIN_BUNDLE
  SSLCertificateFile $EDITORDOMAIN_CERT
  SSLCertificateKeyFile $EDITORDOMAIN_KEY"
	else
	EditorSSLCert="  SSLCertificateChainFile $CERTFILES/$editordomain/chain.pem
  SSLCertificateFile $CERTFILES/$editordomain/cert.pem
  SSLCertificateKeyFile $CERTFILES/$editordomain/privkey.pem"
	fi
	touch "$HTTPS_CONF"
        cat << HTTPS_CREATE > "$HTTPS_CONF"
<VirtualHost *:443>
  ServerName $editordomain:443

  # SSL configuration, you may want to take the easy route instead and use Lets Encrypt!
  SSLEngine on
  $EditorSSLCert
  SSLProtocol             all -SSLv2 -SSLv3
  SSLCipherSuite ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA256:ECDHE-ECDSA-AES128-SHA:ECDHE-RSA-AES256-SHA384:ECDHE-RSA-AES128-SHA:ECDHE-ECDSA-AES256-SHA384:ECDHE-ECDSA-AES256-SHA:ECDHE-RSA-AES256-SHA:DHE-RSA-AES128-SHA256:DHE-RSA-AES128-SHA:DHE-RSA-AES256-SHA256:DHE-RSA-AES256-SHA:ECDHE-ECDSA-DES-CBC3-SHA:ECDHE-RSA-DES-CBC3-SHA:EDH-RSA-DES-CBC3-SHA:AES128-GCM-SHA256:AES256-GCM-SHA384:AES128-SHA256:AES256-SHA256:AES128-SHA:AES256-SHA:DES-CBC3-SHA:!DSS
  SSLHonorCipherOrder     on

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
  ProxyPassMatch "/lool/(.*)/ws$" wss://127.0.0.1:9980/lool/$1/ws nocanon
  
  # Admin Console websocket
  ProxyPass   /lool/adminws wss://127.0.0.1:9980/lool/adminws

  # Download as, Fullscreen presentation and Image upload operations
  ProxyPass           /lool https://127.0.0.1:9980/lool
  ProxyPassReverse /lool https://127.0.0.1:9980/lool
</VirtualHost>
HTTPS_CREATE
fi

cp $SSL_CONF $HTTPS_EXIST
a2ensite $cleandomain.conf

#Set up SSL $CLEANDOMAIN
sed -i '$d' $HTTPS_EXIST | sed -i '$d' $HTTPS_EXIST | sed -i '$d' $HTTPS_EXIST
if [ -f $CLEANDOMAIN_CERT ] || [ -f $CLEANDOMAIN_KEY ] || [ -f $CLEANDOMAIN_BUNDLE ]; then
	sed -i "s/ServerName example.com/ServerName $cleandomain/g" $HTTPS_EXIST
	sed -i "35 i SSLCertificateFile $CLEANDOMAIN_CERT" $HTTPS_EXIST
	sed -i "36 i SSLCertificateKeyFile $CLEANDOMAIN_KEY" $HTTPS_EXIST
	sed -i "37 i SSLCertificateChainFile $CLEANDOMAIN_BUNDLE" $HTTPS_EXIST
	sed -i "38 i <\/VirtualHost>" $HTTPS_EXIST 
elif [ -f "$CERTFILES/$editordomain/cert.pem" ] || [ -f "$CERTFILES/$editordomain/privkey.pem" ] || [ -f "$CERTFILES/$editordomain/chain.pem" ];then
	sed -i "s/ServerName example.com/ServerName $cleandomain/g" $HTTPS_EXIST
	sed -i "35 i SSLCertificateFile $CERTFILES/$editordomain/cert.pem" $HTTPS_EXIST
	sed -i "36 i SSLCertificateKeyFile $CERTFILES/$editordomain/privkey.pem" $HTTPS_EXIST
	sed -i "37 i SSLCertificateChainFile $CERTFILES/$editordomain/chain.pem" $HTTPS_EXIST
	sed -i "38 i </VirtualHost>" $HTTPS_EXIST
else
	echo "There seems to be an error with your SSL Certs you'll need to configure it manually."
fi

service apache2 restart

# Update & upgrade
apt update -q
apt upgrade -y -q
apt -f install -y -q

echo "Please write the nextcloud server domain exiting dots with backslashes"
echo 'e.g.: my\\.nextcloudserver\\.com'
read DOMAIN

# Install Collabora docker
docker pull collabora/code
docker run -t -d -p 127.0.0.1:9980:9980 -e "domain=$DOMAIN" --restart always --cap-add MKNOD collabora/code

