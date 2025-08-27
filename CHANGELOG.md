### Download can be found here: https://www.hanssonit.se/nextcloud-vm/ 

**Please note that BOTH disks need to be imported for the VM to function properly.**

- Check the latest commits here: https://github.com/nextcloud/vm/commits/main
- Documentation can be found here: https://docs.hanssonit.se/s/W6fMouPiqQz3_Mog/virtual-machines-vm/d/W7Du9uPiqQz3_Mr1/nextcloud-vm-machine-configuration

PR's are more than welcome. Happy Nextclouding!

### Different versions
If you run Hyper-V or want 500 GB, 1 TB or 2 TB VM you can download it from [T&M Hansson IT's shop](https://shop.hanssonit.se/product-category/virtual-machine/nextcloud/). 

## All future releases

### Full changelog:
- [VM](https://github.com/nextcloud/vm/releases/)
- [Nextcloud](https://nextcloud.com/changelog/)


## 26.0.0

### Full changelog:
- [VM](https://github.com/nextcloud/vm/releases/tag/26.0.0)
- [Nextcloud](https://nextcloud.com/changelog/#latest26)

## 25.0.2

### Small changelog:
- Drop all tables from FTS when reinstalling to avoid leftovers
- Make Talk security optional. Should work out of the box on all scenarios now. 
- Previewgenerator and Webmin are no longer default apps during installation
- Support really old versions when migrating/upgrading Nextcloud
- Improve some scripts and other stuff in the `not-supported` folder
- Minor bugfixes and improvements
- And more...

### Full changelog:
- [https://github.com/nextcloud/vm/compare/24.0.5..25.0.2](https://github.com/nextcloud/vm/compare/24.0.5..25.0.2)
- [https://nextcloud.com/changelog/#latest25](https://nextcloud.com/changelog/#latest25)

## 24.0.5

### Small changelog:
- Update Fail2ban with a better regex
- Fix FTS, and make sure it's gone when removed (even DB)
- Make Talk installable again by fixing source-repos and some tweaks to the script
- Fix dependencies for Bitwarden
- Improve the port checking function (for checking open ports)
- Allow `NCDATA` to be other than default when checking for Nextcloud version (`lowest_compatible_version()`)
- Upgrade Realtek firmware drivers for the Home/SME Nextcloud server
- Add Googles DNS as an option (user request)
- Always recover old Nextcloud apps, even if app store is broken
- Remove some legacy code
- Improve backup scripts and other stuff in the `not-supported` folder
- Ubuntu 22.04 reached its first maintenance release, consider it 100% stable.
- And more...

### Full changelog:
- [https://github.com/nextcloud/vm/compare/24.0.1..24.0.5](https://github.com/nextcloud/vm/compare/24.0.1..24.0.5)
- [https://nextcloud.com/changelog/#latest24](https://nextcloud.com/changelog/#latest24)


## 24.0.1

This release is quite huge, including Ubuntu 22.04 (minimal), PHP-FPM 8.1, and PosgreSQL 14.

### Small changelog:
- Prefer use of local lib file
- Add `addons/fix_invalid_modification_time.sh`
- Use minimal OS, instead of full blown. Install only needed dependecies.
- Deprecate Ubuntu 18.04
- Upgrade to Ubuntu 22.04
- Upgrade to PHP 8.1
- Upgrade to PostgreSQL 14
- Upgrade Documentserver scripts to work with the new Docker images
- Deprectae `apt-key` and introduce a new and better way for adding keys
- Make the menu update option default. It first upgrades minor, then asks for major if applicable
- Only clean disk if it's 70% full and/or less than 100 GB left
- Remove legacy code
- Make it possible to add your own DNS servers during installation (not setup)
- Do not ask for password change if it differs from default, since that means you probably already set your own password
- Make it possible to add your own GUI user during installation
- Change DH-param instead of DSA-param
- Make Talk a bit safer
- Minor bugfixes and improvements
- Updated geoblock database
- Fixed a few backup related details
- And more...

### Full changelog:
- https://github.com/nextcloud/vm/compare/23.0.2..24.0.1
- https://nextcloud.com/changelog/#latest24

## 24.0.0.1

### This is a pre-release. Available as a VM, but only the free 40 GB version.

### Full changelog:
- https://github.com/nextcloud/vm/compare/24.0.0..24.0.0.1
- https://nextcloud.com/changelog/#latest24


## 24.0.0

### This is a pre-release. Only available in master.

### Full changelog:
- https://github.com/nextcloud/vm/compare/23.0.2..24.0.0
- https://nextcloud.com/changelog/#latest24

## 23.0.2

### Small changelog:
- Change to another Full Text Search implementation
- Improve deSEC functions
- Minor bugfixes and improvements
- And more...

### Full changelog:
- https://github.com/nextcloud/vm/compare/23.0.1..23.0.2
- https://nextcloud.com/changelog/#latest23

## 23.0.1

### Small changelog:
- Fixed all the bugs with the old release (23.0.0)
- Minor bugfixes and improvements
- And more...

### Full changelog:
- https://github.com/nextcloud/vm/compare/23.0.0..23.0.1
- https://nextcloud.com/changelog/#latest23

## 23.0.0

### Small changelog:
- Change from lool to cool for Collabora
- Make it possible to ugrade NIC-firmware from all old releases ([Home/SME server](https://shop.hanssonit.se/product-category/nextcloud/home-sme-server/))
- Minor bugfixes and improvements
- And more...

### Full changelog:
- https://github.com/nextcloud/vm/compare/22.2.2..23.0.0
- https://nextcloud.com/changelog/#latest23

## 22.2.2

### Small changelog:
- Change to AllowOverride None for Apache and include .htaccess instead (speeds up I/O)
- Change IPv4 check (WANIP4)
- Set productname
- Minor bugfixes and improvements
- And more...

### Full changelog:
- https://github.com/nextcloud/vm/compare/22.2.0..22.2.2
- https://nextcloud.com/changelog/#latest22

## 22.2.0

### Small changelog:
- Upgrade Home/SME server NIC firmware
- Add NVMe to format disk
- Change keyserver
- Minor bugfixes and improvements
- And more...

### Full changelog:
- https://github.com/nextcloud/vm/compare/22.1.1..22.2.0
- https://nextcloud.com/changelog/#latest22


## 22.1.1

### Small changelog:
- Remove Group Folders in the standard installation
- Improved deSEC and added support for existing accounts
- Improved SPAMHAUS rules and script
- Show the hostname when notifying - better if you run multiple servers
- Only update update script if it's older than 120 days
- Changed to EDCSA for certbot (TLS)
- Add script for removal or deSEC + subdomain
- Make deSEC a menu instead
- Crucial fixes for the new PN51 network drivers
- Update script - only update the updatenotification script if a new Nextcloud update is available
- Updated and renamed Bitwarden RS to Vaultwarden
- Updated geoblock database - August 2021
- Update script - don't execute the update before all cronjobs are finished
- Always create a backup before updating
- Minor bugfixes and improvements
- And more...

### Full changelog:
- https://github.com/nextcloud/vm/compare/22.0.0..22.1.1
- https://nextcloud.com/changelog/#latest22

## 22.0.0

### Small changelog:
- Add SMTP2GO to SMTP-Relay
- Remove APCu and replace with Redis instead
- Made it possible to add subdomains to deSEC
- Improved spinner_loading
- Added dates to automatic updates log
- Added regular ZFS snapshot prune
- Added retention for Nextclouds user activities
- Previewgenerator - allow to clear all previews
- Update script - update Nextclouds mimetype list
- Moved mimteype update to nextcloud_configuration menu
- Reworked office scripts
- Update script - change crontab on all installations to 5 minutes
- Fixed a bug with Netdata
- Geoblock - updated link to csv file
- Refactored the bitwarden_mailconfig script
- Added more functionality to curl_to_dir
- Docker documentserver - don't restart docker daemon upon installation
- Restart notify push in some situations
- Make sure sudo and software-properties-common is installed
- Fixed password generation in edge cases
- Reworked the cookielifetime script
- Updated geoblock database - June 2021
- Added option to check for 0-byte files
- Changed from apt to apt-get
- Simplified ClamAV notifications and small fix to fail2ban notification
- Harden-SSH script - allow to set up 2FA authentication
- SMB-server - added option to automatically empty recylce bins
- SMB-server - added option to empty all recycle bins
- SMB-server - Create the files directory for new users directly during the user creation
- Reworked system-restore
- Minor bugfixes and improvements
- And more...

### Full changelog:
- https://github.com/nextcloud/vm/compare/21.0.2..22.0.0
- https://nextcloud.com/changelog/#latest22

## 21.0.2

### Small changelog:
- Make it possible to choose port for public access in the deSEC setup (only when you choose TLS)
- Fix bugs with the deSEC script
- Avoid ending up in a loop in the deSEC script
- It's now possible to check for NONO ports with a function
- Loop port selection in the Talk script
- Move backups location to /mnt/NCBACKUPS and delete backups from last year
- Tune chunking in GUI uploads
- Clean up some more scripts in the end of each setup
- Add the Azure kernel for Hyper-V VMs
- Shorten the time files are stored in trashbin (can still be configured)
- Escape all Apache Log dirs correctly
- Made some enhancements to scripts in the [not-supported folder](https://github.com/nextcloud/vm/tree/main/not-supported)
- Minor bugfixes and improvements
- And more...

### Full changelog:
- https://github.com/nextcloud/vm/compare/21.0.1..21.0.2
- https://nextcloud.com/changelog/#latest21

## 21.0.1

### Small changelog:
- Add TLS with DNS and deSEC. It's now possible to get DNS from a local machine without any open ports!
- ClamAV - give the daemon more time to start
- SMB-server - completely rework how directories get mounted to Nextcloud
- SMTP-mail - add providers
- Create a script for the Pico CMS Nextcloud app
- Add a Firewall script to the not-supported folder
- Add SSH hardening
- Add deSEC magic
- S.M.A.R.T. Monitoring - test drives directly
- Add a script for the Facerecognition Nextcloud app
- ClamAV - improve weekly full-scan tremendously
- Update geoblock database - april
- Speed up the network check if the network already works
- Made some enhancements to scripts in the [not-supported folder](https://github.com/nextcloud/vm/tree/main/not-supported)
- Minor bugfixes and improvements

### Full changelog:
- https://github.com/nextcloud/vm/compare/21.0.0..21.0.1
- https://nextcloud.com/changelog/#latest21

## 21.0.0

### Small changelog:
- Added Push Notifications for Nextcloud (`High Performance Backend for Nextcloud files`)
- Added Whiteboard for Nextcloud (`New in Nextcloud 21`)
- Moved Extract for Nextcloud to its own script
- Add phone region (new in 21)
- Made sure that all docker containers only listen on localhost 
- Improve Strict Transport Security in TLS
- DDclient - added No-IP
- Updated geoblock database files
- Avoid double crontabs when reexecuting some scripts
- Don't enable disabled apps after update
- Geoblock - allow some IP-addresses by default
- Fix watchtower updates
- Geoblock - add Let's Encrypt advice
- Fix upgrade.disable-web
- Don't break update when enabling app
- Fix not enabled PECL extensions
- Prevent apps from breaking the update due to incompatibility
- Made some enhancements to scripts in the [not-supported folder](https://github.com/nextcloud/vm/tree/main/not-supported)
- Minor bugfixes and improvements

### Full changelog:
- https://github.com/nextcloud/vm/compare/20.0.7..21.0.0
- https://nextcloud.com/changelog/#latest21

## 20.0.7

### Small changelog:
- Ask to get the latest `update.sh` script when running updates from `menu.sh`
- Allow to reinstall Bitwarden RS also if local files are present
- Updated geoblock database files
- Made some enhancements to scripts in the [not-supported folder](https://github.com/nextcloud/vm/tree/main/not-supported)
- Minor bugfixes and improvements

### Full changelog:
- https://github.com/nextcloud/vm/compare/20.0.5..20.0.7
- https://nextcloud.com/changelog/#latest20

## 20.0.5

### Small changelog:
- Minor bugfixes and improvements

### Full changelog:
- https://github.com/nextcloud/vm/compare/20.0.4..20.0.5
- https://nextcloud.com/changelog/#latest20


## 20.0.4

### Major changes:
- We upgraded the compatibility for VMware. More info [here](https://docs.hanssonit.se/s/W6fMouPiqQz3_Mog/virtual-machines-vm/d/W7Du9uPiqQz3_Mr1/nextcloud-vm-machine-configuration). Changes are based on [this](https://github.com/nextcloud/vm/issues/1358) issue.

### Small changelog:
- Happy new year!
- Add ban notifications to Fail2ban
- Remove unattended upgrades to improve stability (we have our own auto updater)
- Fixes to the SMB Mount script
- Fixes to DDclient
- Minor bugfixes and improvements

### Full changelog:
- https://github.com/nextcloud/vm/compare/20.0.3..20.0.4
- https://nextcloud.com/changelog/#latest20


## 20.0.3

### Small changelog:
- Allow to choose between latest version or not
- Always run the permissions script
- Don't allow MariaDB specifically
- Fix PHP error message from Redis
- Fix grammar and spelling
- Update geoblock files
- Minor bugfixes and improvements


### Full changelog:
- https://github.com/nextcloud/vm/compare/20.0.2..20.0.3
- https://nextcloud.com/changelog/#latest20

## 20.0.2

### Small changelog:
- Fixed bugs with the `--provisioning` flag
- Updated geoblock.sh to get rid of jq
- Added a script-explainer to nextcloud_install_production.sh
- ClamAV - added a mechanism to inform about found files
- Fixed a bug in midnight-commander.sh
- Created smart-monitoring.sh to allow continuously smart checking
- Switched from Travis to Github Actions
- Added Reviewdog
- Improved previewgenerator
- Made some SC rules global
- Fixed some problems with wrong ownership of /mnt/ncdata
- Fixed link in startup-script
- Fixed ClamAV-Fullscan
- Added apt over https
- Further improved ClamAV
- Allow to reinstall automatic updates
- Improved partition check during the install-script
- Fixed some typo's
- Added more options to the [not-supported folder](https://github.com/nextcloud/vm/tree/main/not-supported) and made some enhancements
- Minor bugfixes and improvements


### Full changelog:
- https://github.com/nextcloud/vm/compare/20.0.1..20.0.2
- https://nextcloud.com/changelog/#latest20

## 20.0.1

### Small changelog:
- Made the setup of SMTP-mail more reliable
- Added a switch to the install-script to enable automatic provisioning of new releases
- Changed occ_command to nextcloud_occ to simplify copy and paste between scripts and CLI
- Improved the logging for SMTP-mail
- Added deSEC to DDclient-configuration
- Implemented an option to create LVM snapshots during the update script for certain instances
- Don't clear the CLI history anymore to simplify debugging
- Created geblock.sh in order to allow access from configured countries and/or continents
- Made it more clear that a Nextcloud update started
- Added DuckDNS to DDclient-configuration
- Fixed an incorrect OnlyOffice-URL
- Improved the guidance how to control whiptails
- Added some popups that explain the Additional Apps Menu and Server Configuration Menu during the startup script
- Switched to TLS1.3 for new website-configurations on Ubuntu 20.04
- Added a mechanism to update geoblock database file and added the geoblockdat folder to the repository
- SMTP-mail: allow to cancel the removal of configurations and packets if the testmail fails in order to simplify debugging
- Made BPYTOP its own script
- Standardized the usage of the word CLI
- Made Midnight Commander its own script
- Updated all app scripts with a new function for reinstalling
- Renamed the talk-signaling script to talk and deleted the old talk script
- Use start_if_stopped everywhere it fits
- Updatenotification: added an advice for Major Nextcloud updates
- Improved previewgenerator
- Fixed problems with static-ip
- Added Docker migrate script
- Fixed and issue with ClamAV
- Added more options to the [not-supported folder](https://github.com/nextcloud/vm/tree/main/not-supported) and made some enhancements
- Minor bugfixes and improvements

### Full changelog:
- https://github.com/nextcloud/vm/compare/20.0.0..20.0.1
- https://nextcloud.com/changelog/#latest20

## 20.0.0

### Small changelog:
- Add SMTP email relay to be able to send emails directly from the OS (Ubuntu)
- Make it possible to open ports with UPNP
- Update notify_admin_gui to cache all found admin users (tested with 500 users, and it's MUCH faster now)
- Disable hibernation (Ubuntu)
- Set archive.ubuntu.com as default Repo (Ubuntu)
- Standardize whiptails even more
- Improve fetch_lib
- Use fetch_lib in all scripts to prefer local library instead of hammering Github with requests in every script
- Update all Docker containers one by one when the update script is run due to compatibility issues with Bitwarden Password manager
- Improve the way passwords are set during the initial setup
- SMBmount: Introduce the option to customize the mount before adding as external storage to Nextcloud
- SMBmount: Add the option to utilize inotify to actively watch over externally changed files and folders
- Repository: cleanup by removing duplicate scripts and not-needed functions
- Repository: added the [not-supported folder](https://github.com/nextcloud/vm/tree/main/not-supported) with additional options like creating a SMB-server

- Minor bugfixes and improvements

### Full changelog:
- https://github.com/nextcloud/vm/compare/19.0.3..20.0.0
- https://nextcloud.com/changelog/#latest20

## 19.0.3

### Small changelog:
- Standardize input_box flow
- Automatically rewrite Webmin to HTTPS
- Add default dark mode theme to Adminer
- Make Adminer work on HTTP/2
- Introduce fetch_lib and chain libaries - this is now the new way of fetching the libs
- Add more menu scripts
- Add more Yes/No boxes and fix occurrences where the text wasn't shown due to print_text_in_color
- Standardize Whiptails even more
- Change to TLS1.2 all over
- Make functions out of all special variables
- Create a new (smart) startup script with basic server settings
- Automatically get the main domain for all scripts with built in proxies
- Minor bugfixes and improvements

### Full changelog:
- https://github.com/nextcloud/vm/compare/19.0.2..19.0.3
- https://nextcloud.com/changelog/#latest19

### Known errors:
- N/A
