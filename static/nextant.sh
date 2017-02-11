#!/bin/bash
# Solr Server & Nextant App Installation

# Setting variables
STATIC="https://raw.githubusercontent.com/nextcloud/vm/master/static"
SOLR_VERSION=$(curl -s https://github.com/apache/lucene-solr/tags | grep -P -m 1 -o '<span class="tag-name">.+/\K.+?(?=</span>)')
NEXTANT_VERSION=$(curl -s https://api.github.com/repos/nextcloud/nextant/releases/latest | grep 'tag_name' | cut -d\" -f4 | sed -e "s|v||g")
NT_RELEASE=nextant-master-$NEXTANT_VERSION.tar.gz
NT_DL=https://github.com/nextcloud/nextant/releases/download/v$NEXTANT_VERSION/$NT_RELEASE
SOLR_RELEASE=solr-$SOLR_VERSION.tgz
SOLR_DL=http://www-eu.apache.org/dist/lucene/solr/$SOLR_VERSION/$SOLR_RELEASE
NCPATH=/var/www/nextcloud
NC_APPS_PATH=$NCPATH/apps/
SOLR_HOME=/home/$SUDO_USER/solr_install/
SOLR_JETTY=/opt/solr/server/etc/jetty-http.xml
SOLR_DSCONF=/opt/solr-$SOLR_VERSION/server/solr/configsets/data_driven_schema_configs/conf/solrconfig.xml
SCRIPTS=/var/scripts

# Must be root
[[ `id -u` -eq 0 ]] || { echo "Must be root to run script, in Ubuntu type: sudo -i"; exit 1; }

# Make sure there is an Nextcloud installation
if [ "$(sudo -u www-data php $NCPATH/occ -V)" ]
then
	sleep 1
else
	echo "It seems there is no Nextcloud server installed, please check your installation."
	sleep 3
exit 1
fi

# Check if it's a clean install
if [ -d $SOLR_HOME ]
then
    echo
    echo "It seems like $SOLR_HOME already exists. Have you already run this script?"
    echo "If yes, revert all the settings and try again, it must be a clean install."
    exit 1
fi

echo "Starting to setup Solr & Nextant on Nextcloud..."
sleep 3

# Installing requirements
apt update -qq
apt install default-jre -y

# Getting and installing Apache Solr
echo "Installing Apache Solr"
echo "It might take some time depending on your bandwith, please be patient..."
mkdir -p $SOLR_HOME
cd $SOLR_HOME
wget -q $SOLR_DL --show-progress
tar -zxf $SOLR_RELEASE
./solr-$SOLR_VERSION/bin/install_solr_service.sh $SOLR_RELEASE
if [ $? -eq 0 ]
then
    rm -rf $SOLR_HOME/$SOLR_RELEASE
    wget -q https://raw.githubusercontent.com/apache/lucene-solr/master/solr/bin/install_solr_service.sh -P $SCRIPTS/
else
    echo "Solr failed to install, something is wrong with the Solr installation"
    exit 1
fi

sudo sed -i '35,37  s/"jetty.host" \//"jetty.host" default="127.0.0.1" \//' $SOLR_JETTY

iptables -A INPUT -p tcp -s localhost --dport 8983 -j ACCEPT
iptables -A INPUT -p tcp --dport 8983 -j DROP
# Not tested
#sudo apt install iptables-persistent
#sudo service iptables-persistent start
#sudo iptables-save > /etc/iptables.conf

service solr start
if [ $? -eq 0 ]
then
    sudo -u solr /opt/solr/bin/solr create -c nextant 
else
    echo "Solr failed to start, something is wrong with the Solr installation"
    exit 1
fi

# Add search suggestions feature
sed -i '2i <!DOCTYPE config [' $SOLR_DSCONF
sed -i "3i   <\!ENTITY nextant_component SYSTEM \"$NCPATH/apps/nextant/config/nextant_solrconfig.xml\"\>" $SOLR_DSCONF
sed -i '4i   ]>' $SOLR_DSCONF

sed -i '$d' $SOLR_DSCONF | sed -i '$d' $SOLR_DSCONF
echo "
&nextant_component;
</config>" | tee -a $SOLR_DSCONF

echo 'SOLR_OPTS="$SOLR_OPTS -Dsolr.allow.unsafe.resourceloading=true"' | sudo tee -a /etc/default/solr.in.sh

service solr restart
if [ $? -eq 0 ]
then
    sleep 1
else
    echo "Solr failed to restart, something is wrong with the Solr installation"
    exit 1
fi

# Get nextant app for nextcloud
NT_DL_CK=$(wget -q -P $NC_APPS_PATH $NT_DL)
if [ $? -ne 0 ]; then
    echo "There seems to be an issue detecting the latest release version published"
    echo "Please copy/paste the tar file url for the latest release download, manually"
    echo "(e.g. https://github.com/nextcloud/nextant/releases/download/v1.0.3/nextant-master-1.0.3.tar.gz )
    cd $NC_APPS_PATH
    read NT_DL_AL
    NT_ALT_REL=$(wget -nv $NT_DL_AL 2>&1 |cut -d\" -f2)
    tar zxf $NT_ALT_REL
else
    echo "Downloading version $NEXTANT_VERSION"
    cd $NC_APPS_PATH
    tar zxf $NT_RELEASE
fi

# Check if permission script exists, if not get it.
if [ -f $SCRIPTS/setup_secure_permissions_nextcloud.sh ]
then
    bash $SCRIPTS/setup_secure_permissions_nextcloud.sh
else
    wget -q $STATIC/setup_secure_permissions_nextcloud.sh -P $SCRIPTS
    bash $SCRIPTS/setup_secure_permissions_nextcloud.sh
fi

#Delete tar file either of them
if [ -f $NT_ALT_REL ]
then
    rm -r $NT_ALT_REL
else
    rm -r $NT_RELEASE
fi

sudo -u www-data php $NCPATH/occ app:enable nextant
sudo -u www-data php $NCPATH/occ nextant:test http://127.0.0.1:8983/solr/ nextant
sudo -u www-data php $NCPATH/occ nextant:index

if [ $? -eq 0 ]
then
    echo "Nextant app is now installed and enabled."
    sleep 3
else
    echo "Nextant app install failed"
    sleep 3
    exit 1
fi
