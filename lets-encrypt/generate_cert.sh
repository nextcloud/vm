#!/bin/bash
#!/bin/bash
# shellcheck disable=2034,2059
true
# T&M Hansson IT AB © - 2019, https://www.hanssonit.se/

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Check if root
root_check


# Methods
# https://certbot.eff.org/docs/using.html#certbot-command-line-options
standalone() {
# Generate certs
if eval "certbot certonly --standalone --pre-hook 'service apache2 stop' --post-hook 'service apache2 start' $default_le"
then
    return 0
else
    return 1
fi
}

tls-alpn-01() {
if eval "certbot certonly --preferred-challenges tls-alpn-01 $default_le"
then
    return 0
else
    return 1
fi
}

dns() {
if eval "certbot certonly --manual --manual-public-ip-logging-ok --preferred-challenges dns $default_le"
then
    return 0
else
    return 1
fi
}

methods=(standalone dns)

create_config() {
#Check if $CERTFILES exists
if [ -d "$CERTFILES" ]
 then
    # Generate DHparams chifer
    if [ ! -f "$DHPARAMS" ]
    then
        openssl dhparam -dsaparam -out "$DHPARAMS" 4096
    fi
    # Activate new config
    if [ "$2" == "nextcloud" ]
    then
        check_command bash "$SCRIPTS/test-new-config.sh" "$1.conf"
        return 0
    else
        print_text_in_color "${IGreen}" "Certs are generated!"
        a2ensite "$1.conf"
        restart_webserver
        # Install OnlyOffice
        occ_command app:install $2
        return 0
    fi
fi
}

attempts_left() {
if [ "$1" == "standalone" ]
then
    print_text_in_color "${ICyan}" "It seems like no certs were generated, we will do 1 more try."
    any_key "Press any key to continue..."
#elif [ "$method" == "tls-alpn-01" ]
#then
#    print_text_in_color "${ICyan}" "It seems like no certs were generated, we will do 1 more try."
#    any_key "Press any key to continue..."
elif [ "$1" == "dns" ]
then
    print_text_in_color "${IRed}" "It seems like no certs were generated, please check your DNS and try again."
    any_key "Press any key to continue..."
    if [ "$2" == "nextcloud" ]
    then
        # Failed
        msg_box "Sorry, last try failed as well. :/

The script is located in $SCRIPTS/activate-ssl.sh
Please try to run it again some other time with other settings.

There are different configs you can try in Let's Encrypt's user guide:
https://letsencrypt.readthedocs.org/en/latest/index.html
Please check the guide for further information on how to enable SSL.

This script is developed on GitHub, feel free to contribute:
https://github.com/nextcloud/vm

The script will now do some cleanup and revert the settings."

        #Cleanup
        apt remove certbot -y
        apt autoremove -y
        clear
    else
        restart_webserver
        exit 1
    fi
fi
}

# Generate the cert
generate_cert() {
print_text_in_color "${ICyan}" "try to generate a cert and auto-configure it."
if [ "$2" == "nextcloud" ]
then
    default_le="--rsa-key-size 4096 --renew-by-default --no-eff-email --agree-tos  --uir --hsts --server https://acme-v02.api.letsencrypt.org/directory -d $1"
else
    a2dissite 000-default.conf
    service apache2 reload
    default_le="--rsa-key-size 4096 --renew-by-default --no-eff-email --agree-tos --server https://acme-v02.api.letsencrypt.org/directory -d $1"
fi
for f in "${methods[@]}";do
    if $f
    then
        create_config $1 $2
        return 0
    else
        attempts_left "$f" $2
    fi
done
}
