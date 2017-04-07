#!/bin/bash
# shellcheck disable=2034,2059
true
# see https://github.com/koalaman/shellcheck/wiki/Directive

## variables

# Dirs
SCRIPTS=/var/scripts
NCPATH=/var/www/nextcloud
HTML=/var/www
NCDATA=/var/ncdata
SNAPDIR=/var/snap/spreedme
GPGDIR=/tmp/gpg
BACKUP=/var/NCBACKUP
# Ubuntu OS
DISTRO=$(lsb_release -sd | cut -d ' ' -f 2)
OS=$(grep -ic "Ubuntu" /etc/issue.net)
# Network
[ ! -z "$FIRST_IFACE" ] && IFACE=$(lshw -c network | grep "logical name" | awk '{print $3; exit}')
IFACE2=$(ip -o link show | awk '{print $2,$9}' | grep 'UP' | cut -d ':' -f 1)
[ ! -z "$CHECK_CURRENT_REPO" ] && REPO=$(apt-get update | grep -m 1 Hit | awk '{ print $2}')
ADDRESS=$(hostname -I | cut -d ' ' -f 1)
WGET="/usr/bin/wget"
# WANIP4=$(dig +short myip.opendns.com @resolver1.opendns.com) # as an alternative
WANIP4=$(curl -s -m 5 ipinfo.io/ip)
WANIP6=$(curl -s -m 5 6.ifcfg.me)
IFCONFIG="/sbin/ifconfig"
INTERFACES="/etc/network/interfaces"
NETMASK=$($IFCONFIG | grep -w inet |grep -v 127.0.0.1| awk '{print $4}' | cut -d ":" -f 2)
GATEWAY=$(route -n|grep "UG"|grep -v "UGH"|cut -f 10 -d " ")
# Repo
GITHUB_REPO="https://raw.githubusercontent.com/morph027/vm/master"
NCREPO="https://download.nextcloud.com/server/releases"
STATIC="https://raw.githubusercontent.com/morph027/vm/master/static"
LETS_ENC="https://raw.githubusercontent.com/morph027/vm/master/lets-encrypt"
ISSUES="https://github.com/nextcloud/vm/issues"
# User information
NCPASS=nextcloud
NCUSER=ncadmin
UNIXUSER=$SUDO_USER
UNIXUSER_PROFILE="/home/$UNIXUSER/.bash_profile"
ROOT_PROFILE="/root/.bash_profile"
# Passwords
SHUF=$(shuf -i 19-21 -n 1)
MYSQL_PASS=$(tr -dc "a-zA-Z0-9@#*=" < /dev/urandom | fold -w "$SHUF" | head -n 1)
NEWMYSQLPASS=$(tr -dc "a-zA-Z0-9@#*=" < /dev/urandom | fold -w "$SHUF" | head -n 1)
# Path to specific files
PHPMYADMIN_CONF="/etc/apache2/conf-available/phpmyadmin.conf"
SECURE="$SCRIPTS/setup_secure_permissions_nextcloud.sh"
SSL_CONF="/etc/apache2/sites-available/nextcloud_ssl_domain_self_signed.conf"
HTTP_CONF="/etc/apache2/sites-available/nextcloud_http_domain_self_signed.conf"
PW_FILE=/var/mysql_password.txt
MYCNF=/root/.my.cnf
[ ! -z "$CHANGE_MYSQL" ] && OLDMYSQL=$(cat $PW_FILE)
# Nextcloud version
[ ! -z "$NC_UPDATE" ] && CURRENTVERSION=$(sudo -u www-data php $NCPATH/occ status | grep "versionstring" | awk '{print $3}')
NCVERSION=$(curl -s -m 900 $NCREPO/ | tac | grep unknown.gif | sed 's/.*"nextcloud-\([^"]*\).zip.sha512".*/\1/;q')
STABLEVERSION="nextcloud-$NCVERSION"
NCMAJOR="${NCVERSION%%.*}"
NCBAD=$((NCMAJOR-2))
# Keys
OpenPGP_fingerprint='28806A878AE423A28372792ED75899B9A724937A'
# Collabora Docker URL
[ ! -z "$COLLABORA_INSTALL" ] && SUBDOMAIN=$(whiptail --title "Techandme.se Collabora" --inputbox "Collabora subdomain eg: office.yourdomain.com" "$WT_HEIGHT" "$WT_WIDTH" 3>&1 1>&2 2>&3)
# Nextcloud Main Domain
[ ! -z "$COLLABORA_INSTALL" ] && NCDOMAIN=$(whiptail --title "Techandme.se Collabora" --inputbox "Nextcloud url, make sure it looks like this: cloud\\.yourdomain\\.com" "$WT_HEIGHT" "$WT_WIDTH" cloud\\.yourdomain\\.com 3>&1 1>&2 2>&3)
# Letsencrypt
LETSENCRYPTPATH="/etc/letsencrypt"
CERTFILES="$LETSENCRYPTPATH/live"
DHPARAMS="$CERTFILES/$SUBDOMAIN/dhparam.pem"
# Collabora App
COLLVER=$(curl -s https://api.github.com/repos/nextcloud/richdocuments/releases/latest | grep "tag_name" | cut -d\" -f4)
COLLVER_FILE=richdocuments.tar.gz
COLLVER_REPO=https://github.com/nextcloud/richdocuments/releases/download
HTTPS_CONF="/etc/apache2/sites-available/$SUBDOMAIN.conf"
# Nextant
SOLR_VERSION=$(curl -s https://github.com/apache/lucene-solr/tags | grep -o "release.*</span>$" | grep -o '[0-9].[0-9].[0-9]' | sort -t. -k1,1n -k2,2n -k3,3n | tail -n1)
NEXTANT_VERSION=$(curl -s https://api.github.com/repos/nextcloud/nextant/releases/latest | grep 'tag_name' | cut -d\" -f4 | sed -e "s|v||g")
NT_RELEASE=nextant-master-$NEXTANT_VERSION.tar.gz
NT_DL=https://github.com/nextcloud/nextant/releases/download/v$NEXTANT_VERSION/$NT_RELEASE
SOLR_RELEASE=solr-$SOLR_VERSION.tgz
SOLR_DL=http://www-eu.apache.org/dist/lucene/solr/$SOLR_VERSION/$SOLR_RELEASE
NC_APPS_PATH=$NCPATH/apps/
SOLR_HOME=/home/$SUDO_USER/solr_install/
SOLR_JETTY=/opt/solr/server/etc/jetty-http.xml
SOLR_DSCONF=/opt/solr-$SOLR_VERSION/server/solr/configsets/data_driven_schema_configs/conf/solrconfig.xml
# Passman
PASSVER=$(curl -s https://api.github.com/repos/nextcloud/passman/releases/latest | grep "tag_name" | cut -d\" -f4)
PASSVER_FILE=passman_$PASSVER.tar.gz
PASSVER_REPO=https://releases.passman.cc
SHA256=/tmp/sha256
# Calendar
CALVER=$(curl -s https://api.github.com/repos/nextcloud/calendar/releases/latest | grep "tag_name" | cut -d\" -f4 | sed -e "s|v||g")
CALVER_FILE=calendar.tar.gz
CALVER_REPO=https://github.com/nextcloud/calendar/releases/download
# Contacts
CONVER=$(curl -s https://api.github.com/repos/nextcloud/contacts/releases/latest | grep "tag_name" | cut -d\" -f4 | sed -e "s|v||g")
CONVER_FILE=contacts.tar.gz
CONVER_REPO=https://github.com/nextcloud/contacts/releases/download
# phpMyadmin
PHPMYADMINDIR=/usr/share/phpmyadmin
PHPMYADMIN_CONF="/etc/apache2/conf-available/phpmyadmin.conf"
UPLOADPATH=""
SAVEPATH=""
# Redis
REDIS_CONF=/etc/redis/redis.conf
REDIS_SOCK=/var/run/redis/redis.sock
RSHUF=$(shuf -i 30-35 -n 1)
REDIS_PASS=$(tr -dc "a-zA-Z0-9@#*=" < /dev/urandom | fold -w "$RSHUF" | head -n 1)
# Extra security
SPAMHAUS=/etc/spamhaus.wl
ENVASIVE=/etc/apache2/mods-available/mod-evasive.load
APACHE2=/etc/apache2/apache2.conf

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

check_command() {
  eval "$*"
  if [ ! $? -eq 0 ]; then
     printf "${IRed}Sorry but something went wrong. Please report this issue to $ISSUES and include the output of the error message. Thank you!${Color_Off}\n"
     echo "$* failed"
    exit 1
  fi
}

network_ok() {
    echo "Testing if network is OK..."
    service networking restart
    if wget -q -T 10 -t 2 http://github.com -O /dev/null
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

# Initial download of script
# call like: download_static_script name_of_script(.sh)
download_static_script() {
    # Get ${1} script
    if [ -f "${SCRIPTS}/${1}.sh" ]
    then
        rm -f "${SCRIPTS}/${1}.sh"
        wget -q "${STATIC}/${1}.sh" -P "$SCRIPTS"
    elif [ ! -f "${SCRIPTS}/${1}.sh" ]
    then
        wget -q "${STATIC}/${1}.sh" -P "$SCRIPTS"
    fi
    # Check ${1} script is downloaded
    if [ -f "${SCRIPTS}/${1}.sh" ]
    then
    sleep 0.1
    else
        echo "{$1} failed to download. Please run: 'sudo wget ${STATIC}/${1}.sh' again."
        echo "If you get this error when running the nextcloud-startup-script then just re-run it with:"
        echo "'sudo bash $SCRIPTS/nextcloud-startup-script.sh' and all the scripts will be downloaded again"
        exit 1
    fi
}

# Install Apps
# call like: run_static_script collabora|nextant|passman|spreedme|contacts|calendar|webmin
run_static_script() {
    # Get ${1} script
    if [ -f "${SCRIPTS}/${1}.sh" ]
    then
        rm -f "${SCRIPTS}/${1}.sh"
        wget -q "${STATIC}/${1}.sh" -P "$SCRIPTS"
    elif [ ! -f "${SCRIPTS}/${1}.sh" ]
    then
        wget -q "${STATIC}/${1}.sh" -P "$SCRIPTS"
    fi
    # Check ${1} script is downloaded
    if [ -f "${SCRIPTS}/${1}.sh" ]
    then
        # Run ${1} script
        bash "${SCRIPTS}/${1}.sh"
        rm -f "$SCRIPTS/${1}.sh"
    else
        echo "Downloading ${1} failed"
        echo "Script failed to download. Please run: 'sudo wget ${STATIC}/${1}.sh' again."
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
        sleep .15
    done
}

any_key() {
    local PROMPT="$1"
    read -r -p "$(printf "${Green}${PROMPT}${Color_Off}")" -n1 -s
    echo
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
