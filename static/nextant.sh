#!/bin/bash
# Solr Server & Nextant App Installation

# Setting variables
NT_RELEASE=nextant-master-1.0.3.tar.gz
NT_DL=https://github.com/nextcloud/nextant/releases/download/v1.0.3/$NT_RELEASE
SOLR_RELEASE=solr-6.3.0.tgz
SOLR_DL=http://mirrors.ircam.fr/pub/apache/lucene/solr/6.3.0/$SOLR_RELEASE
NC_USER=ncadmin
NT_HOME=/home/$NC_USER
NC_APPS_PATH=/var/www/nextcloud/apps/
SOLR_HOME=$NT_HOME/solr_install/
SOLR_JETTY=/opt/solr/server/etc/jetty-http.xml
SOLR_DSCONF=/opt/solr-6.3.0/server/solr/configsets/data_driven_schema_configs/conf/solrconfig.xml

echo "Starting to setup Solr & Nextant on Nextcloud..."
sleep 3

# Installing requirements
apt-get -y install default-jre

# Getting and installing Apache Solr
mkdir $SOLR_HOME
cd $SOLR_HOME
wget $SOLR_DL
tar -zxvf $SOLR_RELEASE
./solr-6.3.0/bin/install_solr_service.sh $SOLR_RELEASE
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

service solr restart

# Get nextant app for nextcloud
wget -P $NC_APPS_PATH $NT_DL
cd $NC_APPS_PATH
tar zxvf $NT_RELEASE
chown -R www-data:www-data nextant
rm -r $NT_RELEASE

echo "End ..."
