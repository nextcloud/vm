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
| You can find the complete install instructions here:                  |
| Nextcloud VM              = https://bit.ly/2S8eGfS                    |
| Nextcloud Home/SME Server = https://bit.ly/2k2TNaM                    |
|                                                                       |
| To be 100% sure that all the keystrokes work correctly (like @),      |
| please use an SSH terminal like Putty. You can download it here:      |
| https://www.chiark.greenend.org.uk/~sgtatham/putty/latest.html        |
| If you are running Windows 10 1809 or later, you can simply use SSH   |
| from the command prompt. Connect like this:                           |
| ssh ncadmin@local.IP.of.this.server                                   |
|                                                                       |
| This server could be made maintenace free by using automatic updates  |
| with the built in update script. If you want automatic updates on     |
| a weekly schelude, choose to configure it later during this setup.    |
|                                                                       |
|  ###################### T&M Hansson IT - $(date +"%Y") ######################  |
+-----------------------------------------------------------------------+
INST2

exit 0
