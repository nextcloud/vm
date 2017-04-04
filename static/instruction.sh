#!/bin/bash
#
clear
cat << INST1
+-----------------------------------------------------------------------+
| Thanks for downloading this Nextcloud VM by the Nextcloud Community!  |
|                                                                       |
INST1
echo -e "|"  "${Green}To run the startup script type the sudoer password. This will either${Color_Off}  |"
echo -e "|"  "${Green}be the default ('nextcloud') or the one chosen during installation.${Color_Off}   |"
cat << INST2
|                                                                       |
| If you have never done this before you can follow the complete        |
| installation instructions here: https://goo.gl/JVxuPh                 |
|                                                                       |
| You can schedule the Nextcloud update process using a cron job.       |
| This is done using a script built into this VM that automatically     |
| updates Nextcloud, sets secure permissions, and logs the successful   |
| update to /var/log/cronjobs_success.log                               |
| Detailed instructions for setting this up can be found here:          |
| https://www.techandme.se/nextcloud-update-is-now-fully-automated/     |
|                                                                       |
|  ####################### Tech and Me - 2017 ########################  |
+-----------------------------------------------------------------------+
INST2

exit 0
