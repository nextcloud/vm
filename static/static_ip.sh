#!/bin/bash

# T&M Hansson IT AB © - 2019, https://www.hanssonit.se/

# shellcheck disable=2034,2059
true
# shellcheck source=lib.sh

###### Add all the functions and variables here so that it works even without internet ######
# Variables
IFACE=$(lshw -c network | grep "logical name" | awk '{print $3; exit}')
IFACE2=$(ip -o link show | awk '{print $2,$9}' | grep 'UP' | cut -d ':' -f 1)
ADDRESS=$(hostname -I | cut -d ' ' -f 1)
INTERFACES="/etc/netplan/01-netcfg.yaml"
GATEWAY=$(ip route | grep default | awk '{print $3}')
DNS1="9.9.9.9"
DNS2="149.112.112.112"
Color_Off='\e[0m'       # Text Reset
IRed='\e[0;91m'         # Red
IGreen='\e[0;92m'       # Green
ICyan='\e[0;96m'        # Cyan
print_text_in_color() {
	printf "%b%s%b\n" "$1" "$2" "$Color_Off"
}

msg_box() {
local PROMPT="$1"
    whiptail --title "Nextcloud VM - T&M Hansson IT - $(date +"%Y")" --msgbox "${PROMPT}" "$WT_HEIGHT" "$WT_WIDTH"
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

check_command() {
  if ! "$@";
  then
     print_text_in_color "$ICyan" "Sorry but something went wrong. Please report this issue to $ISSUES and include the output of the error message. Thank you!"
	 print_text_in_color "$IRed" "$* failed"
    exit 1
  fi
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

# If we have internet, then use the latest variables from the lib file
if test_connection
then
FIRST_IFACE=1 . <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)
unset FIRST_IFACE
fi


################################################################################

# Must be root
root_check

# Check Ubuntu version
check_distro_version

# Copy old interfaces files
msg_box "Copying old netplan.io config files file to:

/tmp/netplan_io_backup/"
if [ -d /etc/netplan/ ]
then
    mkdir -p /tmp/netplan_io_backup
    check_command cp -vR /etc/netplan/* /tmp/netplan_io_backup/
fi

msg_box "Please note that if the IP address changes during an (remote) SSH connection (via Putty, or terminal for example), the connection will break and the IP will reset to DHCP or the IP you had before you started this script.

To avoid issues with lost connectivity, please use the VM Console directly, and not SSH."
if [[ "yes" == $(ask_yes_or_no "Are you connected via SSH?") ]]
then
    print_text_in_color "$IRed" "Please use the VM Console instead."
    sleep 1
    exit
fi

echo
while true
do
    # Ask for IP address
    cat << ENTERIP
+----------------------------------------------------------+
|    Please enter the static IP address you want to set,   |
|    including the subnet. Example: 192.168.1.100/24       |
+----------------------------------------------------------+
ENTERIP
    echo
    read -r LANIP
    echo

    if [[ $LANIP == *"/"* ]]
    then
        break
    else
        print_text_in_color "$IRed" "Did you forget the /subnet?"
    fi
done

echo
while true
do
    # Ask for domain name
    cat << ENTERGATEWAY
+-------------------------------------------------------+
|    Please enter the gateway address you want to set,  |
|    Your current gateway is: $GATEWAY               |
+-------------------------------------------------------+
ENTERGATEWAY
    echo
    read -r GATEWAYIP
    echo
    if [[ "yes" == $(ask_yes_or_no "Is this correct? $GATEWAYIP") ]]
    then
        break
    fi
done

# Check if IFACE is empty, if yes, try another method:
if [ -n "$IFACE" ]
then
    cat <<-IPCONFIG > "$INTERFACES"
network:
   version: 2
   renderer: networkd
   ethernets:
       $IFACE: #object name
         dhcp4: no # dhcp v4 disable
         dhcp6: no # dhcp v6 disable
         addresses: [$LANIP] # client IP address
         gateway4: $GATEWAYIP # gateway address
         nameservers:
           addresses: [$DNS1,$DNS2] #name servers
IPCONFIG

msg_box "These are your settings, please make sure they are correct:

$(cat /etc/netplan/01-netcfg.yaml)"
    netplan try
else
    cat <<-IPCONFIGnonvmware > "$INTERFACES"
network:
   version: 2
   renderer: networkd
   ethernets:
       $IFACE2: #object name
         dhcp4: no # dhcp v4 disable
         dhcp6: no # dhcp v6 disable
         addresses: [$ADDRESS/24] # client IP address
         gateway4: $GATEWAY # gateway address
         nameservers:
           addresses: [$DNS1,$DNS2] #name servers
IPCONFIGnonvmware
msg_box "These are your settings, please make sure they are correct:

$(cat /etc/netplan/01-netcfg.yaml)"
    netplan try
fi

if test_connection
then
    sleep 1
    msg_box "Static IP sucessfully set!"
fi
