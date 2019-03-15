	
  
  
msg_box "This option will update your server every week on Sundays at 18:00 (6 PM). 
The update will run the built in script 'update.sh' which will update both the server packages and Nextcloud itself.

You can read more about it here: https://www.techandme.se/nextcloud-update-is-now-fully-automated/
Please keep in mind that automatic updates might fail hence it's important to have a proper backup in place if you plan
to run this option.

In the next step you will be able to choose to proceed or exit."
ask_yes_no "Do you want to continue?"


crontab -u root -l | { cat; echo "0 18 * * SUN $SRIPTS/update.sh"; } | crontab -u root -


ask_yes_no "Do you want to reboot your server after every upgrade?
# Add "reboot" to update.sh"
