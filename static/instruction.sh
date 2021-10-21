#!/bin/bash

# T&M Hansson IT AB © - 2020, https://www.hanssonit.se/

BIGreen='\e[1;92m'      # Green
IGreen='\e[0;92m'       # Green
Color_Off='\e[0m'       # Text Reset

clear
cat << INST1
+-----------------------------------------------------------------------+
|      Welcome to the first setup of your own Nextcloud Server! :)      |
|                                                                       |
INST1
echo -e "|"  "${IGreen}To run the startup script type the sudoer password, then hit [ENTER].${Color_Off} |"
echo -e "|"  "${IGreen}The default sudoer password is: ${BIGreen}nextcloud${IGreen}${Color_Off}                             |"
cat << INST2
|                                                                       |
| You will now setup the basics of the server.                          |
| A working internet connection if recomended, but not needed for the   |
| setup to finish properly.                                             |
|                                                                       |
| To choose the defaults during installation, just hit [ENTER].         |
|                                                                       |
|     ###################### Nextcloud - $(date +"%Y") #####################     |
+-----------------------------------------------------------------------+
INST2

exit 0
