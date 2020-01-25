
# Cleanup 1
occ_command maintenance:repair
rm -f "$SCRIPTS/ip.sh"
rm -f "$SCRIPTS/change_db_pass.sh"
rm -f "$SCRIPTS/test_connection.sh"
rm -f "$SCRIPTS/instruction.sh"
rm -f "$NCDATA/nextcloud.log"
rm -f "$SCRIPTS/static_ip.sh"

find /root "/home/$UNIXUSER" -type f \( -name '*.sh*' -o -name '*.html*' -o -name '*.tar*' -o -name 'results' -o -name '*.zip*' \) -delete
find "$NCPATH" -type f \( -name 'results' -o -name '*.sh*' \) -delete
sed -i "s|instruction.sh|nextcloud.sh|g" "/home/$UNIXUSER/.bash_profile"

truncate -s 0 \
    /root/.bash_history \
    "/home/$UNIXUSER/.bash_history" \
    /var/spool/mail/root \
    "/var/spool/mail/$UNIXUSER" \
    /var/log/apache2/access.log \
    /var/log/apache2/error.log \
    /var/log/cronjobs_success.log \
    "$VMLOGS/nextcloud.log"

sed -i "s|sudo -i||g" "/home/$UNIXUSER/.bash_profile"

cat << ROOTNEWPROFILE > "/root/.bash_profile"
# ~/.profile: executed by Bourne-compatible login shells.

if [ "/bin/bash" ]
then
    if [ -f ~/.bashrc ]
    then
        . ~/.bashrc
    fi
fi

if [ -x /var/scripts/nextcloud-startup-script.sh ]
then
    /var/scripts/nextcloud-startup-script.sh
fi

if [ -x /var/scripts/history.sh ]
then
    /var/scripts/history.sh
fi

mesg n

ROOTNEWPROFILE

# Upgrade system
print_text_in_color "$ICyan" "System will now upgrade..."
bash $SCRIPTS/update.sh

# Cleanup 2
apt autoremove -y
apt autoclean

# Set trusted domain in config.php
if [ -f "$SCRIPTS"/trusted.sh ]
then
    bash "$SCRIPTS"/trusted.sh
    rm -f "$SCRIPTS"/trusted.sh
else
    run_static_script trusted
fi

# Success!
msg_box "Congratulations! You have successfully installed Nextcloud!

Login to Nextcloud in your browser:
- IP: $ADDRESS
- Hostname: $(hostname -f)

SUPPORT:
Please ask for help in the forums, visit our shop to buy support,
or buy a yearly subscription from Nextcloud:
- SUPPORT: https://shop.hanssonit.se/product/premium-support-per-30-minutes/
- FORUM: https://help.nextcloud.com/
- SUBSCRIPTION: https://nextcloud.com/pricing/ (Please refer to @enoch85)

Please report any bugs here: https://github.com/nextcloud/vm/issues

TIPS & TRICKS:
1. Publish your server online: https://goo.gl/iUGE2U

2. To login to PostgreSQL just type: sudo -u postgres psql nextcloud_db

3. To update this VM just type: sudo bash /var/scripts/update.sh

4. Change IP to something outside DHCP: sudo nano /etc/netplan/01-netcfg.yaml

5. For a better experience it's a good idea to setup an email account here:
   https://yourcloud.xyz/settings/admin"

# Prefer IPv6
sed -i "s|precedence ::ffff:0:0/96  100|#precedence ::ffff:0:0/96  100|g" /etc/gai.conf

# Done
print_text_in_color "$IGreen" "Installation done, system will now reboot..."
rm -f "$SCRIPTS/you-can-not-run-the-startup-script-several-times"
