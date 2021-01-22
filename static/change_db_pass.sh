#!/bin/bash
true
SCRIPT_NAME="Change Database Password"
# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh || source <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)

# Get all needed variables from the library
ncdbpass
ncdb

# T&M Hansson IT AB © - 2021, https://www.hanssonit.se/

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Change PostgreSQL Password
cd /tmp
cat "$NCPATH"/config/config.php # TODO
sudo -u www-data php "$NCPATH"/occ config:system:set dbpassword --value="$NEWPGPASS"

if is_this_installed postgresql-common
then
    OUTPUT="$(sudo -u postgres psql -c "ALTER USER $NCUSER WITH PASSWORD '$NEWPGPASS'";)"
elif is_docker_running && docker ps -a --format "{{.Names}}" | grep -q "^nextcloud-postgresql$"
then
    OUTPUT="$(docker exec nextcloud-postgresql psql "$NCCONFIGDB" -U "$NCUSER" -c "ALTER USER $NCUSER WITH PASSWORD '$NEWPGPASS'";)"
else
    exit 1
fi

# Check if it was successful
if [ "$OUTPUT" == "ALTER ROLE" ]
then
    sleep 1
else
    print_text_in_color "$IRed" "Changing PostgreSQL Nextcloud password failed."
    sed -i "s|  'dbpassword' =>.*|  'dbpassword' => '$NCCONFIGDBPASS',|g" /var/www/nextcloud/config/config.php
    print_text_in_color "$IRed" "Nothing is changed. Your old password is: $NCCONFIGDBPASS"
    exit 1
fi

# Change it for the docker config, too
if is_docker_running && docker ps -a --format "{{.Names}}" | grep -q "^nextcloud-postgresql$"
then
    print_text_in_color "$ICyan" "Downloading the needed tool to get the current Postgresql config..."
    docker pull assaflavie/runlike
    echo '#/bin/bash' > /tmp/psql-conf
    docker run --rm -v /var/run/docker.sock:/var/run/docker.sock assaflavie/runlike -p nextcloud-postgresql \
>> /tmp/psql-conf
    cat /tmp/psql-conf # TODO
    sed -i "/POSTGRES_PASSWORD/s/--env=.*/--env=POSTGRES_PASSWORD=$NEWPGPASS \\\\/" /tmp/psql-conf
    docker stop nextcloud-postgresql
    docker rm nextcloud-postgresql
    check_command bash /tmp/psql-conf
cat "$NCPATH"/config/config.php # TODO
fi