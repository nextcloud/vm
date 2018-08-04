#!/bin/bash
# shellcheck disable=2034,2059
true
# shellcheck source=lib.sh
MYCNFPW=1 . <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)
unset MYCNFPW

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Check if root
root_check

# Add modsecurity
apt install libapache2-mod-security2  modsecurity-crs -y
mv /etc/modsecurity/modsecurity.conf-recommended /etc/modsecurity/modsecurity.conf
# Do not enable the next line unless you know what you are doing. This will enable active defence.
# sed -i 's/SecRuleEngine DetectionOnly/SecRuleEngine on/g' /etc/modsecurity/modsecurity.conf
# You can monitor tail -f /var/log/apache2/modsec_audit.log

/bin/cat <<MODSECWHITE >"/etc/modsecurity/whitelist.conf"
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

  # UPLOADS ( 5 MB max excluding file size )
  SecRequestBodyNoFilesLimit 5242880

  # GENERAL
  SecRuleRemoveById 960017             # Host header is a numeric IP address

  # SAMEORIGN
  SecRuleRemoveById 911100             # fpm socket

  # REGISTERED WARNINGS, BUT DID NOT HAVE TO DISABLE THEM
  #SecRuleRemoveById 981220 900046 981407
  #SecRuleRemoveById 981222 981405 981185 981184
</Directory>
MODSECWHITE
