#!/bin/bash
# Collabora auto installer

SCRIPTS=/var/scripts
# Check if root
if [ "$(whoami)" != "root" ]
then
    echo
    echo -e "\e[31mSorry, you are not root.\n\e[0mYou must type: \e[36msudo \e[0mbash $SCRIPTS/collabora.sh"
    echo
    exit 1
fi

## Variable's
# Docker URL
SUBDOMAIN=$(whiptail --title "Techandme.se Collabora" --inputbox "Collabora subdomain eg: office.yourdomain.com" "$WT_HEIGHT" "$WT_WIDTH" 3>&1 1>&2 2>&3)
# Nextcloud Main Domain
NCDOMAIN=$(whiptail --title "Techandme.se Collabora" --inputbox "Nextcloud url, make sure it looks like this: cloud\\.yourdomain\\.com" "$WT_HEIGHT" "$WT_WIDTH" cloud\\.yourdomain\\.com 3>&1 1>&2 2>&3)
# Vhost
HTTPS_CONF="/etc/apache2/sites-available/$SUBDOMAIN.conf"
# Letsencrypt
LETSENCRYPTPATH=/etc/letsencrypt
CERTFILES=$LETSENCRYPTPATH/live
# WANIP
WANIP4=$(dig +short myip.opendns.com @resolver1.opendns.com)
# App
COLLVER=$(curl -s https://api.github.com/repos/nextcloud/richdocuments/releases/latest | grep "tag_name" | cut -d\" -f4)
COLLVER_FILE=richdocuments.tar.gz
COLLVER_REPO=https://github.com/nextcloud/richdocuments/releases/download
# Folders
NCPATH=/var/www/nextcloud

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
whiptail --msgbox "Please before you start, make sure that port 443 is directly forwarded to this machine!" "$WT_HEIGHT" "$WT_WIDTH"

# Get the latest packages
apt update -q2

# Check if Nextcloud is installed
echo "Checking if Nextcloud is installed..."
curl -s https://$(echo $NCDOMAIN | tr -d '\\')/status.php | grep -q 'installed":true'
if [ $? -eq 0 ]
then
    sleep 1
else
    echo
    echo "It seems like Nextcloud is not installed or that you don't use https on:"
    echo "$(echo $NCDOMAIN | tr -d '\\')."
    echo "Please install Nextcloud and make sure your domain is reachable, or activate SSL"
    echo "on your domain to be able to run this script."
    echo
    echo "If you use the Nextcloud VM you can use the Let's Encrypt script to get SSL and activate your Nextcloud domain."
    echo "When SSL is activated, run these commands from your terminal:"
    echo "sudo wget https://raw.githubusercontent.com/nextcloud/vm/master/static/collabora.sh"
    echo "sudo bash collabora.sh"
    echo -e "\e[32m"
    read -p "Press any key to continue... " -n1 -s
    echo -e "\e[0m"
    exit 1
fi

# Check if $SUBDOMAIN exists and is reachable
echo
echo "Checking if $SUBDOMAIN exists and is reachable..."
curl -s $SUBDOMAIN > /dev/null
if [[ $? > 0 ]]
then
   echo "Nope, it's not there. You have to create $SUBDOMAIN and point"
   echo "it to this server before you can run this script."
   echo -e "\e[32m"
   read -p "Press any key to continue... " -n1 -s
   echo -e "\e[0m"
   exit 1
fi

# Check if 443 is open using nmap, if not notify the user
echo "Running apt update..."
apt update -q2
if [ $(dpkg-query -W -f='${Status}' nmap 2>/dev/null | grep -c "ok installed") -eq 1 ]
then
      echo "nmap is already installed..."
      clear
else
    apt install nmap -y
fi
if [ $(nmap -sS -p 443 "$WANIP4" | grep -c "open") -eq 1 ]
then
  echo -e "\e[32mPort 443 is open on $WANIP4!\e[0m"
  apt remove --purge nmap -y
else
  echo "Port 443 is not open on $WANIP4. We will do a second try on $SUBDOMAIN instead."
  echo -e "\e[32m"
  read -p "Press any key to test $SUBDOMAIN... " -n1 -s
  echo -e "\e[0m"
  if [[ $(nmap -sS -PN -p 443 $SUBDOMAIN | grep -m 1 "open" | awk '{print $2}') = open ]]
  then
    echo -e "\e[32mPort 443 is open on $SUBDOMAIN!\e[0m"
    apt remove --purge nmap -y
  else
    whiptail --msgbox "Port 443 is not open on $SUBDOMAIN. Please follow this guide to open ports in your router: https://www.techandme.se/open-port-80-443/" "$WT_HEIGHT" "$WT_WIDTH"
    echo -e "\e[32m"
    read -p "Press any key to exit... " -n1 -s
    echo -e "\e[0m"
    apt remove --purge nmap -y
    exit 1
  fi
fi

# Install Docker
if [ $(dpkg-query -W -f='${Status}' docker-ce 2>/dev/null | grep -c "ok installed") -eq 1 ]
then
    docker -v
else
    apt update -q2
    apt install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    software-properties-common
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
    apt-key fingerprint 0EBFCD88
    add-apt-repository \
    "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) \
    stable"
    apt update
    apt install docker-ce -y
    docker -v
fi

# Load aufs
apt-get install linux-image-extra-$(uname -r) -y
# apt install aufs-tools -y # already included in the docker-ce package
AUFS=$(grep -r "aufs" /etc/modules)
if [[ $AUFS = "aufs" ]]
then
    sleep 1
else
    echo "aufs" >> /etc/modules
fi

# Set docker storage driver to AUFS
AUFS2=$(grep -r "aufs" /etc/default/docker)
if [[ $AUFS2 = 'DOCKER_OPTS="--storage-driver=aufs"' ]]
then
    sleep 1
else
    echo 'DOCKER_OPTS="--storage-driver=aufs"' >> /etc/default/docker
    service docker restart
fi

# Check if Git is installed
    git --version 2> /dev/null
    GIT_IS_AVAILABLE=$?
if [ $GIT_IS_AVAILABLE -eq 0 ]
then
    sleep 1
else
    apt install git -y
fi

# Check of docker runs and kill it
DOCKERPS=$(docker ps -a -q)
if [[ $DOCKERPS > 0 ]]
then
    echo "Removing old Docker instance(s)... ($DOCKERPS)"
    echo -e "\e[32m"
    read -p "Press any key to continue. Press CTRL+C to abort." -n1 -s
    echo -e "\e[0m"
    docker stop $DOCKERPS
    docker rm $DOCKERPS
else
    echo "No Docker instanses running"
fi

# Disable RichDocuments (Collabora App) if activated
if [ -d $NCPATH/apps/richdocuments ]
then
    sudo -u www-data php $NCPATH/occ app:disable richdocuments
    rm -r $NCPATH/apps/richdocuments
fi

# Install Collabora docker
docker pull collabora/code
docker run -t -d -p 127.0.0.1:9980:9980 -e "domain=$NCDOMAIN" --restart always --cap-add MKNOD collabora/code

# Install Apache2
if [ $(dpkg-query -W -f='${Status}' apache2 2>/dev/null | grep -c "ok installed") -eq 1 ]
then
    sleep 1
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
  ServerName $SUBDOMAIN:443

  # SSL configuration, you may want to take the easy route instead and use Lets Encrypt!
  SSLEngine on
  SSLCertificateChainFile $CERTFILES/$SUBDOMAIN/chain.pem
  SSLCertificateFile $CERTFILES/$SUBDOMAIN/cert.pem
  SSLCertificateKeyFile $CERTFILES/$SUBDOMAIN/privkey.pem
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
  ProxyPassReverse    /lool https://127.0.0.1:9980/lool
</VirtualHost>
HTTPS_CREATE

# Ugly fix for now, maybe "$1" or something?
sed -i 's|/lool//ws|/lool/$1/ws|g' $HTTPS_CONF

if [ -f "$HTTPS_CONF" ];
then
    echo "$HTTPS_CONF was successfully created"
    sleep 2
else
    echo "Unable to create vhost, exiting..."
    echo "Please report this issue here https://github.com/nextcloud/vm/issues/new"
    exit
fi

fi

# Let's Encrypt
# Stop Apache to aviod port conflicts
a2dissite 000-default.conf
sudo service apache2 stop

# Generate certs
cd /etc
git clone https://github.com/certbot/certbot.git
cd /etc/certbot
./letsencrypt-auto certonly --agree-tos --standalone -d $SUBDOMAIN
if [[ "$?" == "0" ]]
then
    echo -e "\e[96m"
    echo -e "Certs are generated!"
    echo -e "\e[0m"
    a2ensite $SUBDOMAIN.conf
    service apache2 restart
# Install Collabora App
    wget -q $COLLVER_REPO/$COLLVER/$COLLVER_FILE -P $NCPATH/apps
    tar -zxf $NCPATH/apps/$COLLVER_FILE -C $NCPATH/apps
    cd $NCPATH/apps
    rm $COLLVER_FILE
else
    echo -e "\e[96m"
    echo -e "It seems like no certs were generated, please report this issue here: https://github.com/nextcloud/vm/issues/new"
    echo -e "\e[32m"
    read -p "Press any key to continue... " -n1 -s
    service apache2 restart
    echo -e "\e[0m"
fi

# Enable RichDocuments (Collabora App)
if [ -d $NCPATH/apps/richdocuments ]
then
    sudo -u www-data php $NCPATH/occ app:enable richdocuments
    sudo -u www-data $NCPATH/occ config:app:set richdocuments wopi_url --value="https://$SUBDOMAIN"
    echo
    echo "Collabora is now succesfylly installed."
    echo "You may have to reboot before Docker will load correctly."
    echo -e "\e[32m"
    read -p "Press any key to continue... " -n1 -s
    echo -e "\e[0m"
fi
