
# Download and install Contacts
if [ ! -d "$NCPATH/apps/contacts" ]
then
    wget -q "$CONVER_REPO/v$CONVER/$CONVER_FILE" -P "$NCPATH/apps"
    tar -zxf "$NCPATH/apps/$CONVER_FILE" -C "$NCPATH/apps"
    cd "$NCPATH/apps"
    rm "$CONVER_FILE"
fi

# Enable Contacts
if [ -d "$NCPATH"/apps/contacts ]
then
    sudo -u www-data php "$NCPATH"/occ app:enable contacts
fi
