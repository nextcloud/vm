#!/bin/sh
#
# Tech and Me, 2016 - www.techandme.se
#
# Secrets
ENCRYPTIONSECRET=$(openssl rand -hex 32)
SESSIONSECRET=$(openssl rand -hex 32)
SERVERTOKEN=$(openssl rand -hex 32)
SHAREDSECRET=$(openssl rand -hex 32)

# Change nextcloud root's dir accordingly
OCDIR="/var/www/nextcloud"

# Change webserver to your needs, apache2, nginx etc
WEB="apache2"
# Make sure this is the right directory for your vhost files and change xxx to your vhost file name
VHOST443="/etc/$WEB/sites-available/xxx"
VHOST80="/etc/$WEB/sites-available/xxx"

# Leave blank for autodiscover
SPREEDDOMAIN=""
SPREEDPORT=""

# Never got 127.0.0.1 to work so LAN IP it is...
lISTENADDRESS="$IP"
lISTENPORT="8080"
IP=$(hostname -I | cut -d ' ' -f 1)

# Check if root
        if [ "$(whoami)" != "root" ]; then
        echo
        echo -e "\e[31mSorry, you are not root.\n\e[0mYou must type: \e[36msudo \e[0mbash install_spreedme_webrtc.sh"
        echo
        exit 1
fi

# Clean and update
apt-get autoclean
apt-get autoremove
apt-get -f install -y
apt-get update
apt-get upgrade -y

# Install spreed (Unstable is used as there are some systemd errors in ubuntu 16.04)
apt-add-repository ppa:strukturag/spreed-webrtc-unstable
apt-get update
apt-get install spreed-webrtc -y

# Change server conf.
sed -i "s|listen = 127.0.0.1:8080|listen = $LISTENADDRESS:$LISTENPORT|g" /etc/spreed/webrtc.conf
sed -i "s|;basePath = /some/sub/path/|basePath = /webrtc/|g" /etc/spreed/webrtc.conf
sed -i "s|;authorizeRoomJoin = false|authorizeRoomJoin = true|g" /etc/spreed/webrtc.conf
sed -i "s|;stunURIs = stun:stun.spreed.me:443|stunURIs = stun:stun.spreed.me:443|g" /etc/spreed/webrtc.conf
sed -i "s|encryptionSecret = tne-default-encryption-block-key|encryptionSecret = $ENCRYPTIONSECRET|g" /etc/spreed/webrtc.conf
sed -i "s|sessionSecret = the-default-secret-do-not-keep-me|sessionSecret = $SESSIONSECRET|g" /etc/spreed/webrtc.conf
sed -i "s|serverToken = i-did-not-change-the-public-token-boo|serverToken = $SERVERTOKEN|g" /etc/spreed/webrtc.conf
sed -i "s|;extra = /usr/share/spreed-webrtc-server/extra|$OCDIR/apps/spreedme/extra|g" /etc/spreed/webrtc.conf
sed -i "s|;plugin = extra/static/myplugin.js|plugin = $OCDIR/apps/spreedme/extra/static/owncloud.js|g" /etc/spreed/webrtc.conf
sed -i "s|enabled = false|enabled = true|g" /etc/spreed/webrtc.conf
sed -i "s|;mode = sharedsecret|mode = sharedsecret|g" /etc/spreed/webrtc.conf
sed -i "s|;sharedsecret_secret = some-secret-do-not-keep|sharedsecret_secret = $SHAREDSECRET|g" /etc/spreed/webrtc.conf

# Change spreed.me config.php
cp $OCDIR/apps/spreedme/config/config.php.in $OCDIR/apps/spreedme/config/config.php
sed -i "s|const SPREED_WEBRTC_ORIGIN = '';|const SPREED_WEBRTC_ORIGIN = '$SPREEDDOMAIN';|g" $OCDIR/apps/spreedme/config/config.php
sed -i "s|const SPREED_WEBRTC_SHAREDSECRET = 'bb04fb058e2d7fd19c5bdaa129e7883195f73a9c49414a7eXXXXXXXXXXXXXXXX';|const SPREED_WEBRTC_SHAREDSECRET = '$SHAREDSECRET';|g" $OCDIR/apps/spreedme/config/config.php

# Change OwnCloudConfig.js
cp $OCDIR/apps/spreedme/extra/static/config/OwnCloudConfig.js.in $OCDIR/apps/spreedme/extra/static/config/OwnCloudConfig.js
sed -i "s|OWNCLOUD_ORIGIN: '',|OWNCLOUD_ORIGIN: 'SPREEDDOMAIN',|g" $OCDIR/apps/spreedme/extra/static/config/OwnCloudConfig.js

# Restart spreed server
service spreedwebrtc restart

# Vhost configuration 443
sed -i 's|</virtualhost>|  <Location /webrtc>\
      ProxyPass http://$LISTENADDRESS:$LISTENPORT/webrtc\
      ProxyPassReverse /\
  </Location>\
\
  <Location /webrtc/ws>\
      ProxyPass ws://$LISTENADDRESS:$LISTENPORT/webrtc/ws\
  </Location>\
\
  ProxyVia On\
  ProxyPreserveHost On\
  RequestHeader set X-Forwarded-Proto 'https' env=HTTPS\
</virtualhost>|g' $VHOST443

# Vhost configuration 80
sed -i 's|</virtualhost>|  <Location /webrtc>\
      ProxyPass http://$LISTENADDRESS:$LISTENPORT/webrtc\
      ProxyPassReverse /\
  </Location>\
\
  <Location /webrtc/ws>\
      ProxyPass ws://$LISTENADDRESS:$LISTENPORT/webrtc/ws\
  </Location>\
\
  ProxyVia On\
  ProxyPreserveHost On\
  RequestHeader set X-Forwarded-Proto 'https' env=HTTPS\
</virtualhost>|g' $VHOST80

# Enable apache2 mods if needed
      	if [ -d /etc/apache2/ ]; then
      	        a2enmod proxy proxy_http proxy_wstunnel headers
      	fi

# Restart webserver
service $WEB reload

# Almost done
echo "Please enable the app in Nextcloud/ownCloud..."
echo
echo "If there are any errors make sure to append /?debug to the url when visiting the spreedme app in the cloud"
echo "This will help us troubleshoot the issues, you could also visit: mydomain.com/index.php/apps/spreedme/admin/debug"

exit 0
