#/bin/bash
# shellcheck disable=2034,2059
true
# see https://github.com/koalaman/shellcheck/wiki/Directive

## VARIABLES

# Dirs
SCRIPTS=/var/scripts
NCPATH=/var/www/nextcloud
HTML=/var/www
NCDATA=/mnt/ncdata
SNAPDIR=/var/snap/spreedme
GPGDIR=/tmp/gpg
BACKUP=/mnt/NCBACKUP
RORDIR=/opt/es/
NC_APPS_PATH=$NCPATH/apps
VMLOGS=/var/log/nextcloud

# Ubuntu OS
DISTRO=$(lsb_release -sd | cut -d ' ' -f 2)
KEYBOARD_LAYOUT=$(localectl status | grep "Layout" | awk '{print $3}')
# Network
[ -n "$FIRST_IFACE" ] && IFACE=$(lshw -c network | grep "logical name" | awk '{print $3; exit}')
IFACE2=$(ip -o link show | awk '{print $2,$9}' | grep 'UP' | cut -d ':' -f 1)
[ -n "$CHECK_CURRENT_REPO" ] && REPO=$(apt-get update | grep -m 1 Hit | awk '{ print $2}')
ADDRESS=$(hostname -I | cut -d ' ' -f 1)
# WANIP4=$(dig +short myip.opendns.com @resolver1.opendns.com) # as an alternative
WANIP4=$(curl -s -k -m 5 https://ipv4bot.whatismyipaddress.com)
[ -n "$LOAD_IP6" ] && WANIP6=$(curl -s -k -m 5 https://ipv6bot.whatismyipaddress.com)
INTERFACES="/etc/netplan/01-netcfg.yaml"
GATEWAY=$(ip route | grep default | awk '{print $3}')
DNS1="9.9.9.9"
DNS2="149.112.112.112"
# Repo
GITHUB_REPO="https://raw.githubusercontent.com/nextcloud/vm/master"
STATIC="$GITHUB_REPO/static"
LETS_ENC="$GITHUB_REPO/lets-encrypt"
APP="$GITHUB_REPO/apps"
NCREPO="https://download.nextcloud.com/server/releases"
ISSUES="https://github.com/nextcloud/vm/issues"
# User information
NCPASS=nextcloud
NCUSER=ncadmin
UNIXUSER=$SUDO_USER
UNIXUSER_PROFILE="/home/$UNIXUSER/.bash_profile"
ROOT_PROFILE="/root/.bash_profile"
# Database
SHUF=$(shuf -i 25-29 -n 1)
MARIADB_PASS=$(tr -dc "a-zA-Z0-9@#*=" < /dev/urandom | fold -w "$SHUF" | head -n 1)
NEWMARIADBPASS=$(tr -dc "a-zA-Z0-9@#*=" < /dev/urandom | fold -w "$SHUF" | head -n 1)
[ -n "$NCDB" ] && NCCONFIGDB=$(grep "dbname" $NCPATH/config/config.php | awk '{print $3}' | sed "s/[',]//g")
ETCMYCNF=/etc/mysql/my.cnf
MYCNF=/root/.my.cnf
[ -n "$MYCNFPW" ] && MARIADBMYCNFPASS=$(grep "password" $MYCNF | sed -n "/password/s/^password='\(.*\)'$/\1/p")
PGDB_PASS=$(tr -dc "a-zA-Z0-9@#*=" < /dev/urandom | fold -w "$SHUF" | head -n 1)
NEWPGPASS=$(tr -dc "a-zA-Z0-9@#*=" < /dev/urandom | fold -w "$SHUF" | head -n 1)
[ -n "$NCDB" ] && NCCONFIGDB=$(grep "dbname" $NCPATH/config/config.php | awk '{print $3}' | sed "s/[',]//g")
[ -n "$NCDBPASS" ] && NCCONFIGDBPASS=$(grep "dbpassword" $NCPATH/config/config.php | awk '{print $3}' | sed "s/[',]//g")
# Path to specific files
SECURE="$SCRIPTS/setup_secure_permissions_nextcloud.sh"

# Nextcloud version
[ -n "$NC_UPDATE" ] && CURRENTVERSION=$(sudo -u www-data php $NCPATH/occ status | grep "versionstring" | awk '{print $3}')
[ -n "$NC_UPDATE" ] && NCVERSION=$(curl -s -m 900 $NCREPO/ | sed --silent 's/.*href="nextcloud-\([^"]\+\).zip.asc".*/\1/p' | sort --version-sort | tail -1)
[ -n "$NC_UPDATE" ] && STABLEVERSION="nextcloud-$NCVERSION"
[ -n "$NC_UPDATE" ] && NCMAJOR="${NCVERSION%%.*}"
[ -n "$NC_UPDATE" ] && NCBAD=$((NCMAJOR-2))
# Keys
OpenPGP_fingerprint='28806A878AE423A28372792ED75899B9A724937A'
# OnlyOffice URL (onlyoffice.sh)
[ -n "$OO_INSTALL" ] && SUBDOMAIN=$(whiptail --title "T&M Hansson IT OnlyOffice" --inputbox "OnlyOffice subdomain eg: office.yourdomain.com\n\nNOTE: This domain must be different than your Nextcloud domain. They can however be hosted on the same server, but would require seperate DNS entries." "$WT_HEIGHT" "$WT_WIDTH" 3>&1 1>&2 2>&3)
# Nextcloud Main Domain (onlyoffice.sh)
[ -n "$OO_INSTALL" ] && NCDOMAIN=$(whiptail --title "T&M Hansson IT OnlyOffice" --inputbox "Nextcloud domain, make sure it looks like this: cloud\\.yourdomain\\.com" "$WT_HEIGHT" "$WT_WIDTH" cloud\\.yourdomain\\.com 3>&1 1>&2 2>&3)
# Collabora Docker URL (collabora.sh
[ -n "$COLLABORA_INSTALL" ] && SUBDOMAIN=$(whiptail --title "T&M Hansson IT Collabora" --inputbox "Collabora subdomain eg: office.yourdomain.com\n\nNOTE: This domain must be different than your Nextcloud domain. They can however be hosted on the same server, but would require seperate DNS entries." "$WT_HEIGHT" "$WT_WIDTH" 3>&1 1>&2 2>&3)
# Nextcloud Main Domain (collabora.sh)
[ -n "$COLLABORA_INSTALL" ] && NCDOMAIN=$(whiptail --title "T&M Hansson IT Collabora" --inputbox "Nextcloud domain, make sure it looks like this: cloud\\.yourdomain\\.com" "$WT_HEIGHT" "$WT_WIDTH" cloud\\.yourdomain\\.com 3>&1 1>&2 2>&3)
# Nextcloud Main Domain (activate-ssl.sh)
[ -n "$TLS_INSTALL" ] && TLSDOMAIN=$(whiptail --title "T&M Hansson IT Let's Encrypt" --inputbox "Nextcloud domain, make sure it looks like this: cloud.yourdomain.com" "$WT_HEIGHT" "$WT_WIDTH" cloud.yourdomain.com 3>&1 1>&2 2>&3)

# Letsencrypt
SITES_AVAILABLE="/etc/apache2/sites-available"
LETSENCRYPTPATH="/etc/letsencrypt"
CERTFILES="$LETSENCRYPTPATH/live"
DHPARAMS_TLS="$CERTFILES/$TLSDOMAIN/dhparam.pem"
DHPARAMS_SUB="$CERTFILES/$SUBDOMAIN/dhparam.pem"
TLS_CONF="nextcloud_tls_domain_self_signed.conf"
HTTP_CONF="nextcloud_http_domain_self_signed.conf"
# Collabora App
HTTPS_CONF="$SITES_AVAILABLE/$SUBDOMAIN.conf"
HTTP2_CONF="/etc/apache2/mods-available/http2.conf"
# PHP-FPM
PHPVER=7.2
PHP_FPM_DIR=/etc/php/$PHPVER/fpm
PHP_INI=$PHP_FPM_DIR/php.ini
PHP_POOL_DIR=$PHP_FPM_DIR/pool.d
# Adminer
ADMINERDIR=/usr/share/adminer
ADMINER_CONF=/etc/apache2/conf-available/adminer.conf
# Redis
REDIS_CONF=/etc/redis/redis.conf
REDIS_SOCK=/var/run/redis/redis-server.sock
RSHUF=$(shuf -i 30-35 -n 1)
REDIS_PASS=$(tr -dc "a-zA-Z0-9@#*=" < /dev/urandom | fold -w "$RSHUF" | head -n 1)
# Extra security
SPAMHAUS=/etc/spamhaus.wl
ENVASIVE=/etc/apache2/mods-available/mod-evasive.load
APACHE2=/etc/apache2/apache2.conf
# Full text Search
[ -n "$ES_INSTALL" ] && INDEX_USER=$(tr -dc '[:lower:]' < /dev/urandom | fold -w "$SHUF" | head -n 1)
[ -n "$ES_INSTALL" ] && ROREST=$(tr -dc "A-Za-z0-9" < /dev/urandom | fold -w "$SHUF" | head -n 1)
[ -n "$ES_INSTALL" ] && nc_fts="ark74/nc_fts"
[ -n "$ES_INSTALL" ] && fts_es_name="fts_esror"
# Talk
[ -n "$TURN_INSTALL" ] && TURN_CONF="/etc/turnserver.conf"
[ -n "$TURN_INSTALL" ] && TURN_PORT=5349
[ -n "$TURN_INSTALL" ] && SHUF=$(shuf -i 25-29 -n 1)
[ -n "$TURN_INSTALL" ] && TURN_SECRET=$(tr -dc "a-zA-Z0-9@#*=" < /dev/urandom | fold -w "$SHUF" | head -n 1)
[ -n "$TURN_INSTALL" ] && TURN_DOMAIN=$(sudo -u www-data /var/www/nextcloud/occ config:system:get overwrite.cli.url | sed 's#https://##;s#/##')

## FUNCTIONS

# If script is running as root?
#
# Example:
# if is_root
# then
#     # do stuff
# else
#     print_text_in_color "$IRed" "You are not root..."
#     exit 1
# fi
#
is_root() {
    if [[ "$EUID" -ne 0 ]]
    then
        return 1
    else
        return 0
    fi
}

# Check if root
root_check() {
if ! is_root
then
msg_box "Sorry, you are not root. You now have two options:

1. With SUDO directly:
   a) :~$ sudo bash $SCRIPTS/name-of-script.sh

2. Become ROOT and then type your command:
   a) :~$ sudo -i
   b) :~# bash $SCRIPTS/name-of-script.sh

In both cases above you can leave out $SCRIPTS/ if the script
is directly in your PATH.

More information can be found here: https://unix.stackexchange.com/a/3064"
    exit 1
fi
}

debug_mode() {
if [ "$DEBUG" -eq 1 ]
then
    set -ex
fi
}

ask_yes_or_no() {
    read -r -p "$1 ([y]es or [N]o): "
    case ${REPLY,,} in
        y|yes)
            echo "yes"
        ;;
        *)
            echo "no"
        ;;
    esac
}

msg_box() {
local PROMPT="$1"
    whiptail --title "Nextcloud VM - T&M Hansson IT - $(date +"%Y")" --msgbox "${PROMPT}" "$WT_HEIGHT" "$WT_WIDTH"
}

# Check if process is runnnig: is_process_running dpkg
is_process_running() {
PROCESS="$1"

while :
do
    RESULT=$(pgrep "${PROCESS}")

    if [ "${RESULT:-null}" = null ]; then
            break
    else
            print_text_in_color "$ICyan" "${PROCESS} is running, waiting for it to stop..."
            sleep 10
    fi
done
}

# Checks if site is reachable with a HTTP 200 status
site_200() {
print_text_in_color "$ICyan" "Checking connection..."
        CURL_STATUS="$(curl -sSL -w "%{http_code}" "${1}" | tail -1)"
        if [[ "$CURL_STATUS" = "200" ]]
        then
            return 0
        else
            print_text_in_color "$IRed" "curl didn't produce a 200 status, is the site reachable?"
            return 1
        fi
}

# Do a DNS lookup and compare the WAN address with the A record
domain_check_200() {
    print_text_in_color "$ICyan" "Doing a DNS lookup for ${1}..."
    install_if_not dnsutils

    # Try to resolve the domain with nslookup using $DNS as resolver
    if nslookup "${1}" $DNS1 >/dev/null 2>&1
    then
        print_text_in_color "$IGreen" "DNS seems correct when checking with nslookup!"
    else
        print_text_in_color "$IRed" "DNS lookup failed with nslookup."
        print_text_in_color "$IRed" "Please check your DNS settings! Maybe the domain isn't propagated?"
        print_text_in_color "$ICyan" "Please check https://www.whatsmydns.net/#A/${1} if the IP seems correct."
        nslookup "${1}" $DNS1
        return 1
    fi

    # Is the DNS record same as the external IP address of the server?
    DIG="$(dig +short "${1}" @resolver1.opendns.com)"
    if [[ "$DIG" = "$WANIP4" ]]
    then
        print_text_in_color "$IGreen" "DNS seems correct when checking with dig!"
    elif [[ "$DIG" != "$WANIP4" ]]
    then
msg_box "DNS lookup failed with dig. The external IP ($WANIP4) address of this server is not the same as the A-record ($DIG).
Please check your DNS settings! Maybe the domain isn't propagated?
Please check https://www.whatsmydns.net/#A/${1} if the IP seems correct."

msg_box "As you noticed your WAN IP and DNS record doesn't match. This can happen when using DDNS for example, or in some edge cases.
If you feel brave, or are sure that everything is setup correctly, then you can choose to skip this test in the next step.

You can always contact us for further support if you wish: https://shop.hanssonit.se/product/premium-support-per-30-minutes/"
        if [[ "no" == $(ask_yes_or_no "Do you feel brave and want to continue?") ]]
            then
            exit
        fi
    fi
}

# A function to fetch a file with curl to a directory
# 1 = https://example.com
# 2 = name of file
# 3 = directory that the file should end up in
curl_to_dir() {
if [ ! -d "$3" ]
then
    mkdir -p "$3"
fi
    rm -f "$3"/"$2"
    curl -sfL "$1"/"$2" -o "$3"/"$2"
}

start_if_stopped() {
if ! pgrep "$1"
then
    print_text_in_color "$ICyan" "Starting $1..."
    check_command service "$1" start
fi
}

# Warn user that HTTP/2 will be disabled if installing app that use Apache2 PHP instead of PHP-FPM
# E.g: http2_warn Modsecurity
http2_warn() {
msg_box "This VM has HTTP/2 enabled by default. 

If you continue with installing $1, HTTP/2 will be disabled since it's not compatible with the mpm module used by $1.

This is what Apache will say in the error.log if you enable $1 anyway:
'The mpm module (prefork.c) is not supported by mod_http2.
The mpm determines how things are processed in your server.
HTTP/2 has more demands in this regard and the currently selected mpm will just not do.
This is an advisory warning. Your server will continue to work, but the HTTP/2 protocol will be inactive.'"

if [[ "no" == $(ask_yes_or_no "Do you really want to enable $1 anyway?") ]]
then
    exit 1
fi
}

calculate_php_fpm() {
# Minimum amount of max children (lower than this won't work with 2 GB RAM)
min_max_children=8
# If start servers are lower than this then it's likely that there are room for max_spare_servers
min_start_servers=20
# Maximum amount of children is only set if the min_start_servers value are met
min_max_spare_servers=35

# Calculate the sum of the current values
CURRENT_START="$(grep pm.start_servers "$PHP_POOL_DIR"/nextcloud.conf | awk '{ print $3}')"
CURRENT_MAX="$(grep pm.max_spare_servers "$PHP_POOL_DIR"/nextcloud.conf | awk '{ print $3}')"
CURRENT_MIN="$(grep pm.min_spare_servers "$PHP_POOL_DIR"/nextcloud.conf | awk '{ print $3}')"
CURRENT_SUM="$((CURRENT_START + CURRENT_MAX + CURRENT_MIN))"

# Calculate max_children depending on RAM
# Tends to be between 30-50MB per children
average_php_memory_requirement=50
available_memory=$(awk '/MemAvailable/ {printf "%d", $2/1024}' /proc/meminfo)
PHP_FPM_MAX_CHILDREN=$((available_memory/average_php_memory_requirement))

# Lowest possible value is 8
print_text_in_color "$ICyan" "Automatically configures pm.max_children for php-fpm..."
if [ $PHP_FPM_MAX_CHILDREN -lt $min_max_children ]
then
msg_box "The current max_children value available to set is $PHP_FPM_MAX_CHILDREN, and with that value PHP-FPM won't function properly.
The minimum value is 8, and the value is calculated depening on how much RAM you have left to use in the system.

The absolute minimum amount of RAM required to run the VM is 2 GB, but we recomend 4 GB.

You now have two choices:
1. Import this VM again, raise the amount of RAM with at least 1 GB, and then run this script again,
   installing it in the same way as you did before.
2. Import this VM again without raising the RAM, but don't install any of the following apps:
   1) Collabora
   2) OnlyOffice
   3) Full Text Search

This script will now exit.
The installation was not successful, sorry for the inconvenience.

If you think this is a bug, please report it to $ISSUES"
exit 1
else
    check_command sed -i "s|pm.max_children.*|pm.max_children = $PHP_FPM_MAX_CHILDREN|g" "$PHP_POOL_DIR"/nextcloud.conf
    print_text_in_color "$IGreen" "pm.max_children was set to $PHP_FPM_MAX_CHILDREN"
    # Check if the sum of all the current values are more than $PHP_FPM_MAX_CHILDREN and only continue it is
    if [ $PHP_FPM_MAX_CHILDREN -gt $CURRENT_SUM ]
    then
        # Set pm.max_spare_servers
        if [ $PHP_FPM_MAX_CHILDREN -ge $min_max_spare_servers ]
        then
            if [ "$(grep pm.start_servers "$PHP_POOL_DIR"/nextcloud.conf | awk '{ print $3}')" -lt $min_start_servers ]
            then
                check_command sed -i "s|pm.max_spare_servers.*|pm.max_spare_servers = $((PHP_FPM_MAX_CHILDREN - 30))|g" "$PHP_POOL_DIR"/nextcloud.conf
                print_text_in_color "$IGreen" "pm.max_spare_servers was set to $((PHP_FPM_MAX_CHILDREN - 30))"
            fi
        fi
    fi
fi

# If $PHP_FPM_MAX_CHILDREN is lower than the current sum of all values, revert to default settings
if [ $PHP_FPM_MAX_CHILDREN -lt $CURRENT_SUM ]
then
    check_command sed -i "s|pm.max_children.*|pm.max_children = $PHP_FPM_MAX_CHILDREN|g" "$PHP_POOL_DIR"/nextcloud.conf
    check_command sed -i "s|pm.start_servers.*|pm.start_servers = 3|g" "$PHP_POOL_DIR"/nextcloud.conf
    check_command sed -i "s|pm.min_spare_servers.*|pm.min_spare_servers = 2|g" "$PHP_POOL_DIR"/nextcloud.conf
    check_command sed -i "s|pm.max_spare_servers.*|pm.max_spare_servers = 3|g" "$PHP_POOL_DIR"/nextcloud.conf
    print_text_in_color "$ICyan" "All PHP-INI values were set back to default values as the value for pm.max_children ($PHP_FPM_MAX_CHILDREN) was lower than the sum of all the current values ($CURRENT_SUM)"
    print_text_in_color "$ICyan" "Please run this again to set optimal values"
fi
restart_webserver
}

test_connection() {
# Install dnsutils if not existing
if ! dpkg-query -W -f='${Status}' "dnsutils" | grep -q "ok installed"
then
    apt update -q4 & spinner_loading && apt install dnsutils -y
fi
# Install network-manager if not existing
if ! dpkg-query -W -f='${Status}' "network-manager" | grep -q "ok installed"
then
    apt update -q4 & spinner_loading && apt install network-manager -y
fi
check_command service network-manager restart
ip link set "$IFACE" down
sleep 2
ip link set "$IFACE" up
sleep 2
print_text_in_color "$ICyan" "Checking connection..."
check_command service network-manager restart
sleep 2
if nslookup github.com
then
    print_text_in_color "$IGreen" "Online!"
elif ! nslookup github.com
then
    print_text_in_color "$ICyan" "Trying to restart networking service..."
    check_command service networking restart && sleep 2
    if nslookup github.com
    then
        print_text_in_color "$IGreen" "Online!"
    fi
else
    if ! nslookup github.com
    then
msg_box "Network NOT OK. You must have a working network connection to run this script
If you think that this is a bug, please report it to https://github.com/nextcloud/vm/issues."
    exit 1
    fi
fi
}

restart_webserver() {
check_command systemctl restart apache2
if is_this_installed php"$PHPVER"-fpm
then
    check_command systemctl restart php"$PHPVER"-fpm.service
fi

}

# Install certbot (Let's Encrypt)
install_certbot() {
certbot --version 2> /dev/null
LE_IS_AVAILABLE=$?
if [ $LE_IS_AVAILABLE -eq 0 ]
then
    certbot --version 2> /dev/null
else
    print_text_in_color "$ICyan" "Installing certbot (Let's Encrypt)..."
    apt update -q4 & spinner_loading
    install_if_not software-properties-common
    add-apt-repository ppa:certbot/certbot -y
    apt update -q4 & spinner_loading
    install_if_not certbot
    apt update -q4 & spinner_loading
    apt dist-upgrade -y
fi
}

#generate certs and auto-configure
# https://certbot.eff.org/docs/using.html#certbot-command-line-options
generate_cert() {
uir_hsts=""
disable_000=""
if [ -z "$SUBDOMAIN" ]
then
    uir_hsts="--uir --hsts"
fi
if [ -e $SITES_AVAILABLE/../sites-enabled/000-default.conf ]
then
    a2dissite 000-default.conf
    systemctl reload apache2
    disable_000="yes"
fi
default_le="--rsa-key-size 4096 --renew-by-default --no-eff-email --agree-tos $uir_hsts --server https://acme-v02.api.letsencrypt.org/directory -d $1"
#http-01
local  standalone="certbot certonly --standalone --pre-hook 'service apache2 stop' --post-hook 'service apache2 start' $default_le"
#tls-alpn-01
local  tls_alpn_01="certbot certonly --preferred-challenges tls-alpn-01 $default_le"
#dns
local  dns="certbot certonly --manual --manual-public-ip-logging-ok --preferred-challenges dns $default_le"
local  methods=(standalone dns)

for f in ${methods[*]}
do
    print_text_in_color "${ICyan}" "Trying to generate certs and validate them with $f method."
    current_method="\$$f"
    if eval "$current_method"
    then
        return 0
    elif [ "$f" != "${methods[$((${#methods[*]} - 1))]}" ]
    then
        print_text_in_color "${ICyan}" "It seems like no certs were generated when trying to validate them with the $f method. We will do more tries."
        any_key "Press any key to continue..."
    else
        print_text_in_color "${ICyan}" "It seems like no certs were generated when trying to validate them with the $f method. We have tried all the methods. Please check your DNS and try again."
        any_key "Press any key to continue..."
        if [ -n "$disable_000" ]
        then
            a2ensite 000-default.conf
            systemctl reload apache2
        fi
        return 1;
    fi
done
}

# Last message depending on with script that is being run when using the generate_cert() function
last_fail_tls() {
msg_box "All methods failed. :/

The script is located in ${1}
Please try to run it again some other time with other settings.

There are different configs you can try in Let's Encrypt's user guide:
https://letsencrypt.readthedocs.org/en/latest/index.html
Please check the guide for further information on how to enable SSL.

This script is developed on GitHub, feel free to contribute:
https://github.com/nextcloud/vm"

if [ -n "$2" ]
then
    print_text_in_color "$ICyan" "The script will now do some cleanup and revert the settings."
    any_key "Press any key to start the cleanup..."
    # Cleanup
    apt remove certbot -y
    apt autoremove -y
fi

# Restart webserver services
restart_webserver
}

# Check if port is open # check_open_port 443 domain.example.com
check_open_port() {
print_text_in_color "$ICyan" "Checking if port ${1} is open with https://ports.yougetsignal.com..."
install_if_not curl
# WAN Adress
if check_command curl -s -H 'Cache-Control: no-cache' 'https://ports.yougetsignal.com/check-port.php' --data "remoteAddress=${WANIP4}&portNumber=${1}" | grep -q "is open on"
then
    print_text_in_color "$IGreen" "Port ${1} is open on ${WANIP4}!"
# Domain name
elif check_command curl -s -H 'Cache-Control: no-cache' 'https://ports.yougetsignal.com/check-port.php' --data "remoteAddress=${2}&portNumber=${1}" | grep -q "is open on"
then
    print_text_in_color "$IGreen" "Port ${1} is open on ${2}!"
else
msg_box "It seems like the port ${1} is closed. This could happend when your
ISP has blocked the port, or that the port isn't open.

If you are 100% sure the port ${1} is open you can now choose to
continue. There are no guarantees that it will work anyway though,
since Let's Encrypt depend on that the port ${1} is open and
accessible from outside your network."
    if [[ "no" == $(ask_yes_or_no "Are you 100% sure the port ${1} is open?") ]]
    then
        msg_box "Port $1 is not open on either ${WANIP4} or ${2}.\n\nPlease follow this guide to open ports in your router or firewall:\nhttps://www.techandme.se/open-port-80-443/"
        any_key "Press any key to exit..."
        exit 1
    fi
fi
}

check_distro_version() {
# Check Ubuntu version
print_text_in_color "$ICyan" "Checking server OS and version..."
if lsb_release -c | grep -ic "bionic" &> /dev/null
then
    OS=1
elif lsb_release -i | grep -ic "Ubuntu" &> /dev/null
then 
    OS=1
elif uname -a | grep -ic "bionic" &> /dev/null
then
    OS=1
elif uname -v | grep -ic "Ubuntu" &> /dev/null
then 
    OS=1
fi

if [ "$OS" != 1 ]
then
msg_box "Ubuntu Server is required to run this script.
Please install that distro and try again.

You can find the download link here: https://www.ubuntu.com/download/server"
    exit 1
fi

if ! version 18.04 "$DISTRO" 18.04.4; then
msg_box "Ubuntu version $DISTRO must be between 18.04 - 18.04.4"
    exit 1
fi
}

# Check if program is installed (stop_if_installed apache2)
stop_if_installed() {
if [ "$(dpkg-query -W -f='${Status}' "${1}" 2>/dev/null | grep -c "ok installed")" == "1" ]
then
    print_text_in_color "$IRed" "${1} is installed, it must be a clean server."
    exit 1
fi
}

# Check if program is installed (is_this_installed apache2)
is_this_installed() {
if dpkg-query -W -f='${Status}' "${1}" | grep -q "ok installed"
then
    return 0
else
    return 1
fi
}

# Install_if_not program
install_if_not() {
if ! dpkg-query -W -f='${Status}' "${1}" | grep -q "ok installed"
then
    apt update -q4 & spinner_loading && apt install "${1}" -y
fi
}

# Test RAM size
# Call it like this: ram_check [amount of min RAM in GB] [for which program]
# Example: ram_check 2 Nextcloud
ram_check() {
mem_available="$(awk '/MemTotal/{print $2}' /proc/meminfo)"
if [ "${mem_available}" -lt "$((${1}*1002400))" ]
then
    print_text_in_color "$IRed" "Error: ${1} GB RAM required to install ${2}!" >&2
    print_text_in_color "$IRed" "Current RAM is: ("$((mem_available/1002400))" GB)" >&2
    sleep 3
    msg_box "If you want to bypass this check you could do so by commenting out (# before the line) 'ram_check X' in the script that you are trying to run.

    In nextcloud_install_production.sh you can find the check somewhere around line #98.

    Please notice that things may be veery slow and not work as expeced. YOU HAVE BEEN WARNED!"
    exit 1
else
    print_text_in_color "$IGreen" "RAM for ${2} OK! ($((mem_available/1002400)) GB)"
fi
}

# Test number of CPU
# Call it like this: cpu_check [amount of min CPU] [for which program]
# Example: cpu_check 2 Nextcloud
cpu_check() {
nr_cpu="$(nproc)"
if [ "${nr_cpu}" -lt "${1}" ]
then
    print_text_in_color "$IRed" "Error: ${1} CPU required to install ${2}!" >&2
    print_text_in_color "$IRed" "Current CPU: ($((nr_cpu)))" >&2
    sleep 3
    exit 1
else
    print_text_in_color "$IGreen" "CPU for ${2} OK! ($((nr_cpu)))"
fi
}

check_command() {
if ! "$@";
then
    print_text_in_color "$ICyan" "Sorry but something went wrong. Please report this issue to $ISSUES and include the output of the error message. Thank you!"
    print_text_in_color "$IRed" "$* failed"
    exit 1
fi
}

# Example: occ_command 'maintenance:mode --on'
occ_command() {
check_command sudo -u www-data php "$NCPATH"/occ "$@";
}

network_ok() {
    print_text_in_color "$ICyan" "Testing if network is OK..."
    install_if_not network-manager
    if ! service network-manager restart > /dev/null
    then
        service networking restart > /dev/null
    fi
    sleep 5 && site_200 github.com
}

# Whiptail auto-size
calc_wt_size() {
    WT_HEIGHT=17
    WT_WIDTH=$(tput cols)

    if [ -z "$WT_WIDTH" ] || [ "$WT_WIDTH" -lt 60 ]; then
        WT_WIDTH=80
    fi
    if [ "$WT_WIDTH" -gt 178 ]; then
        WT_WIDTH=120
    fi
    WT_MENU_HEIGHT=$((WT_HEIGHT-7))
    export WT_MENU_HEIGHT
}

install_and_enable_app() {
# Download and install $1
if [ ! -d "$NC_APPS_PATH/$1" ]
then
    print_text_in_color "$ICyan" "Installing $1..."
    # occ_command not possible here because it uses check_command and will exit if occ_command fails
    installcmd="$(sudo -u www-data php ${NCPATH}/occ app:install "$1")"
    if grep 'not compatible' <<< "$installcmd"
    then
msg_box "The $1 app could not be installed.
It's probably not compatible with $(occ_command -V).

You can try to install the app manually after the script has finished,
or when a new version of the app is released with the following command:

'sudo -u www-data php ${NCPATH}/occ app:install $1'"
    rm -Rf "$NCPATH/apps/$1"
    else
        # Enable $1
        if [ -d "$NC_APPS_PATH/$1" ]
        then
            occ_command app:enable "$1"
            chown -R www-data:www-data "$NC_APPS_PATH"
        fi
    fi
else
    print_text_in_color "$ICyan" "It seems like $1 is installed already, trying to enable it..."
    # occ_command not possible here because it uses check_command and will exit if occ_command fails
    sudo -u www-data php ${NCPATH}/occ app:enable "$1"
    chown -R www-data:www-data "$NC_APPS_PATH"
fi
}

download_verify_nextcloud_stable() {
while [ -z "$NCVERSION" ]
do
    print_text_in_color "$ICyan" "Fetching the latest Nextcloud version..."
    NCVERSION=$(curl -s -m 900 $NCREPO/ | sed --silent 's/.*href="nextcloud-\([^"]\+\).zip.asc".*/\1/p' | sort --version-sort | tail -1)
    STABLEVERSION="nextcloud-$NCVERSION"
    print_text_in_color "$IGreen" "$NCVERSION"
done
install_if_not gnupg
rm -f "$HTML/$STABLEVERSION.tar.bz2"
cd $HTML
print_text_in_color "$ICyan" "Downloading $STABLEVERSION..."
curl -fSLO --retry 3 "$NCREPO/$STABLEVERSION.tar.bz2"
mkdir -p "$GPGDIR"
curl_to_dir "$NCREPO" "$STABLEVERSION.tar.bz2.asc" "$GPGDIR"
chmod -R 600 "$GPGDIR"
gpg --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys "$OpenPGP_fingerprint"
gpg --verify "$GPGDIR/$STABLEVERSION.tar.bz2.asc" "$HTML/$STABLEVERSION.tar.bz2"
rm -r "$GPGDIR"
rm -f releases
}

# Initial download of script in ../static
# call like: download_static_script name_of_script
download_static_script() {
    # Get ${1} script
    rm -f "${SCRIPTS}/${1}.sh" "${SCRIPTS}/${1}.php" "${SCRIPTS}/${1}.py"
    if ! { curl_to_dir "${STATIC}" "${1}.sh" "$SCRIPTS" || curl_to_dir "${STATIC}" "${1}.php" "$SCRIPTS" || curl_to_dir "${STATIC}" "${1}.py" "$SCRIPTS"; }
    then
        print_text_in_color "$IRed" "{$1} failed to download. Please run: 'sudo curl -sLO ${STATIC}/${1}.sh|.php|.py' again."
        print_text_in_color "$ICyan" "If you get this error when running the nextcloud-startup-script then just re-run it with:"
        print_text_in_color "$ICyan" "'sudo bash $SCRIPTS/nextcloud-startup-script.sh' and all the scripts will be downloaded again"
        exit 1
    fi
}

# Initial download of script in ../lets-encrypt
# call like: download_le_script name_of_script
download_le_script() {
    # Get ${1} script
    rm -f "${SCRIPTS}/${1}.sh" "${SCRIPTS}/${1}.php" "${SCRIPTS}/${1}.py"
    if ! { curl_to_dir "${LETS_ENC}" "${1}.sh" "$SCRIPTS" || curl_to_dir "${LETS_ENC}" "${1}.php" "$SCRIPTS" || curl_to_dir "${LETS_ENC}" "${1}.py" "$SCRIPTS"; }
    then
        print_text_in_color "$IRed" "{$1} failed to download. Please run: 'sudo curl -sLO ${STATIC}/${1}.sh|.php|.py' again."
        print_text_in_color "$ICyan" "If you get this error when running the nextcloud-startup-script then just re-run it with:"
        print_text_in_color "$ICyan" "'sudo bash $SCRIPTS/nextcloud-startup-script.sh' and all the scripts will be downloaded again"
        exit 1
    fi
}

# Run any script in ../master
# call like: run_main_script name_of_script
run_main_script() {
    rm -f "${SCRIPTS}/${1}.sh" "${SCRIPTS}/${1}.php" "${SCRIPTS}/${1}.py"
    if curl_to_dir "${GITHUB_REPO}" "${1}.sh" "$SCRIPTS"
    then
        bash "${SCRIPTS}/${1}.sh"
        rm -f "${SCRIPTS}/${1}.sh"
    elif curl_to_dir "${GITHUB_REPO}" "${1}.php" "$SCRIPTS"
    then
        php "${SCRIPTS}/${1}.php"
        rm -f "${SCRIPTS}/${1}.php"
    elif curl_to_dir "${GITHUB_REPO}" "${1}.py" "$SCRIPTS"
    then
        install_if_not python3
        python3 "${SCRIPTS}/${1}.py"
        rm -f "${SCRIPTS}/${1}.py"
    else
        print_text_in_color "$IRed" "Downloading ${1} failed"
        print_text_in_color "$ICyan" "Script failed to download. Please run: 'sudo curl -sLO ${GITHUB_REPO}/${1}.sh|php|py' again."
        exit 1
    fi
}

# Run any script in ../static
# call like: run_static_script name_of_script
run_static_script() {
    # Get ${1} script
    rm -f "${SCRIPTS}/${1}.sh" "${SCRIPTS}/${1}.php" "${SCRIPTS}/${1}.py"
    if curl_to_dir "${STATIC}" "${1}.sh" "$SCRIPTS"
    then
        bash "${SCRIPTS}/${1}.sh"
        rm -f "${SCRIPTS}/${1}.sh"
    elif curl_to_dir "${STATIC}" "${1}.php" "$SCRIPTS"
    then
        php "${SCRIPTS}/${1}.php"
        rm -f "${SCRIPTS}/${1}.php"
    elif curl_to_dir "${STATIC}" "${1}.py" "$SCRIPTS"
    then
        install_if_not python3
        python3 "${SCRIPTS}/${1}.py"
        rm -f "${SCRIPTS}/${1}.py"
    else
        print_text_in_color "$IRed" "Downloading ${1} failed"
        print_text_in_color "$ICyan" "Script failed to download. Please run: 'sudo curl -sLO ${STATIC}/${1}.sh|php|py' again."
        exit 1
    fi
}

# Run any script in ../apps
# call like: run_app_script collabora|nextant|passman|spreedme|contacts|calendar|webmin|previewgenerator
run_app_script() {
    rm -f "${SCRIPTS}/${1}.sh" "${SCRIPTS}/${1}.php" "${SCRIPTS}/${1}.py"
    if curl_to_dir "${APP}" "${1}.sh" "$SCRIPTS"
    then
        bash "${SCRIPTS}/${1}.sh"
        rm -f "${SCRIPTS}/${1}.sh"
    elif curl_to_dir "${APP}" "${1}.php" "$SCRIPTS"
    then
        php "${SCRIPTS}/${1}.php"
        rm -f "${SCRIPTS}/${1}.php"
    elif curl_to_dir "${APP}" "${1}.py" "$SCRIPTS"
    then
        install_if_not python3
        python3 "${SCRIPTS}/${1}.py"
        rm -f "${SCRIPTS}/${1}.py"
    else
        print_text_in_color "$IRed" "Downloading ${1} failed"
        print_text_in_color "$ICyan" "Script failed to download. Please run: 'sudo curl -sLO ${APP}/${1}.sh|php|py' again."
        exit
    fi
}

version(){
    local h t v

    [[ $2 = "$1" || $2 = "$3" ]] && return 0

    v=$(printf '%s\n' "$@" | sort -V)
    h=$(head -n1 <<<"$v")
    t=$(tail -n1 <<<"$v")

    [[ $2 != "$h" && $2 != "$t" ]]
}

version_gt() {
    local v1 v2 IFS=.
    read -ra v1 <<< "$1"
    read -ra v2 <<< "$2"
    printf -v v1 %03d "${v1[@]}"
    printf -v v2 %03d "${v2[@]}"
    [[ $v1 > $v2 ]]
}

spinner_loading() {
    pid=$!
    spin='-\|/'
    i=0
    while kill -0 $pid 2>/dev/null
    do
        i=$(( (i+1) %4 ))
        printf "\r[${spin:$i:1}] " # Add text here, something like "Please be paitent..." maybe?
        sleep .1
    done
}

any_key() {
    local PROMPT="$1"
    read -r -sn 1 -p "$(printf "%b" "${IGreen}${PROMPT}${Color_Off}")";echo
}

lowest_compatible_nc() {
if [ "${CURRENTVERSION%%.*}" -lt "$1" ]
then
msg_box "This script is developed to work with Nextcloud $1 and later.
This means we can't use our own script for now. But don't worry,
we automated the update process and we will now use Nextclouds updater instead.

Press [OK] to continue the update, or press [CTRL+C] to abort.

If you are using Nextcloud $1 and later and still see this message,
or experience other issues then please report this to $ISSUES"

    # Download the latest updater
#    cd $NCPATH
#    curl sLO https://github.com/nextcloud/updater/archive/master.zip
#    install_if_not unzip
#    unzip -q master.zip
#    rm master.zip*
#    rm updater/ -R
#    mv updater-master/ updater/
#    download_static_script setup_secure_permissions_nextcloud -P $SCRIPTS
#    bash $SECURE
#    cd

    # Do the upgrade
    chown -R www-data:www-data "$NCPATH"
    rm -rf "$NCPATH"/assets
    yes | sudo -u www-data php /var/www/nextcloud/updater/updater.phar
    download_static_script setup_secure_permissions_nextcloud -P $SCRIPTS
    bash $SECURE
    occ_command maintenance:mode --off
fi

# Check new version
# shellcheck source=lib.sh
NC_UPDATE=1 . <(curl -sL $GITHUB_REPO/lib.sh)
unset NC_UPDATE
if [ "${CURRENTVERSION%%.*}" -ge "$1" ]
then
    sleep 1
else
msg_box "It appears that something went wrong with the update. 
Please report this to $ISSUES"
occ_command -V
exit
fi
}

# Check universe reposiroty
check_universe() {
UNIV=$(apt-cache policy | grep http | awk '{print $3}' | grep universe | head -n 1 | cut -d "/" -f 2)
if [ "$UNIV" != "universe" ]
then
    print_text_in_color "$ICyan" "Adding required repo (universe)."
    add-apt-repository universe
fi
}

# Check universe reposiroty
check_multiverse() {
MULTIV=$(apt-cache policy | grep http | awk '{print $3}' | grep multiverse | head -n 1 | cut -d "/" -f 2)
if [ "$MULTIV" != "multiverse" ]
then
    print_text_in_color "$ICyan" "Adding required repo (multiverse)."
    add-apt-repository multiverse
fi
}

set_max_count() {
if grep -F 'vm.max_map_count=262144' /etc/sysctl.conf ; then
    print_text_in_color "$ICyan" "Max map count already set, skipping..."
else
    sysctl -w vm.max_map_count=262144
    {
        echo "###################################################################"
        echo "# Docker ES max virtual memory"
        echo "vm.max_map_count=262144"
    } >> /etc/sysctl.conf
fi
}

# Check if docker is installed
is_docker_running() {
    docker ps -a > /dev/null 2>&1
}

# Check if specific docker image is present
is_image_present() {
    [[ $(docker images -q "$1") ]]
}

# Check if old docker exists
# FULL NAME e.g. ark74/nc_fts or containrrr/watchtower or collabora/code
does_this_docker_exist() {
is_docker_running && is_image_present "$1";
}

install_docker() {
if ! is_docker_running
then
    print_text_in_color "$ICyan" "Installing Docker CE..."
    apt update -q4 & spinner_loading
    install_if_not curl
    curl -fsSL get.docker.com | sh
fi
# Set overlay2
cat << OVERLAY2 > /etc/docker/daemon.json
{
  "storage-driver": "overlay2"
}
OVERLAY2
systemctl daemon-reload
systemctl restart docker
}

# Remove all dockers excluding one
# docker_prune_except_this fts_esror 'Full Text Search'
docker_prune_except_this() {
print_text_in_color "$ICyan" "Checking if there are any old images and removing them..."
DOCKERPS=$(docker ps -a | grep -v "$1" | awk 'NR>1 {print $1}')
if [ "$DOCKERPS" != "" ]
then
msg_box "Removing old Docker instance(s)... ($DOCKERPS)

Please note that we will not remove $1 ($2).

You will be given the option to abort when you hit OK."
    any_key "Press any key to continue. Press CTRL+C to abort"
    docker stop "$(docker ps -a | grep -v "$1" | awk 'NR>1 {print $1}')"
    docker container prune -f
    docker image prune -a -f
    docker volume prune -f
fi
}

# Remove selected Docker image
# docker_prune_this 'collabora/code' 'onlyoffice/documentserver' 'ark74/nc_fts'
docker_prune_this() {
if does_this_docker_exist "$1"
then
msg_box "Removing old Docker image: $1
You will be given the option to abort when you hit OK."
    any_key "Press any key to continue. Press CTRL+C to abort"
    docker stop "$(docker container ls | grep "$1" | awk '{print $1}' | tail -1)"
    docker container prune -f
    docker image prune -a -f
    docker volume prune -f
fi
}

# countdown 'message looks like this' 10
countdown() {
print_text_in_color "$ICyan" "$1"
secs="$(($2))"
while [ $secs -gt 0 ]; do
   echo -ne "$secs\033[0K\r"
   sleep 1
   : $((secs--))
done
}

print_text_in_color() {
printf "%b%s%b\n" "$1" "$2" "$Color_Off"
}

# Apply patch
# git_apply_patch 15992 server 16.0.2
# 1 = pull
# 2 = repository
# Nextcloud version
git_apply_patch() {
if [[ "$CURRENTVERSION" = "$3" ]]
then
    curl_to_dir "https://patch-diff.githubusercontent.com/raw/nextcloud/${2}/pull" "${1}.patch" "/tmp"
    install_if_not git
    cd "$NCPATH"
    if git apply --check /tmp/"${1}".patch >/dev/null 2>&1
    then
        print_text_in_color "$IGreen" "Applying patch https://github.com/nextcloud/${2}/pull/${1} ..."
        git apply /tmp/"${1}".patch
    fi
fi
}

# Check if it's the Home/SME Server

#if home_sme_server
#then
#    do something
#fi

home_sme_server() {
if lshw -c system | grep -q NUC8i3BEH
then
    if lshw -c memory | grep -q BLS16G4
    then
        if lshw -c disk | grep -q ST2000LM015-2E81 || lshw -c disk | grep -q ST5000LM015-2E81
        then
            NEXTCLOUDHOMESME=yes-this-is-the-home-sme-server
        fi
    fi
fi

if [ -n "$NEXTCLOUDHOMESME" ]
then
    return 0
else
    return 1
fi
}

# Check if the value is a number
# EXAMPLE: https://github.com/nextcloud/vm/pull/1012
check_if_number() {
case "${1}" in
    ''|*[!0-9]*) return 1 ;;
    *) return 0 ;;
esac
}

## bash colors
# Reset
Color_Off='\e[0m'       # Text Reset

# Regular Colors
Black='\e[0;30m'        # Black
Red='\e[0;31m'          # Red
Green='\e[0;32m'        # Green
Yellow='\e[0;33m'       # Yellow
Blue='\e[0;34m'         # Blue
Purple='\e[0;35m'       # Purple
Cyan='\e[0;36m'         # Cyan
White='\e[0;37m'        # White

# Bold
BBlack='\e[1;30m'       # Black
BRed='\e[1;31m'         # Red
BGreen='\e[1;32m'       # Green
BYellow='\e[1;33m'      # Yellow
BBlue='\e[1;34m'        # Blue
BPurple='\e[1;35m'      # Purple
BCyan='\e[1;36m'        # Cyan
BWhite='\e[1;37m'       # White

# Underline
UBlack='\e[4;30m'       # Black
URed='\e[4;31m'         # Red
UGreen='\e[4;32m'       # Green
UYellow='\e[4;33m'      # Yellow
UBlue='\e[4;34m'        # Blue
UPurple='\e[4;35m'      # Purple
UCyan='\e[4;36m'        # Cyan
UWhite='\e[4;37m'       # White

# Background
On_Black='\e[40m'       # Black
On_Red='\e[41m'         # Red
On_Green='\e[42m'       # Green
On_Yellow='\e[43m'      # Yellow
On_Blue='\e[44m'        # Blue
On_Purple='\e[45m'      # Purple
On_Cyan='\e[46m'        # Cyan
On_White='\e[47m'       # White

# High Intensity
IBlack='\e[0;90m'       # Black
IRed='\e[0;91m'         # Red
IGreen='\e[0;92m'       # Green
IYellow='\e[0;93m'      # Yellow
IBlue='\e[0;94m'        # Blue
IPurple='\e[0;95m'      # Purple
ICyan='\e[0;96m'        # Cyan
IWhite='\e[0;97m'       # White

# Bold High Intensity
BIBlack='\e[1;90m'      # Black
BIRed='\e[1;91m'        # Red
BIGreen='\e[1;92m'      # Green
BIYellow='\e[1;93m'     # Yellow
BIBlue='\e[1;94m'       # Blue
BIPurple='\e[1;95m'     # Purple
BICyan='\e[1;96m'       # Cyan
BIWhite='\e[1;97m'      # White

# High Intensity backgrounds
On_IBlack='\e[0;100m'   # Black
On_IRed='\e[0;101m'     # Red
On_IGreen='\e[0;102m'   # Green
On_IYellow='\e[0;103m'  # Yellow
On_IBlue='\e[0;104m'    # Blue
On_IPurple='\e[0;105m'  # Purple
On_ICyan='\e[0;106m'    # Cyan
On_IWhite='\e[0;107m'   # White
