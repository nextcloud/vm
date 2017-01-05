#!/bin/bash
# Solr Server & Nextant App Installation

# Setting variables
NT_RELEASE=nextant-master-1.0.3.tar.gz
NT_DL=https://github.com/nextcloud/nextant/releases/download/v1.0.3/$NT_RELEASE
SOLR_RELEASE=solr-6.3.0.tgz
SOLR_DL=http://mirrors.ircam.fr/pub/apache/lucene/solr/6.3.0/$SOLR_RELEASE
NC_USER=ncadmin
NT_HOME=/home/$NC_USER
NCPATH=/var/www/nextcloud/
NC_APPS_PATH=$NCPATH/apps/
SOLR_HOME=$NT_HOME/solr_install/
SOLR_JETTY=/opt/solr/server/etc/jetty-http.xml
SOLR_DSCONF=/opt/solr-6.3.0/server/solr/configsets/data_driven_schema_configs/conf/solrconfig.xml
SCRIPTS=/var/scripts

# Must be root
[[ `id -u` -eq 0 ]] || { echo "Must be root to run script, in Ubuntu type: sudo -i"; exit 1; }

echo "Starting to setup Solr & Nextant on Nextcloud..."
sleep 3

# Installing requirements
apt install default-jre -y

# Getting and installing Apache Solr
echo "Installing Apache Sorl..."
mkdir $SOLR_HOME
cd $SOLR_HOME
wget -q $SOLR_DL
tar -zxf $SOLR_RELEASE
./solr-6.3.0/bin/install_solr_service.sh $SOLR_RELEASE # add test after this
#rm -rf $SOLR_HOME/$SOLR_RELEASE
#should we remove solr home folder?

sudo sed -i '35,37  s/"jetty.host" \//"jetty.host" default="127.0.0.1" \//' $SOLR_JETTY

iptables -A INPUT -p tcp -s localhost --dport 8983 -j ACCEPT
iptables -A INPUT -p tcp --dport 8983 -j DROP
#shouldn't this rules be saved somewhere to reload on reboot?

service solr start
sudo -u solr /opt/solr/bin/solr create -c nextant 

# Add search suggestions feature
sed -i '2i <!DOCTYPE config [' $SOLR_DSCONF
sed -i '3i   <!ENTITY nextant_component SYSTEM "/var/www/nextcloud/apps/nextant/config/nextant_solrconfig.xml"\>' $SOLR_DSCONF
sed -i '4i   ]>' $SOLR_DSCONF

sed -i '$d' $SOLR_DSCONF | sed -i '$d' $SOLR_DSCONF
echo "
&nextant_component;
</config>" | tee -a $SOLR_DSCONF

echo 'SOLR_OPTS="$SOLR_OPTS -Dsolr.allow.unsafe.resourceloading=true"' | sudo tee -a /etc/default/solr.in.sh

service solr restart # add test here

# Get nextant app for nextcloud
wget -q -P $NC_APPS_PATH $NT_DL
cd $NC_APPS_PATH
tar zxf $NT_RELEASE
bash $SCRIPTS/setup_secure_permissions_nextcloud.sh
rm -r $NT_RELEASE
sudo -u www-data php $NCPATH/occ app:enable nextant # add test here

echo "Nextant is now installed and enabled."
echo "Please go to: Admin Settings --> Additional Settings, and configure the app"
