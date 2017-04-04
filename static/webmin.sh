# Install packages for Webmin
apt install -y zip perl libnet-ssleay-perl openssl libauthen-pam-perl libpam-runtime libio-pty-perl apt-show-versions python

# Install Webmin
sed -i '$a deb http://download.webmin.com/download/repository sarge contrib' /etc/apt/sources.list
if wget -q http://www.webmin.com/jcameron-key.asc -O- | sudo apt-key add -
then
    apt update -q2
    apt install webmin -y
fi
