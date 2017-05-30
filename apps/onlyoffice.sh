#!/bin/bash
# shellcheck disable=2034,2059
true
# shellcheck source=lib.sh
. <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)

# Tech and Me © - 2017, https://www.techandme.se/

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Check if root
if ! is_root
then
    printf "\n${Red}Sorry, you are not root.\n${Color_Off}You must type: ${Cyan}sudo ${Color_Off}bash $SCRIPTS/collabora.sh\n"
    exit 1
fi

# Get the latest packages
apt update -q4 & spinner_loading

# Check if Nextcloud is installed
echo "Checking if Nextcloud is installed..."
if ! curl -s https://"${NCDOMAIN//\\/}"/status.php | grep -q 'installed":true'
then
    echo
    echo "It seems like Nextcloud is not installed or that you don't use https on:"
    echo "${NCDOMAIN//\\/}."
    echo "Please install Nextcloud and make sure your domain is reachable, or activate SSL"
    echo "on your domain to be able to run this script."
    echo
    echo "If you use the Nextcloud VM you can use the Let's Encrypt script to get SSL and activate your Nextcloud domain."
    echo "When SSL is activated, run these commands from your terminal:"
    echo "sudo wget $APP/onlyoffice.sh"
    echo "sudo bash onlyoffice.sh"
    any_key "Press any key to continue... "
    exit 1
fi

# Install Docker
if [ "$(dpkg-query -W -f='${Status}' docker-ce 2>/dev/null | grep -c "ok installed")" == "1" ]
then
    docker -v
else
    apt update -q4 & spinner_loading
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
apt-get install linux-image-extra-"$(uname -r)" -y
# apt install aufs-tools -y # already included in the docker-ce package
AUFS=$(grep -r "aufs" /etc/modules)
if ! [ "$AUFS" = "aufs" ]
then
    echo "aufs" >> /etc/modules
fi

# Set docker storage driver to AUFS
AUFS2=$(grep -r "aufs" /etc/default/docker)
if ! [ "$AUFS2" = 'DOCKER_OPTS="--storage-driver=aufs"' ]
then
    echo 'DOCKER_OPTS="--storage-driver=aufs"' >> /etc/default/docker
    service docker restart
fi

# Check of docker runs and kill it
DOCKERPS=$(docker ps -a -q)
if [ "$DOCKERPS" != "" ]
then
    echo "Removing old Docker instance(s)... ($DOCKERPS)"
    any_key "Press any key to continue. Press CTRL+C to abort"
    docker stop "$DOCKERPS"
    docker rm "$DOCKERPS"
fi

# Disable Onlyoffice if activated
if [ -d "$NCPATH"/apps/onlyoffice ]
then
    sudo -u www-data php "$NCPATH"/occ app:disable onlyoffice
    rm -r "$NCPATH"/apps/onlyoffice
fi

# Install Onlyoffice docker
docker pull onlyoffice/communityserver
sudo docker run -i -t -d -p 80:80  -p 443:443 \
    -v /app/onlyoffice/CommunityServer/data:/var/www/onlyoffice/Data  onlyoffice/communityserver

# Activate SSL
cd /tmp
openssl genrsa -out onlyoffice.key 4096
openssl req -new -key onlyoffice.key -out onlyoffice.csr
openssl x509 -req -days 3650 -in onlyoffice.csr -signkey onlyoffice.key -out onlyoffice.crt
openssl dhparam -out dhparam.pem 2048

mkdir -p /app/onlyoffice/CommunityServer/data/certs
cp onlyoffice.key /app/onlyoffice/CommunityServer/data/certs/
cp onlyoffice.crt /app/onlyoffice/CommunityServer/data/certs/
cp dhparam.pem /app/onlyoffice/CommunityServer/data/certs/
chmod 400 /app/onlyoffice/CommunityServer/data/certs/onlyoffice.key


# Install Apache2
if [ "$(dpkg-query -W -f='${Status}' apache2 2>/dev/null | grep -c "ok installed")" == "1" ]
then
    sleep 0.1
else
    {
    i=1
    while read -r line; do
        ((i++))
        echo $i
    done < <(apt install apache2 -y)
    } | whiptail --title "Progress" --gauge "Please wait while installing Apache2" 6 60 0
fi

# Enable Apache2 module's
a2enmod ssl

# Enable Onlyoffice
cd $NCPATH/apps
git clone https://github.com/ONLYOFFICE/onlyoffice-owncloud.git onlyoffice
if [ -d "$NCPATH"/apps/onlyoffice ]
then
    check_command sudo -u www-data php "$NCPATH"/occ app:enable onlyoffice
    chown -R www-data:www-data $NCPATH/apps
    echo
    echo "Onlyoffice is now succesfylly installed."
    echo "You may have to reboot before Docker will load correctly."
    any_key "Press any key to continue... "
fi

# Add prune command?
printf "Docker automatically saves all containers as untagged even if they are not in use and it\n"
printf "uses a lot of space which may lead to that your disk reaches its limit after a while.\n\n"
if [[ "yes" == $(ask_yes_or_no "Do you want to add a cronjob to remove untagged containers once a week?") ]]
then
    {
    echo "#!/bin/bash"
    echo "docker system prune -a --force"
    echo "exit"
    } > "$SCRIPTS/dockerprune.sh"
    chmod a+x "$SCRIPTS/dockerprune.sh"
    crontab -u root -l | { cat; echo "@weekly $SCRIPTS/dockerprune.sh"; } | crontab -u root -
    any_key "Cronjob added! Press any key to continue... "
fi
