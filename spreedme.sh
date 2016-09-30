#!/bin/bash
SHAREDSECRET=$(openssl rand -hex 32)
NCDIR="/var/www/nextcloud"
SPREEDDOMAIN=$(whiptail --title "Spreed domain" --inputbox "Leave empty for autodiscovery" 10 60 3>&1 1>&2 2>&3)
SPREEDPORT=""
VHOST443="/etc/apache2/sites-available/nextcloud_ssl_domain_self_signed.conf"
LISTENADDRESS="$ADDRESS"
SPREEDVER_REPO="https://github.com/strukturag/nextcloud-spreedme/master"
SPREED_FILE="nextcloud-spreedme-master.zip"
SPREEDCONF="/etc/spreed/webrtc.conf"

# Install spreed-webrtc
apt-add-repository ppa:strukturag/spreed-webrtc
apt-get update
apt-get install spreed-webrtc unzip -y

# Download and install Spreed
if [ -d $NCDIR/apps/spreedme ]; then
echo "Spreed-webrtc exists..."
else
wget -q $SPREEDVER_REPO -P $NCDIR/apps
unzip -q $NCDIR/apps/$SPREED_FILE -d $NCDIR/apps
mv $NCDIR/apps/nextcloud-spreedme-master $NCDIR/apps/spreedme
rm $NCDIR/apps/$SPREEDVER_FILE
fi

# Enable Spreedme
if [ -d $NCDIR/apps/spreedme ]; then
sudo -u www-data php $NCDIR/occ app:enable spreedme
fi

cat <<-SPREEDCONF > "$SPREEDCONF"
; Minimal Spreed WebRTC for Nextcloud server configuration

[app]
; Change the next four values
sessionSecret = the-default-secret-do-not-keep-me
encryptionSecret = tne-default-encryption-block-key
serverToken = i-did-not-change-the-public-token-boo
extra = /absolute/path/to/nextcloud/apps/spreedme/extra
; Do not change these three values
plugin = extra/static/owncloud.js
authorizeRoomJoin = true
serverRealm = local

[users]
; Only change sharedsecret_secret
sharedsecret_secret = some-secret-do-not-keep
; Do not change these two values
enabled = true
mode = sharedsecret

[http]
; Do not change these two values
listen = 127.0.0.1:8080
basePath = /webrtc/
SPREEDCONF

# Change values
#sed -i "s|listen = 127.0.0.1:8080|listen = $LISTENADDRESS:$LISTENPORT|g" /etc/spreed/webrtc.conf
#sed -i "s|;baseDIR = /some/sub/DIR/|baseDIR = /webrtc/|g" /etc/spreed/webrtc.conf
#sed -i "s|;authorizeRoomJoin = false|authorizeRoomJoin = true|g" /etc/spreed/webrtc.conf
#sed -i "s|;stunURIs = stun:stun.spreed.me:443|stunURIs = stun:stun.spreed.me:443|g" /etc/spreed/webrtc.conf
#sed -i "s|encryptionSecret = .*|encryptionSecret = $ENCRYPTIONSECRET|g" /etc/spreed/webrtc.conf
#sed -i "s|sessionSecret = .*|sessionSecret = $SESSIONSECRET|g" /etc/spreed/webrtc.conf
#sed -i "s|serverToken = .*|serverToken = $SERVERTOKEN|g" /etc/spreed/webrtc.conf
#sed -i "s|;extra = /usr/share/spreed-webrtc-server/extra|extra = $NCDIR/apps/spreedme/extra|g" /etc/spreed/webrtc.conf
#sed -i "s|;plugin = extra/static/myplugin.js|plugin = $NCDIR/apps/spreedme/extra/static/owncloud.js|g" /etc/spreed/webrtc.conf
#sed -i "s|enabled = false|enabled = true|g" /etc/spreed/webrtc.conf
#sed -i "s|;mode = sharedsecret|mode = sharedsecret|g" /etc/spreed/webrtc.conf
#sed -i "s|;sharedsecret_secret = .*|sharedsecret_secret = $SHAREDSECRET|g" /etc/spreed/webrtc.conf

# Change spreed.me config.php
cp "$NCDIR"/apps/spreedme/config/config.php.in "$NCDIR"/apps/spreedme/config/config.php
sed -i "s|const SPREED_WEBRTC_ORIGIN = '';|const SPREED_WEBRTC_ORIGIN = $SPREEDDOMAIN;|g" "$NCDIR"/apps/spreedme/config/config.php
sed -i "s|const SPREED_WEBRTC_SHAREDSECRET = 'bb04fb058e2d7fd19c5bdaa129e7883195f73a9c49414a7eXXXXXXXXXXXXXXXX';|const SPREED_WEBRTC_SHAREDSECRET = '$SHAREDSECRET';|g" "$NCDIR"/apps/spreedme/config/config.php

# Change OwnCloudConfig.js
cp "$NCDIR"/apps/spreedme/extra/static/config/OwnCloudConfig.js.in "$NCDIR"/apps/spreedme/extra/static/config/OwnCloudConfig.js
sed -i "s|OWNCLOUD_ORIGIN: '',|OWNCLOUD_ORIGIN: $SPREEDDOMAIN,|g" "$NCDIR"/apps/spreedme/extra/static/config/OwnCloudConfig.js

# Restart spreed server
service spreedwebrtc restart

# Vhost configuration 443
sed -i 's|</VirtualHost>||g' "$VHOST443"
CAT <<-VHOST >> "$VHOST443"
<Location /webrtc>
      ProxyPass http://"$LISTENADDRESS":"$LISTENPORT"/webrtc
      ProxyPassReverse /webrtc
  </Location>
  <Location /webrtc/ws>
      ProxyPass ws://"$LISTENADDRESS":"$LISTENPORT"/webrtc/ws
  </Location>
  ProxyVia On
  ProxyPreserveHost On
  RequestHeader set X-Forwarded-Proto 'https' env=HTTPS
</VirtualHost>
VHOST

# Enable apache2 mods if needed
      	if [ -d /etc/apache2/ ]; then
      	        a2enmod proxy proxy_http proxy_wstunnel headers
      	fi

# Restart webserver
service apache2 reload

# Almost done
echo
echo "If there are any errors make sure to append /?debug to the url when visiting the spreedme app in the cloud"
echo "This will help us troubleshoot the issues, you could also visit: mydomain.com/index.php/apps/spreedme/admin/debug"
