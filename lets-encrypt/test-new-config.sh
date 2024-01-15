#!/bin/bash
true
SCRIPT_NAME="Test New Configuration"
# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh

# T&M Hansson IT AB © - 2024, https://www.hanssonit.se/

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
    msg_box "New settings works! TLS is now activated and OK!"

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

# Set the domain as trusted
add_to_trusted_domains "$FQDOMAIN"
nextcloud_occ config:system:set overwrite.cli.url --value="https://$FQDOMAIN"
nextcloud_occ maintenance:update:htaccess

# Add crontab
cat << CRONTAB > "$SCRIPTS/letsencryptrenew.sh"
#!/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/snap/bin
echo '###################################'
if ! certbot renew >> /var/log/letsencrypt/cronjob.log 2>&1
then
    echo "Let's Encrypt FAILED!--$(date +%Y-%m-%d_%H:%M)" >> /var/log/letsencrypt/cronjob.log
else
    echo "Let's Encrypt SUCCESS!--$(date +%Y-%m-%d_%H:%M)" >> /var/log/letsencrypt/cronjob.log
fi
# Check if service is running
if ! pgrep apache2 > /dev/null
then
    systemctl start apache2.service
    if ! pgrep apache2 > /dev/null
    then
        # shellcheck source=lib.sh
        source /var/scripts/fetch_lib.sh
        notify_admin_gui "Could not start Apache!" "Please report this to $ISSUES!"
    fi
fi
CRONTAB
# Make letsencryptrenew.sh executable
chmod +x $SCRIPTS/letsencryptrenew.sh
# Add cronjob
crontab -u root -l | grep -v "$SCRIPTS/letsencryptrenew.sh" | crontab -u root -
crontab -u root -l | { cat; echo "3 */12 * * * $SCRIPTS/letsencryptrenew.sh >/dev/null"; } | crontab -u root -

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
