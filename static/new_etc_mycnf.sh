#!/bin/bash
# shellcheck disable=2034,2059
true
# shellcheck source=lib.sh
MYCNFPW=1 . <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)
unset MYCNFPW

/bin/cat <<WRITENEW >$ETCMYCNF
text1
text2
text3
text4
WRITENEW

# Restart MariaDB
mysqladmin shutdown --force & spinner_loading
wait
check_command systemctl restart mariadb & spinner_loading

exit
