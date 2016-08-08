#!/bin/sh
#
# Tech and Me, 2016 - www.techandme.se
# Whiptail menu to install various Nextcloud app and do other useful stuf.
##### Index ######
#- 1 Variable
#- 1.1 Network
#- 1.2 Collabora
#- 1.3 Spreed-webrtc
#- 1.4 Whiptail
#- 1.5 Root check
#- 1.6 Ask to reboot
#- 1.7 
#- 1.8
#- 1.9
#- 2 Apps
#- 2.1 Collabora
#- 2.2 Spreed-webrtc
#- 2.3 Gpxpod
#- 2.4
#- 2.5
#- 2.6
#- 3 Tools
#- 3.1 Show LAN details
#- 3.2 Show WAN details
#- 3.3 Change Hostname
#- 3.4 Internationalisation
#- 3.5 Connect to WLAN
#- 3.6 Raspberry specific
#- 3.61 Resize root fs
#- 3.62 External USB HD
#- 3.63 RPI-update
#- 3.7 Show folder size
#- 3.8 Show folder content with permissions
#- 3.9 Show connected devices
#- 3.10 Show disks usage
#- 3.11 Show system performance
#- 3.12 Disable IPV6
#- 3.13 
#- 4 About this tool
#- 5 Tech and Tool

################################################ Variable 1
################################ Network 1.1

IFCONFIG=$(ifconfig)
IP="/sbin/ip"
IFACE=$($IP -o link show | awk '{print $2,$9}' | grep "UP" | cut -d ":" -f 1)
INTERFACES="/etc/network/interfaces"
ADDRESS=$($IP route get 1 | awk '{print $NF;exit}')
NETMASK=$(ifconfig $IFACE | grep Mask | sed s/^.*Mask://)
GATEWAY=$($IP route | awk '/default/ { print $3 }')

################################ Collabora variable 1.2

HTTPS_CONF="/etc/apache2/sites-available/$EDITORDOMAIN"
DOMAIN=$(whiptail --title "Techandme.se Collabora" --inputbox "Nextcloud url, make sure it looks like this: office\.yourdomain\.com" $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT 3>&1 1>&2 2>&3)
EDITORDOMAIN=$(whiptail --title "Techandme.se Collabora" --inputbox "Collabora subdomain eg: office.yourdomain.com" $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT 3>&1 1>&2 2>&3)

################################ Spreed-webrtc variable 1.3 

DOMAIN=$(whiptail --title "Techandme.se Collabora online installer" --inputbox "Nextcloud url, make sure it looks like this: cloud\.nextcloud\.com" $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT 3>&1 1>&2 2>&3)
NCDIR=$(whiptail --title "Nextcloud directory" --inputbox "eg. /var/www/nextcloud" $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT 3>&1 1>&2 2>&3)
WEB=$(whiptail --title "What webserver do you run" --inputbox "eg. apache2" $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT 3>&1 1>&2 2>&3)
SPREEDDOMAIN=$(whiptail --title "Spreed domain" --inputbox "Leave empty for autodiscovery" $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT 3>&1 1>&2 2>&3)
SPREEDPORT=$(whiptail --title "Spreed port" --inputbox "Leave empty for autodiscovery" $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT 3>&1 1>&2 2>&3)
VHOST443=$(whiptail --title "Vhost 443 file location" --inputbox "eg. /etc/$WEB/sites-available/nextcloud_ssl_domain_self_signed.conf or /etc/$WEB/sites-available/$WEB/sites-available/" $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT 3>&1 1>&2 2>&3)
#VHOST80="/etc/$WEB/sites-available/xxx"
lISTENADDRESS="$ADDRESS"
lISTENPORT="$SPREEDPORT"

################################ Whiptail size 1.4

calc_wt_size() {
  WT_HEIGHT=17
  WT_WIDTH=$(tput cols)

  if [ -z "$WT_WIDTH" ] || [ "$WT_WIDTH" -lt 60 ]; then
    WT_WIDTH=80
  fi
  if [ "$WT_WIDTH" -gt 178 ]; then
    WT_WIDTH=120
  fi
  WT_MENU_HEIGHT=$(($WT_HEIGHT-7))
}

################################################ Whiptail check 1.5

	if [ $(dpkg-query -W -f='${Status}' whiptail 2>/dev/null | grep -c "ok installed") -eq 1 ];
then
        sleep 0

else

    {
    i=1
    while read -r line; do
        i=$(( $i + 1 ))
        echo $i
    done < <(apt-get install whiptail -y)
    } | whiptail --title "Progress" --gauge "Please wait while installing Whiptail" 6 60 0

fi

################################################ Check if root 1.6

if [ "$(whoami)" != "root" ]; then
        whiptail --msgbox "Sorry you are not root. You must type: sudo bash techandtool.sh" 20 60 1
        exit
fi

################################################ Ask to reboot 1.7

ASK_TO_REBOOT=0

do_finish() {
  if [ $ASK_TO_REBOOT -eq 1 ]; then
    whiptail --yesno "Would you like to reboot now?" 20 60 2
    if [ $? -eq 0 ]; then # yes
      sync
      reboot
    fi
  fi
  exit 0
}

################################################ Locations 1.8

REPO="https://github.com/ezraholm50/vm/raw/master"
SCRIPTS="/var/scripts"

################################################ Apps 2

do_apps() {
  FUN=$(whiptail --title "Tech and Tool - https://www.techandme.se" --menu "Apps" $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT \
    "T1 Collabora" "Docker" \
    "T2 Spreed-webrtc" "Spreedme" \
    "T3 Gpxpod" "" \
    3>&1 1>&2 2>&3)
  RET=$?
  if [ $RET -eq 1 ]; then
    return 0
  elif [ $RET -eq 0 ]; then
    case "$FUN" in
      T1\ *) do_collabora ;;
      T2\ *) do_spreed_webrtc ;;
      T3\ *) do_gpxpod ;;
      *) whiptail --msgbox "Programmer error: unrecognized option" 20 60 1 ;;
    esac || whiptail --msgbox "There was an error running option $FUN" 20 60 1
  fi
}

################################ Collabora 2.1

do_collabora() {
# Message
whiptail --msgbox "Please before you start make sure port 443 is directly forwarded to this machine or open!" 20 60 2

# Update & upgrade
    {
    i=1
    while read -r line; do
        i=$(( $i + 1 ))
        echo $i
    done < <(apt-get update && apt-get upgrade -y && apt-get -f install -y)
    } | whiptail --title "Progress" --gauge "Please wait while updating repo's" 6 60 0

# Check if docker is installed

	if [ $(dpkg-query -W -f='${Status}' docker.io 2>/dev/null | grep -c "ok installed") -eq 1 ];
then
        sleep 0

else
    {
    i=1
    while read -r line; do
        i=$(( $i + 1 ))
        echo $i
    done < <(apt-get install docker.io -y)
    } | whiptail --title "Progress" --gauge "Please wait while installing docker" 6 60 0
fi

# Install Collabora docker

docker pull collabora/code
docker run -t -d -p 127.0.0.1:9980:9980 -e "domain=$DOMAIN" --restart always --cap-add MKNOD collabora/code

# Install Apache2

	if [ $(dpkg-query -W -f='${Status}' apache2 2>/dev/null | grep -c "ok installed") -eq 1 ];
then
        sleep 0

else

    {
    i=1
    while read -r line; do
        i=$(( $i + 1 ))
        echo $i
    done < <(apt-get install apache2 -y)
    } | whiptail --title "Progress" --gauge "Please wait while installing Apache2" 6 60 0

fi

# Enable Apache2 module's

a2enmod proxy
a2enmod proxy_wstunnel
a2enmod proxy_http
a2enmod ssl

# Create Vhost for Collabora online in Apache2

if [ -f $HTTPS_CONF ];
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
  ProxyPass   /lool/ws      wss://127.0.0.1:9980/lool/ws

  # Admin Console websocket
  ProxyPass   /lool/adminws wss://127.0.0.1:9980/lool/adminws

  # Download as, Fullscreen presentation and Image upload operations
  ProxyPass           /lool https://127.0.0.1:9980/lool
  ProxyPassReverse    /lool https://127.0.0.1:9980/lool
</VirtualHost>
HTTPS_CREATE

if [ -f $HTTPS_CONF ];
then
        echo "$HTTPS_CONF was successfully created"
        sleep 2
else
	echo "Unable to create vhost, exiting..."
	exit
fi

fi

# Restart Apache2
service apache2 restart

# Firewall -- not needed for it to work
#if (whiptail --title "Test Yes/No Box" --yes-button "Firewall" --no-button "No Firewall"  --yesno "Do you have a firewall enabled?" 10 60) then
#    echo "You chose yes..."

#if (whiptail --title "Test Yes/No Box" --yes-button "UFW" --no-button "IPtables"  --yesno "Do you have UFW or IPtables enabled?" 10 60) then
#    echo "You chose UFW..."
#        sudo ufw allow 9980
#else
#    echo "You chose IPtables... Please file a PR to add a rule for IPtables."
#fi

#else
#    echo "You chose no, it is highly recommended that you use a firewall! Enable it by typing: sudo ufw enable && sudo ufw allow 9980."
#fi

# Let's Encrypt
##### START FIRST TRY
# Stop Apache to aviod port conflicts
        a2dissite 000-default.conf
        sudo service apache2 stop
# Check if $letsencryptpath exist, and if, then delete.
if [ -d "$letsencryptpath" ]; then
  	rm -R $letsencryptpath
fi
# Generate certs
	cd $dir_before_letsencrypt
	git clone https://github.com/letsencrypt/letsencrypt
	cd $letsencryptpath
        ./letsencrypt-auto certonly --standalone -d $EDITORDOMAIN
# Use for testing
#./letsencrypt-auto --apache --server https://acme-staging.api.letsencrypt.org/directory -d EXAMPLE.COM
# Activate Apache again (Disabled during standalone)
        service apache2 start
        a2ensite 000-default.conf
        service apache2 reload
# Check if $certfiles exists
if [ -d "$certfiles" ]; then
# Activate new config
	sed -i "s|SSLCertificateKeyFile /path/to/private/key|SSLCertificateKeyFile $certfiles/$EDITORDOMAIN/privkey.pem|g"    
	sed -i "s|SSLCertificateFile /path/to/signed_certificate|SSLCertificateFile $certfiles/$EDITORDOMAIN/cert.pem|g"
	sed -i "s|SSLCertificateChainFile /path/to/intermediate_certificate|SSLCertificateChainFile $certfiles/$EDITORDOMAIN/chain.pem|g"
        service apache2 restart
        bash /var/scripts/test-new-config.sh
# Message
whiptail --msgbox "\
Succesfully installed Collabora online docker, now please head over to your Nextcloud apps and admin panel
and enable the Collabora online connector app and change the URL to whatever subdomain you choose to run Collabora on.\
" $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT

	exit 0
else
        echo -e "\e[96m"
        echo -e "It seems like no certs were generated, we do three more tries."
        echo -e "\e[32m"
        read -p "Press any key to continue... " -n1 -s
        echo -e "\e[0m"
fi

##### START SECOND TRY
# Check if $letsencryptpath exist, and if, then delete.
	if [ -d "$letsencryptpath" ]; then
  	rm -R $letsencryptpath
fi

# Generate certs
	cd $dir_before_letsencrypt
	git clone https://github.com/letsencrypt/letsencrypt
	cd $letsencryptpath
	./letsencrypt-auto -d $EDITORDOMAIN

# Check if $certfiles exists
if [ -d "$certfiles" ]; then
# Activate new config
	sed -i "s|SSLCertificateKeyFile /path/to/private/key|SSLCertificateKeyFile $certfiles/$EDITORDOMAIN/privkey.pem|g"    
	sed -i "s|SSLCertificateFile /path/to/signed_certificate|SSLCertificateFile $certfiles/$EDITORDOMAIN/cert.pem|g"
	sed -i "s|SSLCertificateChainFile /path/to/intermediate_certificate|SSLCertificateChainFile $certfiles/$EDITORDOMAIN/chain.pem|g"
	service apache2 restart
	bash /var/scripts/test-new-config.sh
# Message
whiptail --msgbox "Succesfully installed Collabora online docker, now please head over to your Nextcloud apps and admin paneland enable the Collabora online connector app and change the URL to whatever subdomain you choose to run Collabora on." $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT

        exit 0
else
	echo -e "\e[96m"
	echo -e "It seems like no certs were generated, something went wrong"
	echo -e "\e[32m"
	read -p "Press any key to continue... " -n1 -s
	echo -e "\e[0m"
fi

exit 0
}

################################ Spreed-webrtc 2.2

do_spreed_webrtc() {
	# Secrets
ENCRYPTIONSECRET=$(openssl rand -hex 32)
SESSIONSECRET=$(openssl rand -hex 32)
SERVERTOKEN=$(openssl rand -hex 32)
SHAREDSECRET=$(openssl rand -hex 32)

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
#sed -i 's|</virtualhost>|  <Location /webrtc>\
#      ProxyPass http://$LISTENADDRESS:$LISTENPORT/webrtc\
#      ProxyPassReverse /\
#  </Location>\
#\
#  <Location /webrtc/ws>\
#      ProxyPass ws://$LISTENADDRESS:$LISTENPORT/webrtc/ws\
#  </Location>\
#\
#  ProxyVia On\
#  ProxyPreserveHost On\
#  RequestHeader set X-Forwarded-Proto 'https' env=HTTPS\
#</virtualhost>|g' $VHOST80

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
}

################################ Gpxpod 2.3

do_gpxpod() {
	sleep 1
}

################################################ Tools 3

do_tools() {
  FUN=$(whiptail --title "Tech and Tool - https://www.techandme.se" --menu "Tools" $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT \
    "T1 Show LAN IP, Gateway, Netmask" "Ifconfig" \
    "T2 Show WAN IP" "External IP address" \
    "T3 Change Hostname" "" \
    "T4 Internationalisation Options" "Change language, time, date and keyboard layout" \
    "T5 Connect to WLAN" "Please have a wifi dongle/card plugged in before start" \
    "T6 Show folder size" ""\
    "T7 Show folder conten" "with permissions" \
    "T8 Show connected devices" "blkid" \
    "T9 Show disks usage" "df -h" \
    "T10 Show system performance" "HTOP" \
    "T11 Disable IPV6" "Via sysctl.conf"\
    3>&1 1>&2 2>&3)
  RET=$?
  if [ $RET -eq 1 ]; then
    return 0
  elif [ $RET -eq 0 ]; then
    case "$FUN" in
      T1\ *) do_ifconfig ;;
      T2\ *) do_wan_ip ;;
      T3\ *) do_change_hostname ;;
      T4\ *) do_internationalisation_menu ;;
      T5\ *) do_wlan ;;
      T6\ *) do_foldersize ;;
      T7\ *) do_listdir ;;
      T8\ *) do_blkid ;;
      T9\ *) do_df ;;
      T10\ *) do_htop ;;
      T11\ *) do_disable_ipv6 ;;
    *) whiptail --msgbox "Programmer error: unrecognized option" 20 60 1 ;;
    esac || whiptail --msgbox "There was an error running option $FUN" 20 60 1
  fi
}

################################ Network details 3.1

do_ifconfig() {
whiptail --msgbox "\
Interface: $IFACE
LAN IP: $ADDRESS
Netmask: $NETMASK
Gateway: $GATEWAY\
" $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT
}

################################ Wan IP 3.2

do_wan_ip() {
  WAN=$(wget -qO- http://ipecho.net/plain ; echo)
  whiptail --msgbox "WAN IP: $WAN" $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT
}

################################ Hostname 3.3

do_change_hostname() {
  whiptail --msgbox "\
Please note: RFCs mandate that a hostname's labels \
may contain only the ASCII letters 'a' through 'z' (case-insensitive), 
the digits '0' through '9', and the hyphen.
Hostname labels cannot begin or end with a hyphen. 
No other symbols, punctuation characters, or blank spaces are permitted.\
" 20 70 1

  CURRENT_HOSTNAME=`cat /etc/hostname | tr -d " \t\n\r"`
  NEW_HOSTNAME=$(whiptail --inputbox "Please enter a hostname" 20 60 "$CURRENT_HOSTNAME" 3>&1 1>&2 2>&3)
  if [ $? -eq 0 ]; then
    echo $NEW_HOSTNAME > /etc/hostname
    sed -i "s/127.0.1.1.*$CURRENT_HOSTNAME/127.0.1.1\t$NEW_HOSTNAME/g" /etc/hosts
    ASK_TO_REBOOT=1
  fi
}

################################ Internationalisation 3.4

do_internationalisation_menu() {
  FUN=$(whiptail --title "Tech and Tool - https://www.techandme.se" --menu "Internationalisation Options" $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT --cancel-button Back --ok-button Select \
    "I1 Change Locale" "Set up language and regional settings to match your location" \
    "I2 Change Timezone" "Set up timezone to match your location" \
    "I3 Change Keyboard Layout" "Set the keyboard layout to match your keyboard" \
    3>&1 1>&2 2>&3)
  RET=$?
  if [ $RET -eq 1 ]; then
    return 0
  elif [ $RET -eq 0 ]; then
    case "$FUN" in
      I1\ *) do_change_locale ;;
      I2\ *) do_change_timezone ;;
      I3\ *) do_configure_keyboard ;;
      *) whiptail --msgbox "Programmer error: unrecognized option" 20 60 1 ;;
    esac || whiptail --msgbox "There was an error running option $FUN" 20 60 1
  fi
}

######

do_configure_keyboard() {
  dpkg-reconfigure keyboard-configuration &&
  printf "Reloading keymap. This may take a short while\n" &&
  invoke-rc.d keyboard-setup start
}

######

do_change_locale() {
  dpkg-reconfigure locales
}

######

do_change_timezone() {
  dpkg-reconfigure tzdata
}

################################ Wifi 3.5

do_wlan() {
	 whiptail --yesno "Would you like to use advanced options?" 20 60 2
    if [ $? -eq 0 ]; then # yes

		if [ $(dpkg-query -W -f='${Status}' wicd-curses 2>/dev/null | grep -c "ok installed") -eq 1 ];
then
         whiptail --msgbox "wicd-curses is already installed!" 20 60 1
         wicd-curses

else

    {
    i=1
    while read -r line; do
        i=$(( $i + 1 ))
        echo $i
    done < <(apt-get update)
    } | whiptail --title "Progress" --gauge "Please wait while updating" 6 60 0
    
    {
    i=1
    while read -r line; do
        i=$(( $i + 1 ))
        echo $i
    done < <(apt-get install wicd-curses -y)
    } | whiptail --title "Progress" --gauge "Please wait while installing wicd-curses" 6 60 0
    
	wicd-curses
fi

else

		if [ $(dpkg-query -W -f='${Status}' linux-firmware 2>/dev/null | grep -c "ok installed") -eq 1 ];
then
         whiptail --msgbox "Linux-firmware is already installed!" 20 60 1

else
    {
    i=1
    while read -r line; do
        i=$(( $i + 1 ))
        echo $i
    done < <(apt-get install linux-firmware -y)
    } | whiptail --title "Progress" --gauge "Please wait while installing linux firmware" 6 60 0
fi

	if [ $(dpkg-query -W -f='${Status}' network-manager 2>/dev/null | grep -c "ok installed") -eq 1 ];
then
        whiptail --msgbox "Network manager is already installed!" 20 60 1

else
    {
    i=1
    while read -r line; do
        i=$(( $i + 1 ))
        echo $i
    done < <(apt-get install network-manager -y)
    } | whiptail --title "Progress" --gauge "Please wait while installing network manager" 6 60 0
fi

	if [ $(dpkg-query -W -f='${Status}' wireless-tools 2>/dev/null | grep -c "ok installed") -eq 1 ];
then
         whiptail --msgbox "wireless-tools is already installed!" 20 60 1

else
    {
    i=1
    while read -r line; do
        i=$(( $i + 1 ))
        echo $i
    done < <(	apt-get install wireless-tools -y)
    } | whiptail --title "Progress" --gauge "Please wait while installing wireless tools" 6 60 0
fi

	sed -i 's|managed=false|managed=true|g' /etc/NetworkManager/NetworkManager.conf
	/etc/init.d/network-manager restart

	WIFACE=$(lshw -c network | grep "wl" | awk '{print $3}')
	cp /etc/network/interfaces /etc/network/interfaces.bak
	echo "auto $WIFACE" >> /etc/network/interfaces
	echo "allow-hotplug $WIFACE" >> /etc/network/interfaces
	echo "iface $WIFACE inet dhcp" >> /etc/network/interfaces
	ifup $WIFACE

	IWLIST=$(nmcli dev wifi)
	OLDSETTINGS=$(cat /etc/network/interfaces.bak)
	whiptail --msgbox "In the next screen copy your wifi network SSID (CTRL + SHIFT + C)" 20 60 1
	whiptail --msgbox "$IWLIST" 30 80 1
	WLAN=$(whiptail --title "SSID, network name? (case sensetive)" --inputbox "Navigate with TAB to hit ok to enter input" 10 60 3>&1 1>&2 2>&3)
	WLANPASS=$(whiptail --title "Wlan password? (case sensetive)" --passwordbox "Navigate with TAB to hit ok to enter input" 10 60 3>&1 1>&2 2>&3)
	
cat <<-NETWORK > "/etc/network/interfaces"
$OLDSETTINGS

auto $WIFACE
allow-hotplug $WIFACE
iface $WIFACE inet dhcp
wireless-essid $WLAN
wireless-key $WLANPASS
NETWORK

	ifup $WIFACE
	nmcli dev wifi connect $WLAN password $WLANPASS
	ifdown $WIFACE
	ifup $WIFACE
	dhcpcd -r
	dhcpcd $WIFACE
fi
}

################################ Raspberry specific 3.6

do_Raspberry() {
  FUN=$(whiptail --title "Tech and Tool - https://www.techandme.se" --menu "Raspberry" $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT \
    "R1 Resize SD" "" \
    "R2 External USB" "Use an USB HD/SSD as root" \
    "R3 RPI-update" "Update the RPI firmware and kernel" \
    3>&1 1>&2 2>&3)
  RET=$?
  if [ $RET -eq 1 ]; then
    return 0
  elif [ $RET -eq 0 ]; then
    case "$FUN" in
      R1\ *) do_expand_rootfs ;;
      R2\ *) do_external_usb ;;
      R3\ *) do_rpi_update ;;
      *) whiptail --msgbox "Programmer error: unrecognized option" 20 60 1 ;;
    esac || whiptail --msgbox "There was an error running option $FUN" 20 60 1
  fi
}

##################### Resize SD 3.61

do_expand_rootfs() {
  if ! [ -h /dev/root ]; then
    whiptail --msgbox "/dev/root does not exist or is not a symlink. Don't know how to expand" 20 60 2
    return 0
  fi

  ROOT_PART=$(readlink /dev/root)
  PART_NUM=${ROOT_PART#mmcblk0p}
  if [ "$PART_NUM" = "$ROOT_PART" ]; then
    whiptail --msgbox "/dev/root is not an SD card. Don't know how to expand" 20 60 2
    return 0
  fi

  # NOTE: the NOOBS partition layout confuses parted. For now, let's only 
  # agree to work with a sufficiently simple partition layout
  if [ "$PART_NUM" -ne 2 ]; then
    whiptail --msgbox "Your partition layout is not currently supported by this tool. You are probably using NOOBS, in which case your root filesystem is already expanded anyway." 20 60 2
    return 0
  fi

  LAST_PART_NUM=$(parted /dev/mmcblk0 -ms unit s p | tail -n 1 | cut -f 1 -d:)

  if [ "$LAST_PART_NUM" != "$PART_NUM" ]; then
    whiptail --msgbox "/dev/root is not the last partition. Don't know how to expand" 20 60 2
    return 0
  fi

  # Get the starting offset of the root partition
  PART_START=$(parted /dev/mmcblk0 -ms unit s p | grep "^${PART_NUM}" | cut -f 2 -d:)
  [ "$PART_START" ] || return 1
  # Return value will likely be error for fdisk as it fails to reload the
  # partition table because the root fs is mounted
  fdisk /dev/mmcblk0 <<EOF
p
d
$PART_NUM
n
p
$PART_NUM
$PART_START
p
w
EOF
  ASK_TO_REBOOT=1

  # now set up an init.d script
cat <<\EOF > /etc/init.d/resize2fs_once &&
#!/bin/sh
### BEGIN INIT INFO
# Provides:          resize2fs_once
# Required-Start:
# Required-Stop:
# Default-Start: 2 3 4 5 S
# Default-Stop:
# Short-Description: Resize the root filesystem to fill partition
# Description:
### END INIT INFO
. /lib/lsb/init-functions
case "$1" in
  start)
    log_daemon_msg "Starting resize2fs_once" &&
    resize2fs /dev/root &&
    rm /etc/init.d/resize2fs_once &&
    update-rc.d resize2fs_once remove &&
    log_end_msg $?
    ;;
  *)
    echo "Usage: $0 start" >&2
    exit 3
    ;;
esac
EOF
  chmod +x /etc/init.d/resize2fs_once &&
  update-rc.d resize2fs_once defaults &&
  if [ "$INTERACTIVE" = True ]; then
    whiptail --msgbox "Root partition has been resized.\nThe filesystem will be enlarged upon the next reboot" 20 60 2
  fi
}

##################### External USB 3.62

do_external_usb() {
	sleep 1
}

##################### RPI-update 3.63

do_rpi_update() {
	    {
    i=1
    while read -r line; do
        i=$(( $i + 1 ))
        echo $i
    done < <(rpi-update)
    } | whiptail --title "Progress" --gauge "Please wait while updating your RPI firmware and kernel" 6 60 0
}

################################ Show folder size 3.7

do_foldersize() {
	
	if [ $(dpkg-query -W -f='${Status}' ncdu 2>/dev/null | grep -c "ok installed") -eq 1 ];
then
        ncdu /
else
    {
    i=1
    while read -r line; do
        i=$(( $i + 1 ))
        echo $i
    done < <(	apt-get install ncdu -y)
    } | whiptail --title "Progress" --gauge "Please wait while installing ncdu" 6 60 0
	
	ncdu /
	
fi
}

################################ Show folder content and permissions 3.8

do_listdir() {
	LISTDIR=$(whiptail --title "Directory to list? Eg. /mnt/yourfolder" --inputbox "Navigate with TAB to hit ok to enter input" $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT 3>&1 1>&2 2>&3)
	LISTDIR1=$(ls -la $LISTDIR)
	whiptail --msgbox "$LISTDIR1" 30 $WT_WIDTH $WT_MENU_HEIGHT
	
}

################################ Show connected devices 3.9

do_blkid() {
  BLKID=$(blkid)
  whiptail --msgbox "$BLKID" $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT
}

################################ Show disk usage 3.10

do_df() {
  DF=$(df -h)
  whiptail --msgbox "$DF" 20 $WT_WIDTH $WT_MENU_HEIGHT
}

################################ Show system performance 3.11

do_htop() {
	if [ $(dpkg-query -W -f='${Status}' htop 2>/dev/null | grep -c "ok installed") -eq 1 ];
then
        htop

else

    {
    i=1
    while read -r line; do
        i=$(( $i + 1 ))
        echo $i
    done < <(apt-get install htop -y)
    } | whiptail --title "Progress" --gauge "Please wait while installing htop" 6 60 0

fi
	htop
}

################################ Disable IPV6 3.12

do_disable_ipv6() {

 if grep -q net.ipv6.conf.all.disable_ipv6 = 1 "/etc/sysctl.conf"; then
   sleep 0
 else
 echo "net.ipv6.conf.all.disable_ipv6 = 1" >> /etc/sysctl.conf
 fi

 if grep -q net.ipv6.conf.default.disable_ipv6 = 1 "/etc/sysctl.conf"; then
   sleep 0
 else
 echo "net.ipv6.conf.default.disable_ipv6 = 1" >> /etc/sysctl.conf
 fi
 
  if grep -q net.ipv6.conf.lo.disable_ipv6 = 1 = 1 "/etc/sysctl.conf"; then
   sleep 0
 else
 echo "net.ipv6.conf.lo.disable_ipv6 = 1" >> /etc/sysctl.conf
 fi
 
whiptail --msgbox "IPV6 is now disabled..." 30 $WT_WIDTH $WT_MENU_HEIGHT
}

################################################ Update

do_update() {

   {
    i=1
    while read -r line; do
        i=$(( $i + 1 ))
        echo $i
    done < <( apt-get autoclean )
    } | whiptail --title "Progress" --gauge "Please wait while auto cleaning" 6 60 0

    {
    i=1
    while read -r line; do
        i=$(( $i + 1 ))
        echo $i
    done < <( apt-get autoremove -y )
    } | whiptail --title "Progress" --gauge "Please wait while auto removing unneeded dependancies " 6 60 0

    {
    i=1
    while read -r line; do
        i=$(( $i + 1 ))
        echo $i
    done < <( apt-get update )
    } | whiptail --title "Progress" --gauge "Please wait while updating " 6 60 0


    {
    i=1
    while read -r line; do
        i=$(( $i + 1 ))
        echo $i
    done < <( apt-get apt-get upgrade -y )
    } | whiptail --title "Progress" --gauge "Please wait while ugrading " 6 60 0

    {
    i=1
    while read -r line; do
        i=$(( $i + 1 ))
        echo $i
    done < <( 	apt-get -f install -y )
    } | whiptail --title "Progress" --gauge "Please wait while forcing install of dependancies " 6 60 0

	dpkg --configure --pending

	mkdir -p /var/scripts

	if [ -f /var/scripts/techandtool.sh ]
then
    rm /var/scripts/techandtool.sh
fi

    {
    i=1
    while read -r line; do
        i=$(( $i + 1 ))
        echo $i
    done < <( 	wget https://github.com/ezraholm50/vm/raw/master/static/techandtool.sh -P /var/scripts )
    } | whiptail --title "Progress" --gauge "Please wait while downloading latest version Tech and Tool " 6 60 0
	

	exit | bash /var/scripts/techandtool.sh 

}

################################################ About

do_about() {
  whiptail --msgbox "\
This tool is created by techandme.se for less skilled linux terminal users.
It makes it easy just browsing the menu and installing or using system tools. Please post requests or suggestions here:
lINK TO FOLLOW!!!!!!!!!!!!!!!!!!!!!!!!!!!!
Visit https://www.techandme.se for awsome free virtual machines,
Nextcloud, ownCloud, Teamspeak, Wordpress etc.\
" $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT
}

################################################ Interactive use loop

calc_wt_size
while true; do
  FUN=$(whiptail --title "https://www.techandme.se" --menu "Multi Installer" $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT --cancel-button Finish --ok-button Select \
    "1 Apps" "Nextcloud" \
    "2 Tools" "Various tools" \
    "3 Update & upgrade" "Updates and upgrades packages and get the latest version of this tool" \
    "4 Reboot" "Reboots your machine" \
    "5 Shutdown" "Shutdown your machine" \
    "6 About Tech and Tool" "Information about this tool" \
    3>&1 1>&2 2>&3)
  RET=$?
  if [ $RET -eq 1 ]; then
	do_finish
  elif [ $RET -eq 0 ]; then
    case "$FUN" in
      1\ *) do_apps ;;
      2\ *) do_tools;;
      3\ *) do_update ;;
      4\ *) do_reboot ;;
      5\ *) do_poweroff ;;
      6\ *) do_about ;;
      *) whiptail --msgbox "Programmer error: unrecognized option" 20 60 1 ;;
    esac || whiptail --msgbox "There was an error running option $FUN" 20 60 1
 else
   exit 1
  fi
done

do_reboot() {
	reboot
}

do_poweroff() {
	shutdown now
}
