#!/bin/bash

# T&M Hansson IT AB © - 2024, https://www.hanssonit.se/

true
SCRIPT_NAME="Create daily ZFS prune script"
# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh

# Check if root
root_check

# Add daily snapshot prune
cat << PRUNZE_ZFS > "$SCRIPTS/daily-zfs-prune.sh"
#!/bin/bash

# Source the library
source /var/scripts/fetch_lib.sh

# Check if root
root_check

# Run the script
run_script DISK prune_zfs_snaphots
PRUNZE_ZFS

# Add crontab
chmod +x "$SCRIPTS/daily-zfs-prune.sh"
crontab -u root -l | grep -v "$SCRIPTS/daily-zfs-prune.sh"  | crontab -u root -
crontab -u root -l | { cat; echo "@daily $SCRIPTS/daily-zfs-prune.sh >/dev/null" ; } | crontab -u root -
