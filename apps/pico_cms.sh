#!/bin/bash

# T&M Hansson IT AB © - 2024, https://www.hanssonit.se/
# Copyright © 2021 Simon Lindner (https://github.com/szaimen)

true
SCRIPT_NAME="Pico CMS"
SCRIPT_EXPLAINER="This script allows to easily install Pico CMS, a leightweight CMS integration in Nextcloud."
# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Check if root
root_check

# Nextcloud Main Domain
NCDOMAIN=$(nextcloud_occ_no_check config:system:get overwrite.cli.url | sed 's|https://||;s|/||')

# Check if Nextcloud is installed
print_text_in_color "$ICyan" "Checking if Nextcloud is installed..."
if ! curl -s https://"$NCDOMAIN"/status.php | grep -q 'installed":true'
then
    msg_box "It seems like Nextcloud is not installed or that you don't use https on:
$NCDOMAIN
Please install Nextcloud and make sure your domain is reachable, or activate TLS \
on your domain to be able to run this script.
If you use the Nextcloud VM you can use the Let's Encrypt script to get TLS and activate your Nextcloud domain."
    exit 1
fi
# Check apache conf
if ! [ -f "$SITES_AVAILABLE/$NCDOMAIN.conf" ]
then
    msg_box "It seems like you haven't used the built-in 'Activate TLS' script to enable 'Let's Encrypt!' \
on your instance. Unfortunately is this a requirement to be able to configure $SCRIPT_NAME successfully.
The installation will be aborted."
    exit 1
elif ! grep -q "<VirtualHost \*:443>" "$SITES_AVAILABLE/$NCDOMAIN.conf"
then
    msg_box "The virtualhost config doesn't seem to be the default. Cannot proceed."
    exit 1
fi

# Check if Pico CMS is already installed
if ! is_app_installed cms_pico
then
    # Ask for installing
    install_popup "$SCRIPT_NAME"
else
    # Ask for removal or reinstallation
    reinstall_remove_menu "$SCRIPT_NAME"
    # Removal
    if yesno_box_yes "Did you opted for using a different subdomain for Pico CMS when you installed it with this script?
If not, just choose 'No'."
    then
        SUBDOMAIN=$(input_box_flow "Please enter the subdomain that you've used for Pico CMS. \
E.g. 'sites.yourdomain.com' or 'blog.yourdomain.com'")
        if [ -f "$CERTFILES/$SUBDOMAIN/cert.pem" ]
        then
            yes no | certbot revoke --cert-path "$CERTFILES/$SUBDOMAIN/cert.pem"
            REMOVE_OLD="$(find "$LETSENCRYPTPATH/" -name "$SUBDOMAIN*")"
            for remove in $REMOVE_OLD
                do rm -rf "$remove"
            done
        fi
        # Remove Apache2 config
        if [ -f "$SITES_AVAILABLE/$SUBDOMAIN.conf" ]
        then
            a2dissite "$SUBDOMAIN".conf
            restart_webserver
            rm -f "$SITES_AVAILABLE/$SUBDOMAIN.conf"
        fi
        # Remove trusted domain
        remove_from_trusted_domains "$SUBDOMAIN"
    fi
    sed -i "/#Pico-CMS-start/,/#Pico-CMS-end/d" "$SITES_AVAILABLE/$NCDOMAIN.conf"
    systemctl restart apache2
    # Disable short links for Pico CMS
    nextcloud_occ config:app:set cms_pico link_mode --value=1
    nextcloud_occ app:remove cms_pico
    # Show successful uninstall if applicable
    removal_popup "$SCRIPT_NAME"
fi

# Install the app
install_and_enable_app cms_pico

# Add Apache config
sudo a2enmod proxy
sudo a2enmod proxy_http
cat << APACHE_PUSH_CONF > /tmp/apache.conf
    #Pico-CMS-start - Please don't remove or change this line
    ProxyPass /sites/ https://$NCDOMAIN/index.php/apps/cms_pico/pico_proxy/
    ProxyPassReverse /sites/ https://$NCDOMAIN/index.php/apps/cms_pico/pico_proxy/
    SSLProxyEngine on
    #Pico-CMS-end - Please don't remove or change this line"
APACHE_PUSH_CONF
sed -i '/<VirtualHost \*:443>/r /tmp/apache.conf' "$SITES_AVAILABLE/$NCDOMAIN.conf"
rm -f /tmp/apache.conf
if ! systemctl restart apache2
then
    msg_box "Failed to restart apache2. Will restore the old NCDOMAIN config now."
    sed -i "/#Pico-CMS-start/,/#Pico-CMS-end/d" "$SITES_AVAILABLE/$NCDOMAIN.conf"
    systemctl restart apache2
    nextcloud_occ_no_check app:remove cms_pico
    exit 1
fi

# Disable incompatible apps
# $1=app-id, $2=app-name, $3=additional-text
disable_incompatible_app() {
    if is_app_enabled "$1"
    then
        msg_box "It seems like the $2 is enabled.
Unfortunately, it has some incompatibility issues with Pico CMS.
Because of that it is recommended to disable it. $3"
        if yesno_box_yes "Do you want to disable the $2?"
        then
            nextcloud_occ app:disable "$1"
        fi
    fi
}

# Incompatible with text
disable_incompatible_app text "default Text app of Nextcloud" \
"\nThis script will install the Markdown editor and Plain text editor in exchange."

# Incompatible with issuetemplate
disable_incompatible_app issuetemplate "Issue Template app"

# Incompatible with terms_of_service
disable_incompatible_app terms_of_service "Terms of Service app"

# Install markdown and plain text editor
install_and_enable_app files_texteditor
install_and_enable_app files_markdown

# Enable short links
nextcloud_occ config:app:set cms_pico link_mode --value=2

# Inform user
msg_box "Congratulations, the base configuration of Pico CMS was successfully installed!"

# Make it available on a different domain
if ! yesno_box_no "Do you want to make your sites available on a different domain than your Nextcloud Domain?"
then
    exit
fi

# Ask for the domain for OnlyOffice
SUBDOMAIN=$(input_box_flow "Please enter your Sites subdomain e.g: 'sites.yourdomain.com' or 'blog.yourdomain.com'
NOTE: This domain must be different than your Nextcloud domain. \
They can however be hosted on the same server, but would require separate DNS entries.")

true
# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh

# Get all needed variables from the library
nc_update

# Notification
msg_box "Before continuing, please make sure that you have you have \
edited the DNS settings for $SUBDOMAIN, and opened port 80 and 443 \
directly to this servers IP. A full extensive guide can be found here:
https://www.techandme.se/open-port-80-443

This can be done automatically if you have UPNP enabled in your firewall/router. \
You will be offered to use UPNP in the next step.

PLEASE NOTE:
Using other ports than the default 80 and 443 is not supported, \
though it may be possible with some custom modification:
https://help.nextcloud.com/t/domain-refused-to-connect-collabora/91303/17"

if yesno_box_no "Do you want to use UPNP to open port 80 and 443?"
then
    unset FAIL
    open_port 80 TCP
    open_port 443 TCP
    cleanup_open_port
fi

# Get the latest packages
apt-get update -q4 & spinner_loading

# Check if $SUBDOMAIN exists and is reachable
print_text_in_color "$ICyan" "Checking if $SUBDOMAIN exists and is reachable..."
domain_check_200 "$SUBDOMAIN"

# Check open ports with NMAP
check_open_port 80 "$SUBDOMAIN"
check_open_port 443 "$SUBDOMAIN"

if yesno_box_yes "Do you want to make a specific Pico CMS site available when accessing '$SUBDOMAIN'?
Otherwise there will be a rewrite to your Nextcloud domain when accessing the subdomain which will show the login mask to strangers."
then
    PICO_SITE="$(input_box_flow "Please enter the Pico CMS site name that will be shown when accessing the subdomain.
e.g. 'example_site'\n
Note that it doesn't have to exist for this script and can get created by you in Pico CMS after finishing this script.
(The required site name is the sites 'Identifier' in Pico CMS's terminology.)")"
fi
# Install apache2
install_if_not apache2

# Enable Apache2 module's
a2enmod rewrite
a2enmod proxy
a2enmod proxy_http
a2enmod ssl
a2enmod headers

# Only add TLS 1.3 on Ubuntu later than 22.04
if version 22.04 "$DISTRO" 24.04.10
then
    TLS13="+TLSv1.3"
fi

if [ -f "$HTTPS_CONF" ]
then
    a2dissite "$SUBDOMAIN.conf"
    rm -f "$HTTPS_CONF"
fi

# Create Vhost for OnlyOffice Docker online in Apache2
if [ ! -f "$HTTPS_CONF" ];
then
    cat << HTTPS_CREATE > "$HTTPS_CONF"
<VirtualHost *:443>
     ServerName $SUBDOMAIN:443

    SSLCertificateChainFile $CERTFILES/$SUBDOMAIN/chain.pem
    SSLCertificateFile $CERTFILES/$SUBDOMAIN/cert.pem
    SSLCertificateKeyFile $CERTFILES/$SUBDOMAIN/privkey.pem
    SSLOpenSSLConfCmd DHParameters $DHPARAMS_SUB

    # Intermediate configuration
    SSLEngine               on
    SSLCompression          off
    SSLProtocol             -all +TLSv1.2 $TLS13
    SSLCipherSuite          ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384 
    SSLHonorCipherOrder     off
    SSLSessionTickets       off
    ServerSignature         off

    # Logs
    LogLevel warn
    CustomLog \${APACHE_LOG_DIR}/access.log combined
    ErrorLog \${APACHE_LOG_DIR}/error.log

    # Just in case - see below
    SSLProxyEngine On
    SSLProxyVerify None
    SSLProxyCheckPeerCN Off
    SSLProxyCheckPeerName Off

    # Improve security settings
    Header set X-XSS-Protection "1; mode=block"
    Header set Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
    Header set X-Content-Type-Options nosniff
    Header set Content-Security-Policy "frame-ancestors 'self'"

    # contra mixed content warnings
    RequestHeader set X-Forwarded-Proto "https"

    # basic proxy settings
    ProxyRequests off

    # Based on https://github.com/nextcloud/cms_pico/issues/83#issuecomment-637021453
    # For all resources outside of the cms pico directory (incl. the cms pico app itself)
    ProxyPass /apps/ https://$NCDOMAIN/apps/
    ProxyPassReverse /apps/ https://$NCDOMAIN/apps/
    # Needed for assets that keeps being referred as /sites/something
    ProxyPass /sites/ https://$NCDOMAIN/index.php/apps/cms_pico/pico_proxy/
    ProxyPassReverse /sites/ https://$NCDOMAIN/index.php/apps/cms_pico/pico_proxy/
    # For blog files themselves
    ProxyPassMatch "^/(..*)$" https://$NCDOMAIN/index.php/apps/cms_pico/pico_proxy/
    ProxyPassReverse / https://$NCDOMAIN/index.php/apps/cms_pico/pico_proxy/
    ProxyPass / https://$NCDOMAIN/index.php/apps/cms_pico/pico_proxy/$PICO_SITE

    # Based on https://github.com/nextcloud/cms_pico/issues/83#issuecomment-741758898
    # Rewrite root domain to Nextcloud if no Pico CMS site was chosen
    RewriteEngine on
    RewriteCond %{REQUEST_URI} ^/login [NC]
    RewriteRule ^ https://$NCDOMAIN%{REQUEST_URI} [END,NE,R=permanent]
    RewriteCond %{REQUEST_URI} ^/s/ [NC]
    RewriteRule ^ https://$NCDOMAIN%{REQUEST_URI} [END,NE,R=permanent]

</VirtualHost>
HTTPS_CREATE

    if [ -f "$HTTPS_CONF" ];
    then
        print_text_in_color "$IGreen" "$HTTPS_CONF was successfully created."
        sleep 1
    else
        print_text_in_color "$IRed" "Unable to create vhost, exiting..."
        print_text_in_color "$IRed" "Please report this issue here $ISSUES"
        exit 1
    fi
fi

# Install certbot (Let's Encrypt)
install_certbot

# Generate certs
if generate_cert "$SUBDOMAIN"
then
    # Generate DHparams cipher
    if [ ! -f "$DHPARAMS_SUB" ]
    then
        openssl dhparam -dsaparam -out "$DHPARAMS_SUB" 4096
    fi
    print_text_in_color "$IGreen" "Certs are generated!"
    a2ensite "$SUBDOMAIN.conf"
    restart_webserver
else
    exit 1
fi

# Appending the new domain to trusted domains
add_to_trusted_domains "$SUBDOMAIN"

# Inform user
msg_box "Pico CMS was successfully installed!
All public Pico CMS sites will be accessible in a subdir of 'https://$SUBDOMAIN/'.
An example URL is 'https://$SUBDOMAIN/example_site'.
('example_site' is here a Pico CMS site with the identifier 'example_site'.)"
if [ -n "$PICO_SITE" ]
then
    msg_box "And don't forget to create a public Pico CMS site with an identifier called '$PICO_SITE'!
Otherwise accessing the root domain will result in a 404 not found error."
fi
