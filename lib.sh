#!/bin/bash

ask_yes_or_no() {
    read -p "$1 ([y]es or [N]o): "
    case ${REPLY,,} in
    y|yes) echo "yes" ;;
    *)     echo "no" ;;
esac
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

