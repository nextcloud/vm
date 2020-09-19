#!/bin/bash

# T&M Hansson IT AB © - 2020, https://www.hanssonit.se/

# shellcheck disable=2034,2059
true
SCRIPT_NAME="Talk Menu"
# shellcheck source=lib.sh
. <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Must be root
root_check

# Set the startup switch
if [ -f "$SCRIPTS/nextcloud-startup-script.sh" ]
then
    STARTUP_SWITCH="ON"
else
    STARTUP_SWITCH="OFF"
fi

choice=$(whiptail --title "$TITLE" --checklist "Automatically install and configure Talk.\n$CHECKLIST_GUIDE\n$RUN_LATER_GUIDE" "$WT_HEIGHT" "$WT_WIDTH" 4 \
"Talk " "(Install Talk standalone - no subdomain required)" OFF \
"Talk-Signaling" "(Install Talk + Signaling Server - subdomain required)" OFF 3>&1 1>&2 2>&3)

case "$choice" in
    *"Talk "*)
        clear
        print_text_in_color "$ICyan" "Downloading the Talk script..."
        run_script APP talk
    ;;&
    *"Talk-Signaling"*)
        clear
        print_text_in_color "$ICyan" "Downloading the Talk Signaling script..."
        run_script APP talk_signaling
    ;;&
    *)
    ;;
esac
exit

