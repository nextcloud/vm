#!/bin/bash
# shellcheck disable=2034,2059
true
# shellcheck source=lib.sh
. <(curl -sL https://raw.githubusercontent.com/morph027/vm/master/lib.sh)

# Tech and Me © - 2017, https://www.techandme.se/

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Activate the new config
printf "${Color_Off}Apache will now reboot"
any_key "Press any key to continue... "
a2ensite "$1"
a2dissite nextcloud_ssl_domain_self_signed.conf
a2dissite nextcloud_http_domain_self_signed.conf
a2dissite 000-default.conf
if service apache2 restart
then
    printf "${On_Green}New settings works! SSL is now activated and OK!${Color_Off}\n\n"
    echo "This cert will expire in 90 days, so you have to renew it."
    echo "There are several ways of doing so, here are some tips and tricks: https://goo.gl/c1JHR0"
    echo "This script will add a renew cronjob to get you started, edit it by typing:"
    echo "'crontab -u root -e'"
    echo "Feel free to contribute to this project: https://goo.gl/3fQD65"
    any_key "Press any key to continue..."
    crontab -u root -l | { cat; echo "@weekly $SCRIPTS/letsencryptrenew.sh"; } | crontab -u root -

FQDOMAIN=$(grep -m 1 "ServerName" "/etc/apache2/sites-enabled/$1" | awk '{print $2}')
if [ "$(hostname)" != "$FQDOMAIN" ]
then
    echo "Setting hostname to $FQDOMAIN..."
    sudo sh -c "echo 'ServerName $FQDOMAIN' >> /etc/apache2/apache2.conf"
    sudo hostnamectl set-hostname "$FQDOMAIN"
fi

# Update Config
run_static_script trusted

DATE="$(date +%Y-%m-%d_%H:%M)"
cat << CRONTAB > "$SCRIPTS/letsencryptrenew.sh"
#!/bin/sh
service apache2 stop
if ! certbot renew --quiet --no-self-upgrade > /var/log/letsencrypt/renew.log 2>&1 ; then
        echo "Let's Encrypt FAILED!"--$DATE >> /var/log/letsencrypt/cronjob.log
        service apache2 start
else
        echo "Let's Encrypt SUCCESS!"--$DATE >> /var/log/letsencrypt/cronjob.log
        service apache2 start
fi
CRONTAB

# Makeletsencryptrenew.sh executable
chmod +x $SCRIPTS/letsencryptrenew.sh

# Cleanup
rm $SCRIPTS/test-new-config.sh ## Remove ??
rm $SCRIPTS/activate-ssl.sh ## Remove ??

else
# If it fails, revert changes back to normal
    a2dissite "$1"
    a2ensite nextcloud_ssl_domain_self_signed.conf
    a2ensite nextcloud_http_domain_self_signed.conf
    a2ensite 000-default.conf
    service apache2 restart
    printf "${ICyan}Couldn't load new config, reverted to old settings. Self-signed SSL is OK!${Color_Off}\n"
    any_key "Press any key to continue... "
    exit 1
fi
