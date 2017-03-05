#!/bin/bash

SCRIPTS=/var/scripts
STATIC="https://raw.githubusercontent.com/nextcloud/vm/master/static"

# Activate the new config
echo -e "\e[0m"
echo "Apache will now reboot"
echo -e "\e[32m"
read -p "Press any key to continue... " -n1 -s
echo -e "\e[0m"
a2ensite $1
a2dissite nextcloud_ssl_domain_self_signed.conf
a2dissite nextcloud_http_domain_self_signed.conf
a2dissite 000-default.conf
service apache2 restart
if [[ "$?" == "0" ]]
then
    echo -e "\e[42m"
    echo "New settings works! SSL is now activated and OK!"
    echo -e "\e[0m"
    echo
    echo "This cert will expire in 90 days, so you have to renew it."
    echo "There are several ways of doing so, here are some tips and tricks: https://goo.gl/c1JHR0"
    echo "This script will add a renew cronjob to get you started, edit it by typing:"
    echo "'crontab -u root -e'"
    echo "Feel free to contribute to this project: https://goo.gl/3fQD65"
    echo -e "\e[32m"
    read -p "Press any key to continue... " -n1 -s
    echo -e "\e[0m"
    crontab -u root -l | { cat; echo "@weekly $SCRIPTS/letsencryptrenew.sh"; } | crontab -u root -

# Set hostname and ServerName
FQDOMAIN=$(grep -r -m 1 ServerName /etc/apache2/sites-enabled/* | awk '{print $3; exit}')
echo "Setting hostname to $FQDOMAIN..."
sudo sh -c "echo 'ServerName $FQDOMAIN' >> /etc/apache2/apache2.conf"
sudo hostnamectl set-hostname $FQDOMAIN
service apache2 restart

DATE='$(date +%Y-%m-%d_%H:%M)'
IF='if [[ $? -eq 0 ]]'
cat << CRONTAB > "$SCRIPTS/letsencryptrenew.sh"
#!/bin/sh
service apache2 stop
if ! /etc/letsencrypt/letsencrypt-auto renew > /var/log/letsencrypt/renew.log 2>&1 ; then
        echo Automated renewal failed:
        cat /var/log/letsencrypt/renew.log
        exit 1
fi
service apache2 start
$IF
then
        echo "Let's Encrypt SUCCESS!"--$DATE >> /var/log/letsencrypt/cronjob.log
else
        echo "Let's Encrypt FAILED!"--$DATE >> /var/log/letsencrypt/cronjob.log
        reboot
fi
CRONTAB

# Makeletsencryptrenew.sh executable
chmod +x $SCRIPTS/letsencryptrenew.sh

# Cleanup
rm $SCRIPTS/test-new-config.sh
rm $SCRIPTS/activate-ssl.sh

else
# If it fails, revert changes back to normal
    a2dissite $1
    a2ensite nextcloud_ssl_domain_self_signed.conf
    a2ensite nextcloud_http_domain_self_signed.conf
    a2ensite 000-default.conf
    service apache2 restart
    echo -e "\e[96m"
    echo "Couldn't load new config, reverted to old settings. Self-signed SSL is OK!"
    echo -e "\e[0m"
    echo -e "\e[32m"
    read -p "Press any key to continue... " -n1 -s
    echo -e "\e[0m"
    exit 1
fi

exit
