#!/bin/bash
# shellcheck disable=2034,2059
true
# see https://github.com/koalaman/shellcheck/wiki/Directive

## variables

# Dirs
SCRIPTS=/var/scripts
NCPATH=/var/www/nextcloud
HTML=/var/www
NCDATA=/mnt/ncdata
SNAPDIR=/var/snap/spreedme
GPGDIR=/tmp/gpg
BACKUP=/var/NCBACKUP
RORDIR=/opt/es/

# Ubuntu OS
DISTRO=$(lsb_release -sd | cut -d ' ' -f 2)
# Network
[ ! -z "$FIRST_IFACE" ] && IFACE=$(lshw -c network | grep "logical name" | awk '{print $3; exit}')
IFACE2=$(ip -o link show | awk '{print $2,$9}' | grep 'UP' | cut -d ':' -f 1)
[ ! -z "$CHECK_CURRENT_REPO" ] && REPO=$(apt-get update | grep -m 1 Hit | awk '{ print $2}')
ADDRESS=$(hostname -I | cut -d ' ' -f 1)
WGET="/usr/bin/wget"
# WANIP4=$(dig +short myip.opendns.com @resolver1.opendns.com) # as an alternative
WANIP4=$(curl -s -m 5 ipinfo.io/ip)
[ ! -z "$LOAD_IP6" ] && WANIP6=$(curl -s -k -m 7 https://6.ifcfg.me)
INTERFACES="/etc/netplan/01-netcfg.yaml"
GATEWAY=$(route -n|grep "UG"|grep -v "UGH"|cut -f 10 -d " ")
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
[ ! -z "$NCDB" ] && NCCONFIGDB=$(grep "dbname" $NCPATH/config/config.php | awk '{print $3}' | sed "s/[',]//g")
ETCMYCNF=/etc/mysql/my.cnf
MYCNF=/root/.my.cnf
[ ! -z "$MYCNFPW" ] && MARIADBMYCNFPASS=$(grep "password" $MYCNF | sed -n "/password/s/^password='\(.*\)'$/\1/p")
PGDB_PASS=$(tr -dc "a-zA-Z0-9@#*=" < /dev/urandom | fold -w "$SHUF" | head -n 1)
NEWPGPASS=$(tr -dc "a-zA-Z0-9@#*=" < /dev/urandom | fold -w "$SHUF" | head -n 1)
[ ! -z "$NCDB" ] && NCCONFIGDB=$(grep "dbname" $NCPATH/config/config.php | awk '{print $3}' | sed "s/[',]//g")
[ ! -z "$NCDBPASS" ] && NCCONFIGDBPASS=$(grep "dbpassword" $NCPATH/config/config.php | awk '{print $3}' | sed "s/[',]//g")
# Path to specific files
PHPMYADMIN_CONF="/etc/apache2/conf-available/phpmyadmin.conf"
PHPMPGDMIN_CONF="/etc/apache2/conf-available/phppgadmin.conf"
SECURE="$SCRIPTS/setup_secure_permissions_nextcloud.sh"
SSL_CONF="/etc/apache2/sites-available/nextcloud_ssl_domain_self_signed.conf"
HTTP_CONF="/etc/apache2/sites-available/nextcloud_http_domain_self_signed.conf"
# Nextcloud version
[ ! -z "$NC_UPDATE" ] && CURRENTVERSION=$(sudo -u www-data php $NCPATH/occ status | grep "versionstring" | awk '{print $3}')
NCVERSION=$(curl -s -m 900 $NCREPO/ | sed --silent 's/.*href="nextcloud-\([^"]\+\).zip.asc".*/\1/p' | sort --version-sort | tail -1)
STABLEVERSION="nextcloud-$NCVERSION"
NCMAJOR="${NCVERSION%%.*}"
NCBAD=$((NCMAJOR-2))
# Keys
OpenPGP_fingerprint='28806A878AE423A28372792ED75899B9A724937A'
# OnlyOffice URL
[ ! -z "$OO_INSTALL" ] && SUBDOMAIN=$(whiptail --title "Techandme.se OnlyOffice" --inputbox "OnlyOffice subdomain eg: office.yourdomain.com" "$WT_HEIGHT" "$WT_WIDTH" 3>&1 1>&2 2>&3)
# Nextcloud Main Domain
[ ! -z "$OO_INSTALL" ] && NCDOMAIN=$(whiptail --title "Techandme.se OnlyOffice" --inputbox "Nextcloud url, make sure it looks like this: cloud\\.yourdomain\\.com" "$WT_HEIGHT" "$WT_WIDTH" cloud\\.yourdomain\\.com 3>&1 1>&2 2>&3)
# Collabora Docker URL
[ ! -z "$COLLABORA_INSTALL" ] && SUBDOMAIN=$(whiptail --title "Techandme.se Collabora" --inputbox "Collabora subdomain eg: office.yourdomain.com" "$WT_HEIGHT" "$WT_WIDTH" 3>&1 1>&2 2>&3)
# Nextcloud Main Domain
[ ! -z "$COLLABORA_INSTALL" ] && NCDOMAIN=$(whiptail --title "Techandme.se Collabora" --inputbox "Nextcloud url, make sure it looks like this: cloud\\.yourdomain\\.com" "$WT_HEIGHT" "$WT_WIDTH" cloud\\.yourdomain\\.com 3>&1 1>&2 2>&3)
# Letsencrypt
LETSENCRYPTPATH="/etc/letsencrypt"
CERTFILES="$LETSENCRYPTPATH/live"
DHPARAMS="$CERTFILES/$SUBDOMAIN/dhparam.pem"
# Collabora App
HTTPS_CONF="/etc/apache2/sites-available/$SUBDOMAIN.conf"
HTTP2_CONF="/etc/apache2/mods-available/http2.conf"
# Nextant
# this var get's the latest automatically:
SOLR_VERSION=$(curl -s https://github.com/apache/lucene-solr/tags | grep -o "release.*</span>$" | grep -o '[0-6].[0-9].[0-9]' | sort -t. -k1,1n -k2,2n -k3,3n | tail -n1)
[ ! -z "$NEXTANT_INSTALL" ] && NEXTANT_VERSION=$(curl -s https://api.github.com/repos/nextcloud/fulltextsearch/releases/10134699 | grep 'tag_name' | cut -d\" -f4 | sed -e "s|v||g")
NT_RELEASE=nextant-$NEXTANT_VERSION.tar.gz
NT_DL=https://github.com/nextcloud/fulltextsearch/releases/download/v$NEXTANT_VERSION/$NT_RELEASE
SOLR_RELEASE=solr-$SOLR_VERSION.tgz
SOLR_DL=http://www-eu.apache.org/dist/lucene/solr/$SOLR_VERSION/$SOLR_RELEASE
NC_APPS_PATH=$NCPATH/apps
SOLR_HOME=/home/$SUDO_USER/solr_install/
SOLR_JETTY=/opt/solr/server/etc/jetty-http.xml
SOLR_DSCONF=/opt/solr-$SOLR_VERSION/server/solr/configsets/data_driven_schema_configs/conf/solrconfig.xml
# phpMyadmin
PHPMYADMINDIR=/usr/share/phpmyadmin
PHPMYADMIN_CONF="/etc/apache2/conf-available/phpmyadmin.conf"
UPLOADPATH=""
SAVEPATH=""
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
[ ! -z "$ES_INSTALL" ] && NCADMIN=$(sudo -u www-data php $NCPATH/occ user:list | awk '{print $3}')
[ ! -z "$ES_INSTALL" ] && ROREST=$(tr -dc "A-Za-z0-9" < /dev/urandom | fold -w "$SHUF" | head -n 1)
[ ! -z "$ES_INSTALL" ] && DOCKER_INS=$(dpkg -l | grep ^ii | awk '{print $2}' | grep docker)
[ ! -z "$ES_INSTALL" ] && nc_rores6x="ark74/nc_rores6.x:1.6.23_es6.3.2"
[ ! -z "$ES_INSTALL" ] && rores6x_name="es6.3.2-rores_1.6.23"
# Talk
[ ! -z "$TURN_INSTALL" ] && TURN_CONF="/etc/turnserver.conf"
[ ! -z "$TURN_INSTALL" ] && TURN_PORT=5349
[ ! -z "$TURN_INSTALL" ] && SHUF=$(shuf -i 25-29 -n 1)
[ ! -z "$TURN_INSTALL" ] && TURN_SECRET=$(tr -dc "a-zA-Z0-9@#*=" < /dev/urandom | fold -w "$SHUF" | head -n 1)
[ ! -z "$TURN_INSTALL" ] && TURN_DOMAIN=$(sudo -u www-data /var/www/nextcloud/occ config:system:get overwrite.cli.url | sed 's#https://##;s#/##')

## functions

# If script is running as root?
#
# Example:
# if is_root
# then
#     # do stuff
# else
#     echo "You are not root..."
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
   b) :~# $SCRIPTS/name-of-script.sh

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
    whiptail --msgbox "${PROMPT}" "$WT_HEIGHT" "$WT_WIDTH"
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
            echo "${PROCESS} is running. Waiting for it to stop..."
            sleep 10
    fi
done
}

test_connection() {
# Install dnsutils if not existing
if [ "$(dpkg-query -W -f='${Status}' "dnsutils" 2>/dev/null | grep -c "ok installed")" == "1" ]
then
    sleep 0.1
else
    apt update -q4 & spinner_loading
    apt install dnsutils -y
fi
# Install network-manager if not existing
if [ "$(dpkg-query -W -f='${Status}' "network-manager" 2>/dev/null | grep -c "ok installed")" == "1" ]
then
    sleep 0.1
else
    apt update -q4 & spinner_loading
    apt install network-manager -y
fi
check_command service network-manager restart
ip link set "$IFACE" down
sleep 2
ip link set "$IFACE" up
sleep 2
echo "Checking connection..."
check_command service network-manager restart
sleep 2
if nslookup github.com
then
    echo "Online!"
elif ! nslookup github.com
then
    echo "Trying to restart networking service..."
    check_command service networking restart && sleep 2
    if nslookup github.com
    then
        echo "Online!"
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

# Install certbot (Let's Encrypt)
install_certbot() {
certbot --version 2> /dev/null
LE_IS_AVAILABLE=$?
if [ $LE_IS_AVAILABLE -eq 0 ]
then
    certbot --version
else
    echo "Installing certbot (Let's Encrypt)..."
    apt update -q4 & spinner_loading
    apt install software-properties-common
    add-apt-repository ppa:certbot/certbot -y
    apt update -q4 & spinner_loading
    apt install certbot -y -q
    apt update -q4 & spinner_loading
    apt dist-upgrade -y
fi
}

# Let's Encrypt for subdomains
le_subdomain() {
a2dissite 000-default.conf
service apache2 reload
certbot certonly --standalone --pre-hook "service apache2 stop" --post-hook "service apache2 start" --agree-tos --rsa-key-size 4096 -d "$SUBDOMAIN"
}

# Check if port is open # check_open_port 443 domain.example.com
check_open_port() {
# Check to see if user already has nmap installed on their system
if [ "$(dpkg-query -s nmap 2> /dev/null | grep -c "ok installed")" == "1" ]
then
    NMAPSTATUS=preinstalled
fi

apt update -q4 & spinner_loading
if [ "$NMAPSTATUS" = "preinstalled" ]
then
      echo "nmap is already installed..."
else
    apt install nmap -y
fi

# Check if $1 is open using nmap, if not notify the user
if [ "$(nmap -sS -p "$1" "$WANIP4" | grep -c "open")" == "1" ]
then
  printf "${Green}Port $1 is open on $WANIP4!${Color_Off}\n"
  if [ "$NMAPSTATUS" = "preinstalled" ]
  then
    echo "nmap was previously installed, not removing."
  else
    apt remove --purge nmap -y
  fi
else
  whiptail --msgbox "Port $1 is not open on $WANIP4. We will do a second try on $2 instead." "$WT_HEIGHT" "$WT_WIDTH"
  if [[ "$(nmap -sS -PN -p "$1" "$2" | grep -m 1 "open" | awk '{print $2}')" = "open" ]]
  then
      printf "${Green}Port $1 is open on $2!${Color_Off}\n"
      if [ "$NMAPSTATUS" = "preinstalled" ]
      then
        echo "nmap was previously installed, not removing."
      else
        apt remove --purge nmap -y
      fi
  else
      whiptail --msgbox "Port $1 is not open on $2. Please follow this guide to open ports in your router: https://www.techandme.se/open-port-80-443/" "$WT_HEIGHT" "$WT_WIDTH"
      any_key "Press any key to exit... "
      if [ "$NMAPSTATUS" = "preinstalled" ]
      then
        echo "nmap was previously installed, not removing."
      else
        apt remove --purge nmap -y
      fi
      exit 1
  fi
fi
}

check_distro_version() {
# Check Ubuntu version
echo "Checking server OS and version..."
if uname -a | grep -ic "bionic"
then
    OS=1
elif uname -v | grep -ic "Ubuntu"  
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

configure_max_upload() {
# Increase max filesize (expects that changes are made in /etc/php/7.2/apache2/php.ini)
# Here is a guide: https://www.techandme.se/increase-max-file-size/
sed -i 's/  php_value upload_max_filesize.*/# php_value upload_max_filesize 511M/g' "$NCPATH"/.htaccess
sed -i 's/  php_value post_max_size.*/# php_value post_max_size 511M/g' "$NCPATH"/.htaccess
sed -i 's/  php_value memory_limit.*/# php_value memory_limit 512M/g' "$NCPATH"/.htaccess
}

# Check if program is installed (is_this_installed apache2)
is_this_installed() {
if [ "$(dpkg-query -W -f='${Status}' "${1}" 2>/dev/null | grep -c "ok installed")" == "1" ]
then
    echo "${1} is installed, it must be a clean server."
    exit 1
fi
}

# Install_if_not program
install_if_not () {
if [[ "$(is_this_installed "${1}")" != "${1} is installed, it must be a clean server." ]]
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
    printf "${Red}Error: ${1} GB RAM required to install ${2}!${Color_Off}\n" >&2
    printf "${Red}Current RAM is: ("$((mem_available/1002400))" GB)${Color_Off}\n" >&2
    sleep 3
    msg_box "If you want to bypass this check you could do so by commenting out (# before the line) 'ram_check X' in the script that you are trying to run.
    
    In nextcloud_install_production.sh you can find the check somewhere around line #34. 
    
    Please notice that things may be veery slow and not work as expeced. YOU HAVE BEEN WARNED!"
    exit 1
else
    printf "${Green}RAM for ${2} OK! ("$((mem_available/1002400))" GB)${Color_Off}\n"
fi
}

# Test number of CPU
# Call it like this: cpu_check [amount of min CPU] [for which program]
# Example: cpu_check 2 Nextcloud
cpu_check() {
nr_cpu="$(nproc)"
if [ "${nr_cpu}" -lt "${1}" ]
then
    printf "${Red}Error: ${1} CPU required to install ${2}!${Color_Off}\n" >&2
    printf "${Red}Current CPU: ("$((nr_cpu))")${Color_Off}\n" >&2
    sleep 3
    exit 1
else
    printf "${Green}CPU for ${2} OK! ("$((nr_cpu))")${Color_Off}\n"
fi
}

check_command() {
  if ! "$@";
  then
     printf "${IRed}Sorry but something went wrong. Please report this issue to $ISSUES and include the output of the error message. Thank you!${Color_Off}\n"
     echo "$* failed"
    exit 1
  fi
}

# Example: occ_command 'maintenance:mode --on'
occ_command() {
check_command sudo -u www-data php "$NCPATH"/occ "$@";
}

network_ok() {
    echo "Testing if network is OK..."
    if ! service network-manager restart > /dev/null
    then
        service networking restart > /dev/null
    fi
    sleep 2
    if wget -q -T 20 -t 2 http://github.com -O /dev/null & spinner_loading
    then
        return 0
    else
        return 1
    fi
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
    echo "Installing $1..."
    occ_command app:install "$1"
fi

# Enable $1
if [ -d "$NC_APPS_PATH/$1" ]
then
    occ_command app:enable "$1"
    chown -R www-data:www-data "$NC_APPS_PATH"
fi
}

download_verify_nextcloud_stable() {
rm -f "$HTML/$STABLEVERSION.tar.bz2"
wget -q -T 10 -t 2 "$NCREPO/$STABLEVERSION.tar.bz2" -P "$HTML"
mkdir -p "$GPGDIR"
wget -q "$NCREPO/$STABLEVERSION.tar.bz2.asc" -P "$GPGDIR"
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
    if ! { wget -q "${STATIC}/${1}.sh" -P "$SCRIPTS" || wget -q "${STATIC}/${1}.php" -P "$SCRIPTS" || wget -q "${STATIC}/${1}.py" -P "$SCRIPTS"; }
    then
        echo "{$1} failed to download. Please run: 'sudo wget ${STATIC}/${1}.sh|.php|.py' again."
        echo "If you get this error when running the nextcloud-startup-script then just re-run it with:"
        echo "'sudo bash $SCRIPTS/nextcloud-startup-script.sh' and all the scripts will be downloaded again"
        exit 1
    fi
}

# Initial download of script in ../lets-encrypt
# call like: download_le_script name_of_script
download_le_script() {
    # Get ${1} script
    rm -f "${SCRIPTS}/${1}.sh" "${SCRIPTS}/${1}.php" "${SCRIPTS}/${1}.py"
    if ! { wget -q "${LETS_ENC}/${1}.sh" -P "$SCRIPTS" || wget -q "${LETS_ENC}/${1}.php" -P "$SCRIPTS" || wget -q "${LETS_ENC}/${1}.py" -P "$SCRIPTS"; }
    then
        echo "{$1} failed to download. Please run: 'sudo wget ${STATIC}/${1}.sh|.php|.py' again."
        echo "If you get this error when running the nextcloud-startup-script then just re-run it with:"
        echo "'sudo bash $SCRIPTS/nextcloud-startup-script.sh' and all the scripts will be downloaded again"
        exit 1
    fi
}

# Run any script in ../master
# call like: run_main_script name_of_script
run_main_script() {
    rm -f "${SCRIPTS}/${1}.sh" "${SCRIPTS}/${1}.php" "${SCRIPTS}/${1}.py"
    if wget -q "${GITHUB_REPO}/${1}.sh" -P "$SCRIPTS"
    then
        bash "${SCRIPTS}/${1}.sh"
        rm -f "${SCRIPTS}/${1}.sh"
    elif wget -q "${GITHUB_REPO}/${1}.php" -P "$SCRIPTS"
    then
        php "${SCRIPTS}/${1}.php"
        rm -f "${SCRIPTS}/${1}.php"
    elif wget -q "${GITHUB_REPO}/${1}.py" -P "$SCRIPTS"
    then
        python "${SCRIPTS}/${1}.py"
        rm -f "${SCRIPTS}/${1}.py"
    else
        echo "Downloading ${1} failed"
        echo "Script failed to download. Please run: 'sudo wget ${GITHUB_REPO}/${1}.sh|php|py' again."
        sleep 3
    fi
}

# Run any script in ../static
# call like: run_static_script name_of_script
run_static_script() {
    # Get ${1} script
    rm -f "${SCRIPTS}/${1}.sh" "${SCRIPTS}/${1}.php" "${SCRIPTS}/${1}.py"
    if wget -q "${STATIC}/${1}.sh" -P "$SCRIPTS"
    then
        bash "${SCRIPTS}/${1}.sh"
        rm -f "${SCRIPTS}/${1}.sh"
    elif wget -q "${STATIC}/${1}.php" -P "$SCRIPTS"
    then
        php "${SCRIPTS}/${1}.php"
        rm -f "${SCRIPTS}/${1}.php"
    elif wget -q "${STATIC}/${1}.py" -P "$SCRIPTS"
    then
        python "${SCRIPTS}/${1}.py"
        rm -f "${SCRIPTS}/${1}.py"
    else
        echo "Downloading ${1} failed"
        echo "Script failed to download. Please run: 'sudo wget ${STATIC}/${1}.sh|php|py' again."
        sleep 3
    fi
}

# Run any script in ../apps
# call like: run_app_script collabora|nextant|passman|spreedme|contacts|calendar|webmin|previewgenerator
run_app_script() {
    rm -f "${SCRIPTS}/${1}.sh" "${SCRIPTS}/${1}.php" "${SCRIPTS}/${1}.py"
    if wget -q "${APP}/${1}.sh" -P "$SCRIPTS"
    then
        bash "${SCRIPTS}/${1}.sh"
        rm -f "${SCRIPTS}/${1}.sh"
    elif wget -q "${APP}/${1}.php" -P "$SCRIPTS"
    then
        php "${SCRIPTS}/${1}.php"
        rm -f "${SCRIPTS}/${1}.php"
    elif wget -q "${APP}/${1}.py" -P "$SCRIPTS"
    then
        python "${SCRIPTS}/${1}.py"
        rm -f "${SCRIPTS}/${1}.py"
    else
        echo "Downloading ${1} failed"
        echo "Script failed to download. Please run: 'sudo wget ${APP}/${1}.sh|php|py' again."
        sleep 3
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
    read -r -p "$(printf "${Green}${PROMPT}${Color_Off}")" -n1 -s
    echo
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
#    wget -q https://github.com/nextcloud/updater/archive/master.zip
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

set_max_count() {
if grep -F 'vm.max_map_count=262144' /etc/sysctl.conf ; then
	echo "Max map count already set, skipping..."
else
	sysctl -w vm.max_map_count=262144
	{
  	echo "###################################################################"
  	echo "# Docker ES max virtual memory"
  	echo "vm.max_map_count=262144"
	} >> /etc/sysctl.conf
fi
}

install_docker() {
if [ "$DOCKER_INS" = "docker-ce" ] || \
[ "$DOCKER_INS" = "docker-ee" ] || \
[ "$DOCKER_INS" = "docker.io" ] ; then
	echo "Docker seems to be installed, skipping..."
else
	echo "Installing Docker CE..."
	curl -fsSL get.docker.com -o get-docker.sh
	bash get-docker.sh
	rm -rf get-docker.sh
fi
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
