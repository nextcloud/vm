#!/bin/bash
true
SCRIPT_NAME="Test New Configuration"
# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh || source <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)

# T&M Hansson IT AB © - 2020, https://www.hanssonit.se/

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Activate the new config
msg_box "We will now test that everything is OK"
a2ensite "$1"
a2dissite "$TLS_CONF"
a2dissite "$HTTP_CONF"
a2dissite 000-default.conf
if restart_webserver
then
    msg_box "New settings works! TLS is now activated and OK!

This cert will expire in 90 days if you don't renew it.
There are several ways of renewing this cert and here are some tips and tricks:
https://goo.gl/c1JHR0

To do your job a little bit easier we have added a autorenew script as a cronjob.
If you need to edit the crontab please type: crontab -u root -e
If you need to edit the script itself, please check: $SCRIPTS/letsencryptrenew.sh

Feel free to contribute to this project: https://goo.gl/3fQD65"
    crontab -u root -l | { cat; echo "3 */12 * * * $SCRIPTS/letsencryptrenew.sh"; } | crontab -u root -

FQDOMAIN=$(grep -m 1 "ServerName" "/etc/apache2/sites-enabled/$1" | awk '{print $2}')
if [ "$(hostname)" != "$FQDOMAIN" ]
then
    print_text_in_color "$ICyan" "Setting hostname to $FQDOMAIN..."
    sudo sh -c "echo 'ServerName $FQDOMAIN' >> /etc/apache2/apache2.conf"
    sudo hostnamectl set-hostname "$FQDOMAIN"
    # Change /etc/hosts as well
    sed -i "s|127.0.1.1.*|127.0.1.1       $FQDOMAIN $(hostname -s)|g" /etc/hosts
    # And in the php-fpm pool conf
    sed -i "s|env\[HOSTNAME\] = .*|env[HOSTNAME] = $(hostname -f)|g" "$PHP_POOL_DIR"/nextcloud.conf
fi

# Set trusted domains
run_script NETWORK trusted

add_crontab_le() {
# shellcheck disable=SC2016
DATE='$(date +%Y-%m-%d_%H:%M)'
cat << CRONTAB > "$SCRIPTS/letsencryptrenew.sh"
#!/bin/sh
if ! certbot renew --quiet --no-self-upgrade > /var/log/letsencrypt/renew.log 2>&1 ; then
        echo "Let's Encrypt FAILED!"--$DATE >> /var/log/letsencrypt/cronjob.log
else
        echo "Let's Encrypt SUCCESS!"--$DATE >> /var/log/letsencrypt/cronjob.log
fi

# Check if service is running
if ! pgrep apache2 > /dev/null
then
    start_if_stopped apache2.service
fi
CRONTAB
}
add_crontab_le

# Makeletsencryptrenew.sh executable
chmod +x $SCRIPTS/letsencryptrenew.sh

# Cleanup
rm -f $SCRIPTS/test-new-config.sh
rm -f $SCRIPTS/activate-tls.sh
rm -f /var/www/index.php

else
# If it fails, revert changes back to normal
    a2dissite "$1"
    a2ensite "$TLS_CONF"
    a2ensite "$HTTP_CONF"
    a2ensite 000-default.conf
    restart_webserver
    msg_box "Couldn't load new config, reverted to old settings. Self-signed TLS is OK!"
    exit 1
fi
