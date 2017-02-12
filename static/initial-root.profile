# ~/.profile: executed by Bourne-compatible login shells.

if [ "$BASH" ]; then
  if [ -f ~/.bashrc ]; then
    . ~/.bashrc
  fi
fi

mesg n || true

# Resize or use hd
mkdir -p /var/scripts

if              [ -f bash /var/scripts/resize-sd.sh ];    then

                rm bash /var/scripts/resize-sd.sh
else
                wget https://raw.githubusercontent.com/techandme/NextBerry/master/static/resize-sd.sh -P /var/scripts
                chmod +x /var/scripts/resize-sd.sh
fi
if [[ $? > 0 ]]
then
        echo "Download of scripts failed. System will reboot in 10 seconds..."
        sleep 10
        reboot
else
        clear
fi

bash /var/scripts/resize-sd.sh

# Grab install scripts
mkdir -p /var/scripts

if              [ -f /var/scripts/nextcloud_install_production.sh ];	then

		rm /var/scripts/nextcloud_install_production.sh
else
                wget https://raw.githubusercontent.com/techandme/NextBerry/master/nextcloud_install_production.sh -P /var/scripts
                chmod +x /var/scripts/nextcloud_install_production.sh
fi
if [[ $? > 0 ]]
then
        echo "Download of scripts failed. System will reboot in 10 seconds..."
        sleep 10
        reboot
else
	clear
fi

bash /var/scripts/nextcloud_install_production.sh
