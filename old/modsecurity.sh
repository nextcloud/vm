#!/bin/bash

# T&M Hansson IT AB © - 2024, https://www.hanssonit.se/

true
SCRIPT_NAME="Modsecurity"
# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh

print_text_in_color "$ICyan" "Installing ModSecurity..."

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Check if root
root_check

# Add modsecurity
apt-get update -q4 & spinner_loading
install_if_not libapache2-mod-security2 
install_if_not modsecurity-crs
mv /etc/modsecurity/modsecurity.conf-recommended /etc/modsecurity/modsecurity.conf

msg_box "WARNING WARNING WARNING WARNING WARNING WARNING:

Do not enable active defense if you don't know what you're doing!
It will break OnlyOffice, and it may break other stuff as well in Nextcloud as it's
blocking access to files automatically.

You can monitor the audit log by typing this command in your shell:
tail -f /var/log/apache2/modsec_audit.log

You can disable it by typing this command in your shell:
sed -i 's/SecRuleEngine .*/SecRuleEngine DetectionOnly/g' /etc/modsecurity/modsecurity.conf

YOU HAVE BEEN WARNED."
if yesno_box_yes "Do you want to enable active defense?"
then
    sed -i 's|SecRuleEngine .*|SecRuleEngine on|g' /etc/modsecurity/modsecurity.conf
fi

cat << MODSECWHITE > "/etc/modsecurity/whitelist.conf"
<Directory $NCPATH>
# VIDEOS
  SecRuleRemoveById 958291             # Range Header Checks
  SecRuleRemoveById 981203             # Correlated Attack Attempt

  # PDF
  SecRuleRemoveById 950109             # Check URL encodings

  # ADMIN (webdav)
  SecRuleRemoveById 960024             # Repeatative Non-Word Chars (heuristic)
  SecRuleRemoveById 981173             # SQL Injection Character Anomaly Usage
  SecRuleRemoveById 981204             # Correlated Attack Attempt
  SecRuleRemoveById 981243             # PHPIDS - Converted SQLI Filters
  SecRuleRemoveById 981245             # PHPIDS - Converted SQLI Filters
  SecRuleRemoveById 981246             # PHPIDS - Converted SQLI Filters
  SecRuleRemoveById 981318             # String Termination/Statement Ending Injection Testing
  SecRuleRemoveById 973332             # XSS Filters from IE
  SecRuleRemoveById 973338             # XSS Filters - Category 3
  SecRuleRemoveById 981143             # CSRF Protections ( TODO edit LocationMatch filter )

  # COMING BACK FROM OLD SESSION
  SecRuleRemoveById 970903             # Microsoft Office document properties leakage

  # NOTES APP
  SecRuleRemoveById 981401             # Content-Type Response Header is Missing and X-Content-Type-Options is either missing or not set to 'nosniff'
  SecRuleRemoveById 200002             # Failed to parse request body

  # UPLOADS ( 20 MB max excluding file size )
  SecRequestBodyNoFilesLimit 20971520

  # GENERAL
  SecRuleRemoveById 960017             # Host header is a numeric IP address

  # SAMEORIGN
  SecRuleRemoveById 911100             # fpm socket

  # REGISTERED WARNINGS, BUT DID NOT HAVE TO DISABLE THEM
  #SecRuleRemoveById 981220 900046 981407
  #SecRuleRemoveById 981222 981405 981185 981184
</Directory>
MODSECWHITE

# Don't log in Apache2 error.log, only in a separate log (/var/log/apache2/modsec_audit.log)
check_command sed -i 's|SecDefaultAction "phase:1,log,auditlog,pass"|# SecDefaultAction "phase:1,log,auditlog,pass"|g' /etc/modsecurity/crs/crs-setup.conf
check_command sed -i 's|SecDefaultAction "phase:2,log,auditlog,pass"|# SecDefaultAction "phase:2,log,auditlog,pass"|g' /etc/modsecurity/crs/crs-setup.conf
check_command sed -i 's|# SecDefaultAction "phase:1,nolog,auditlog,pass"|SecDefaultAction "phase:1,nolog,auditlog,pass"|g' /etc/modsecurity/crs/crs-setup.conf
check_command sed -i 's|# SecDefaultAction "phase:2,nolog,auditlog,pass"|SecDefaultAction "phase:2,nolog,auditlog,pass"|g' /etc/modsecurity/crs/crs-setup.conf

if [ -f /etc/modsecurity/whitelist.conf ]
then
    print_text_in_color "$IGreen" "ModSecurity activated!"
    restart_webserver
fi
