#!/bin/sh
#
# Tech and Me, 2016 - www.techandme.se
# Whiptail menu to install various Nextcloud app and do other useful stuf.
################################################ Variable 1
################################ Network 1.1

IFCONFIG=$(ifconfig)
IP="/sbin/ip"
IFACE=$($IP -o link show | awk '{print $2,$9}' | grep "UP" | cut -d ":" -f 1)
INTERFACES="/etc/network/interfaces"
ADDRESS=$($IP route get 1 | awk '{print $NF;exit}')
NETMASK=$(ifconfig $IFACE | grep Mask | sed s/^.*Mask://)
GATEWAY=$($IP route | awk '/default/ { print $3 }')

################################ 1.2

################################ 1.3

################################ 1.4


################################################ Whiptail check

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

################################################ Check if root

if [ "$(whoami)" != "root" ]; then
        whiptail --msgbox "Sorry you are not root. You must type: sudo bash techandtool.sh" 20 60 1
        exit
fi

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
HTTPS_CONF="/etc/apache2/sites-available/$EDITORDOMAIN"
DOMAIN=$(whiptail --title "Techandme.se Collabora online installer" --inputbox "Nextcloud url, make sure it looks like this: cloud\.nextcloud\.com" $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT 3>&1 1>&2 2>&3)
EDITORDOMAIN=$(whiptail --title "Techandme.se Collabora online installer" --inputbox "Collabora subdomain eg: office.nextcloud.com" $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT 3>&1 1>&2 2>&3)

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
whiptail --msgbox "\
Succesfully installed Collabora online docker, now please head over to your Nextcloud apps and admin panel
and enable the Collabora online connector app and change the URL to whatever subdomain you choose to run Collabora on.\
" $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT

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



}

################################ Gpxpod 2.3

do_gpxpod() {
}

################################################ Tools 3

do_tools() {
  FUN=$(whiptail --title "Tech and Tool - https://www.techandme.se" --menu "Tools" $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT \
    "T1 Show LAN IP, Gateway, Netmask" "Ifconfig" \
    "T2 Show WAN IP" "External IP address" \
    "T3 Change Hostname" "" \
    "T4 Internationalisation Options" "Change language, time, date and keyboard layout" \
    "T5 Connect to WLAN" "Please have a wifi dongle/card plugged in before start" \
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
      *) whiptail --msgbox "Programmer error: unrecognized option" 20 60 1 ;;
    esac || whiptail --msgbox "There was an error running option $FUN" 20 60 1
  fi
}

################################ Network details 3.1

do_ifconfig() {
whiptail --msgbox "\
Interface:$IFACE
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
	IWLIST=$(iwlist wlan0 scanning|grep -i 'essid')
	whiptail --msgbox "Next you will be shown a list with wireless access points, copy yours.." $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT
	whiptail --msgbox "$IWLIST" $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT
	WLAN=$(whiptail --title "SSID, network name? (case sensetive)" --inputbox "Navigate with TAB to hit ok to enter input" 10 60 3>&1 1>&2 2>&3)
	WLANPASS=$(whiptail --title "Wlan password? (case sensetive)" --passwordbox "Navigate with TAB to hit ok to enter input" 10 60 3>&1 1>&2 2>&3)
	if [ $exitstatus = 0 ]; then
	
	if [ $(dpkg-query -W -f='${Status}' linux-firmware 2>/dev/null | grep -c "ok installed") -eq 1 ];
then
        echo "Linux-firmware is already installed!"

else
	apt-get install linux-firmware -y
fi

	if [ $(dpkg-query -W -f='${Status}' wpasupplicant 2>/dev/null | grep -c "ok installed") -eq 1 ];
then
        echo "Wpasupplicant is already installed!"

else
	apt-get install wpasupplicant -y
fi
	
	ifup wlan0
	iwconfig wlan0 essid $WLAN key s:$WLANPASS
	ifdown wlan0
	ifup wlan0
	dhcpcd -r
	dhcpcd wlan0
	else
    	echo "You chose Cancel."
	fi
}

################################################ Update

do_update() {
  	apt-get autoclean
  	apt-get autoremove
  	apt-get update
  	apt-get upgrade -y
  	apt-get -f install
  	dpkg --configure --pending
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
    "4 About Multi Installer" "Information about this tool" \
    3>&1 1>&2 2>&3)
  RET=$?
  if [ $RET -eq 1 ]; then
    do_finish
  elif [ $RET -eq 0 ]; then
    case "$FUN" in
      1\ *) do_apps ;;
      2\ *) do_tools;;
      3\ *) do_update ;;
      4\ *) do_about ;;
      *) whiptail --msgbox "Programmer error: unrecognized option" 20 60 1 ;;
    esac || whiptail --msgbox "There was an error running option $FUN" 20 60 1
  else
    exit 1
  fi
done
