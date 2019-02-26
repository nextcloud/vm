#!/bin/bash

# T&M Hansson IT AB © - 2019, https://www.hanssonit.se/

# shellcheck disable=2034,2059
true
# shellcheck source=lib.sh
. <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

clear
cat << INST1
+-----------------------------------------------------------------------+
| Thanks for downloading this Nextcloud VM by the Nextcloud Community!  |
|                                                                       |
INST1
echo -e "|"  "${IGreen}To run the startup script type the sudoer password. This will either${Color_Off}  |"
echo -e "|"  "${IGreen}be the default ('nextcloud') or the one chosen during installation.${Color_Off}   |"
cat << INST2
|                                                                       |
| If you have never done this before you can follow the complete        |
| installation instructions here: https://bit.ly/2S8eGfS                |
|                                                                       |
| You can schedule the Nextcloud update process using a cron job.       |
| This is done using a script built into this VM that automatically     |
| updates Nextcloud, sets secure permissions, and logs the successful   |
| update to /var/log/cronjobs_success.log                               |
| Detailed instructions for setting this up can be found here:          |
| https://www.techandme.se/nextcloud-update-is-now-fully-automated/     |
|                                                                       |
|  ##################### T&M Hansson IT - $(date +"%Y") #######################  |
+-----------------------------------------------------------------------+
INST2

exit 0
