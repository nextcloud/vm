#!/bin/bash

# T&M Hansson IT AB © - 2024, https://www.hanssonit.se/
# Sami Nieminen - 2024 https://nenimein.fi

# This script helps creating a backup script for your Nextcloud instance to various cloud storage providers.
# It uses Restic to back up your configuration, database and optionally your /mnt/ncdata folder.
# Restic will be downloaded from official binaries to make Azure backups work.
# Server will be set to maintenance mode during backup. 
# If you have large amount of files to backup, please run the script interactively before automatic schedule.

true

SCRIPT_NAME="restic-cloud-backup"

# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Check if root
root_check

# Variables
BACKUP_SCRIPT_NAME="$SCRIPTS/restic-cloud-backup.sh"
BACKUP_CONFIG="$HOME/.restic_cloud_backup_config"

# Install restic from official binaries because debian decided to remove Azure backups from binary for some unknown reason :(
# https://forum.restic.net/t/version-0-16-4-and-azure-blob/7864
# https://salsa.debian.org/go-team/packages/restic/-/tree/master/debian/patches?ref_type=heads
install_restic() {
    # Get latest version from GitHub API
    print_text_in_color "$ICyan" "Getting latest restic version..."
    LATEST_VERSION=$(curl -s https://api.github.com/repos/restic/restic/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    if [ -z "$LATEST_VERSION" ]; then
        msg_box "Failed to get latest restic version. Please try again later."
        exit 1
    fi

    # Remove 'v' prefix from version for comparison and binary download
    LATEST_VERSION_CLEAN=${LATEST_VERSION#v}

    # Check if restic is already installed with correct version
    if [ -x "$(command -v restic)" ]; then
        INSTALLED_VERSION=$(restic version | grep "restic" | awk '{print $2}')
        print_text_in_color "$ICyan" "Restic $INSTALLED_VERSION is already installed, checking for newer version..."
    fi

    # Check if we need to upgrade
    if [ -n "$INSTALLED_VERSION" ] && [ "$INSTALLED_VERSION" = "$LATEST_VERSION_CLEAN" ]; then
        print_text_in_color "$IGreen" "Latest version $LATEST_VERSION is already installed!"
        return 0
    fi

    # Download and install restic
    print_text_in_color "$ICyan" "Installing restic $LATEST_VERSION..."

    # Create temp directory
    TMP_DIR=$(mktemp -d)

    # Download binary
    print_text_in_color "$ICyan" "Downloading restic $LATEST_VERSION..."
    if ! curl -L "https://github.com/restic/restic/releases/download/$LATEST_VERSION/restic_${LATEST_VERSION#v}_linux_amd64.bz2" -o "$TMP_DIR/restic.bz2"; then
        msg_box "Failed to download restic. Please try again later."
        rm -rf "$TMP_DIR"
        exit 1
    fi

    # Extract binary
    print_text_in_color "$ICyan" "Extracting restic binary to $TMP_DIR"
    if ! bunzip2 "$TMP_DIR/restic.bz2"; then
        msg_box "Failed to extract restic binary."
        rm -rf "$TMP_DIR"
        exit 1
    fi

    # Make executable and move to /usr/local/bin
    print_text_in_color "$ICyan" "Moving restic binary to /usr/local/bin/"
    chmod +x "$TMP_DIR/restic"
    if ! mv "$TMP_DIR/restic" /usr/local/bin/; then
        msg_box "Failed to install restic binary."
        rm -rf "$TMP_DIR"
        exit 1
    fi

    # Clean up
    rm -rf "$TMP_DIR"

    # Verify installation
    if ! restic version | grep -q "$LATEST_VERSION_CLEAN"; then
        msg_box "Failed to verify restic installation."
        exit 1
    fi

    print_text_in_color "$IGreen" "Successfully installed restic $LATEST_VERSION"
    return 0
}

# Functions
choose_backup_location() {
    BACKUP_TYPE=$(whiptail --title "$TITLE" --menu \
        "Choose backup destination" "$WT_HEIGHT" "$WT_WIDTH" 4 \
        "Backblaze B2" "" \
        "AWS S3" "" \
        "Azure Blob" "" 3>&1 1>&2 2>&3)

    case "$BACKUP_TYPE" in
        "Backblaze B2")
            B2_ACCOUNT_ID=$(input_box_flow "Enter Backblaze B2 Account ID \nThis is your Application Key keyID:")
            B2_ACCOUNT_KEY=$(input_box_flow "Enter Backblaze B2 Account Key \nThis is the Application Key Secret:")
            B2_BUCKET_NAME=$(input_box_flow "Enter Backblaze B2 Bucket Name:")
            RESTIC_REPOSITORY="b2:$B2_BUCKET_NAME:"
            ;;
        "AWS S3")
            AWS_ACCESS_KEY_ID=$(input_box_flow "Enter AWS Access Key ID:")
            AWS_SECRET_ACCESS_KEY=$(input_box_flow "Enter AWS Secret Access Key:")
            AWS_DEFAULT_REGION=$(input_box_flow "Enter AWS Region (e.g., us-east-1):")
            S3_BUCKET_NAME=$(input_box_flow "Enter S3 Bucket Name:")
            RESTIC_REPOSITORY="s3:s3.${AWS_DEFAULT_REGION}.amazonaws.com/${S3_BUCKET_NAME}"
            ;;
        "Azure Blob")
            AZURE_ACCOUNT_NAME=$(input_box_flow "Enter Azure Storage Account Name")
            AZURE_ACCOUNT_KEY=$(input_box_flow "Enter Azure Storage Account Key:")
            AZURE_CONTAINER_NAME=$(input_box_flow "Enter Azure Storage Account Blob name:")
            RESTIC_REPOSITORY="azure:${AZURE_CONTAINER_NAME}:/"
            ;;
        *)
            msg_box "Invalid selection"
            exit 1
            ;;
    esac

    # Configure restic password
    RESTIC_PASSWORD=$(input_box_flow "Enter Restic Repository Password \nSAVE THIS! \nIF YOU LOSE IT YOU WILL NOT BE ABLE TO RESTORE THIS BACKUP:")
}

choose_backup_scope() {
    BACKUP_SCOPE=$(whiptail --title "$TITLE" --menu \
    "Choose what to backup" "$WT_HEIGHT" "$WT_WIDTH" 4 \
    "Minimal" "(Config files and database only)" \
    "Full" "(Config, database and /mnt/ncdata)" 3>&1 1>&2 2>&3)

    case "$BACKUP_SCOPE" in
        "Minimal")
            BACKUP_NCDATA="no"
            ;;
        "Full")
            BACKUP_NCDATA="yes"
            ;;
        *)
            msg_box "Invalid selection"
            exit 1
            ;;
    esac
}

setup_restic_excludes() {
    # Variables
    RESTIC_EXCLUDES="$HOME/.restic_cloud_backup_excludes"

    # Check if excludes file already exists
    if [ -f "$RESTIC_EXCLUDES" ]
    then
        msg_box "The restic excludes file already exists at $RESTIC_EXCLUDES. It will be used for backups."
        if yesno_box_yes "Do you want to edit the existing excludes file?"
        then
            if [ -x "$(command -v nano)" ]
            then
                nano "$RESTIC_EXCLUDES"
            else
                vim "$RESTIC_EXCLUDES"
            fi
        fi
        return 0
    fi

    # Create default excludes file
    touch "$RESTIC_EXCLUDES"
    chmod 600 "$RESTIC_EXCLUDES"

    # Add default excludes
    {
        echo "# Restic excludes file"
        echo "# One exclude pattern per line"
        echo ""

        # Add Nextcloud appdata/preview folder excludes if full backup is selected.
        if [ "$BACKUP_NCDATA" = "yes" ]
        then
            echo ""
            echo "# Nextcloud preview cache"
            echo "/mnt/ncdata/appdata*/preview/*"
            echo "/mnt/ncdata/appdata*/thumbnails/*"
        fi

    } > "$RESTIC_EXCLUDES"

    msg_box "A default excludes file has been created at $RESTIC_EXCLUDES.
You can edit this file to add or remove paths that should be excluded from backups.
Each line should contain one path or pattern to exclude."

    if yesno_box_yes "Do you want to edit the excludes file now?"
    then
        if [ -x "$(command -v nano)" ]
        then
            nano "$RESTIC_EXCLUDES"
        else
            vim "$RESTIC_EXCLUDES"
        fi
    fi

    # Return success
    return 0
}

# Ask for execution
msg_box "This script helps creating a backup script for your Nextcloud instance to various cloud storage providers.
It uses Restic to back up your configuration, database and optionally your /mnt/ncdata folder.
Restic will be downloaded from official binaries to make Azure backups work.
Server will be set to maintenance mode during backup. 
If you have large amount of files to backup, please run the script interactively before automatic schedule."

if ! yesno_box_yes "Do you want to create a backup script?"
then
    exit
fi

# Check if script already exists
if [ -f "$BACKUP_SCRIPT_NAME" ]
then
    msg_box "The backup script already exists. Please rename or delete $BACKUP_SCRIPT_NAME if you want to reconfigure the backup."
    exit 1
fi

# Install restic if not installed
if ! install_restic; then
    msg_box "Failed to install restic. Cannot continue."
    exit 1
fi

# Configure backup destination
choose_backup_location

# Choose backup scope
choose_backup_scope

if ! setup_restic_excludes; then
    msg_box "Failed to set up restic excludes file. Cannot continue."
    exit 1
fi

# Configure retention policy
BACKUP_RETENTION_DAILY=$(input_box_flow "Enter number of daily backups to keep:" "7")
BACKUP_RETENTION_WEEKLY=$(input_box_flow "Enter number of weekly backups to keep:" "4")
BACKUP_RETENTION_MONTHLY=$(input_box_flow "Enter number of monthly backups to keep:" "3")

# Configure backup time
if yesno_box_yes "Do you want to run the backup at the recommended time 4:00 AM?"
then
    BACKUP_TIME="00 04"
else
    while :
    do
        BACKUP_TIME=$(input_box_flow "Enter backup time (mm hh format, e.g. '00 04' for 4:00 AM):")
        if echo "$BACKUP_TIME" | grep -qE "^[0-5][0-9] ([01][0-9]|2[0-3])$"
        then
            break
        fi
        msg_box "Invalid time format. Please use mm hh format (e.g. '00 04' for 4:00 AM)"
    done
fi

# Save configuration
cat > "$BACKUP_CONFIG" << EOL
BACKUP_TYPE="$BACKUP_TYPE"
BACKUP_SCOPE="$BACKUP_SCOPE"
BACKUP_NCDATA="$BACKUP_NCDATA"
RESTIC_PASSWORD="$RESTIC_PASSWORD"
RESTIC_REPOSITORY="$RESTIC_REPOSITORY"
RESTIC_EXCLUDES="$RESTIC_EXCLUDES"
BACKUP_RETENTION_DAILY="$BACKUP_RETENTION_DAILY"
BACKUP_RETENTION_WEEKLY="$BACKUP_RETENTION_WEEKLY"
BACKUP_RETENTION_MONTHLY="$BACKUP_RETENTION_MONTHLY"


# B2 Configuration
B2_ACCOUNT_ID="$B2_ACCOUNT_ID"
B2_ACCOUNT_KEY="$B2_ACCOUNT_KEY"
B2_BUCKET_NAME="$B2_BUCKET_NAME"

# AWS S3 Configuration
AWS_ACCESS_KEY_ID="$AWS_ACCESS_KEY_ID"
AWS_SECRET_ACCESS_KEY="$AWS_SECRET_ACCESS_KEY"
AWS_DEFAULT_REGION="$AWS_DEFAULT_REGION"
S3_BUCKET_NAME="$S3_BUCKET_NAME"

# Azure Blob Configuration
AZURE_ACCOUNT_NAME="$AZURE_ACCOUNT_NAME"
AZURE_ACCOUNT_KEY="$AZURE_ACCOUNT_KEY"
AZURE_CONTAINER_NAME="$AZURE_CONTAINER_NAME"
EOL
chmod 600 "$BACKUP_CONFIG"

# Create backup script
cat << BACKUP_SCRIPT > "$BACKUP_SCRIPT_NAME"
#!/bin/bash

true
# T&M Hansson IT AB © - 2024, https://www.hanssonit.se/
# Sami Nieminen - 2024 https://nenimein.fi

# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Check if root
root_check

# Get database details
ncdb

# Ensure VMLOGS directory exists
if [ ! -d "$VMLOGS/restic" ]; then
    mkdir -p "$VMLOGS/restic"
fi

# Define log file
DATE=\$(date +%Y%m%d-%H%M%S)
BACKUP_LOG="$VMLOGS/restic/restic-backup_\${DATE}.log"

# Load configuration
source "$HOME/.restic_cloud_backup_config"

# Export environment variables based on backup type
case "$BACKUP_TYPE" in
    "Backblaze B2")
        export B2_ACCOUNT_ID="$B2_ACCOUNT_ID"
        export B2_ACCOUNT_KEY="$B2_ACCOUNT_KEY"
        ;;
    "AWS S3")
        export AWS_ACCESS_KEY_ID="$AWS_ACCESS_KEY_ID"
        export AWS_SECRET_ACCESS_KEY="$AWS_SECRET_ACCESS_KEY"
        export AWS_DEFAULT_REGION="$AWS_DEFAULT_REGION"
        ;;
    "Azure Blob")
        export AZURE_ACCOUNT_NAME="$AZURE_ACCOUNT_NAME"
        export AZURE_ACCOUNT_KEY="$AZURE_ACCOUNT_KEY"
        export AZURE_CONTAINER_NAME="$AZURE_CONTAINER_NAME"
        ;;
esac

export RESTIC_REPOSITORY="$RESTIC_REPOSITORY"
export RESTIC_PASSWORD="$RESTIC_PASSWORD"

# Start logging
{
    echo "\$(date '+%Y-%m-%d %H:%M:%S') Starting Restic backup script"
    echo "----------------------------------------"

    # Check if we have network connection
    if ! network_ok
    then
        echo "\$(date '+%Y-%m-%d %H:%M:%S') ERROR: No network connection"
        notify_admin_gui "Unable to execute Restic backup" "No network connection."
        exit 1
    fi

    # Load backup config
    if [ -f "$BACKUP_CONFIG" ]
    then
        echo "\$(date '+%Y-%m-%d %H:%M:%S') Loading Restic backup configuration"
        # shellcheck disable=SC1090
        source "$BACKUP_CONFIG"
    else
        echo "\$(date '+%Y-%m-%d %H:%M:%S') ERROR: Restic Backup configuration not found"
        notify_admin_gui "Unable to execute Restic backup" "Configuration file not found."
        exit 1
    fi

    # Create backup directory
    BACKUP_DIR="/tmp/nextcloud_backup"
    echo "\$(date '+%Y-%m-%d %H:%M:%S') Creating backup directory: \$BACKUP_DIR"
    mkdir -p "\$BACKUP_DIR"

    # Enable maintenance mode
    echo "\$(date '+%Y-%m-%d %H:%M:%S') Enabling maintenance mode"
    sudo -u www-data php /var/www/nextcloud/occ maintenance:mode --on

    # Backup PostgreSQL database
    echo "\$(date '+%Y-%m-%d %H:%M:%S') Backing up PostgreSQL database"
    if PGPASSWORD="\$NCDBPASS" pg_dump -U "\$NCDBUSER" -h "\$NCDBHOST" -d "\$NCDB" > "\$BACKUP_DIR/nextcloud_db.sql"; then
        echo "\$(date '+%Y-%m-%d %H:%M:%S') Database backup completed successfully"
    else
        echo "\$(date '+%Y-%m-%d %H:%M:%S') ERROR: Nextcloud database backup failed"
        sudo -u www-data php /var/www/nextcloud/occ maintenance:mode --off
        notify_admin_gui "Restic backup failed!" "Database backup failed."
        exit 1
    fi

    # Backup Nextcloud config
    echo "\$(date '+%Y-%m-%d %H:%M:%S') Backing up Nextcloud configuration"
    if cp /var/www/nextcloud/config/config.php "\$BACKUP_DIR/"; then
        echo "\$(date '+%Y-%m-%d %H:%M:%S') Nextcloud configuration backup completed successfully"
    else
        echo "\$(date '+%Y-%m-%d %H:%M:%S') ERROR: Nextcloud configuration backup failed"
        sudo -u www-data php /var/www/nextcloud/occ maintenance:mode --off
        notify_admin_gui "Restic backup failed!" "Nextcloud configuration backup failed."
        exit 1
    fi

    # Initialize repository if needed
    echo "\$(date '+%Y-%m-%d %H:%M:%S') Checking/Initializing repository"
    if ! restic snapshots; then
        echo "\$(date '+%Y-%m-%d %H:%M:%S') Initializing new repository"
        if ! restic init; then
            echo "\$(date '+%Y-%m-%d %H:%M:%S') ERROR: Restic repository initialization failed"
            sudo -u www-data php /var/www/nextcloud/occ maintenance:mode --off
            notify_admin_gui "Restic backup failed!" "Repository initialization failed."
            exit 1
        fi
    fi

    # Create backup based on scope
    if [ "$BACKUP_NCDATA" = "yes" ]
    then
        echo "\$(date '+%Y-%m-%d %H:%M:%S') Creating full backup including /mnt/ncdata"
        if ! restic backup "\$BACKUP_DIR" /mnt/ncdata --exclude-file="$RESTIC_EXCLUDES"; then
            echo "\$(date '+%Y-%m-%d %H:%M:%S') ERROR: Restic full backup failed"
            sudo -u www-data php /var/www/nextcloud/occ maintenance:mode --off
            notify_admin_gui "Restic backup failed!" "Full backup creation failed."
            exit 1
        fi
    else
        echo "\$(date '+%Y-%m-%d %H:%M:%S') Creating minimal backup (config and database only)"
        if ! restic backup "\$BACKUP_DIR"; then
            echo "\$(date '+%Y-%m-%d %H:%M:%S') ERROR: Restic minimal backup failed"
            sudo -u www-data php /var/www/nextcloud/occ maintenance:mode --off
            notify_admin_gui "Restic backup failed!" "Minimal backup creation failed."
            exit 1
        fi
    fi

    # Clean up backup directory
    echo "\$(date '+%Y-%m-%d %H:%M:%S') Cleaning up temporary backup directory"
    rm -rf "\$BACKUP_DIR"

    # Apply retention policy
    echo "\$(date '+%Y-%m-%d %H:%M:%S') Applying retention policy"
    if ! restic forget --keep-daily "$BACKUP_RETENTION_DAILY" \
                      --keep-weekly "$BACKUP_RETENTION_WEEKLY" \
                      --keep-monthly "$BACKUP_RETENTION_MONTHLY" --prune; then
        echo "\$(date '+%Y-%m-%d %H:%M:%S') WARNING: Failed to apply retention policy"
        notify_admin_gui \
            "Restic retention policy not applied!" \
            "The backup completed but repository retention policy failed.\nPlease check the logs at \$BACKUP_LOG"
        exit 1
    fi

    # Check repository
    echo "\$(date '+%Y-%m-%d %H:%M:%S') Checking repository integrity"
    if ! restic check; then
        echo "\$(date '+%Y-%m-%d %H:%M:%S') ERROR: Repository check failed"
        sudo -u www-data php /var/www/nextcloud/occ maintenance:mode --off
        notify_admin_gui \
            "Restic repository check failed!" \
            "The backup completed but repository integrity check failed.\nPlease check the logs at \$BACKUP_LOG"
        exit 1
    fi

    # Disable maintenance mode
    echo "\$(date '+%Y-%m-%d %H:%M:%S') Disabling maintenance mode"
    sudo -u www-data php /var/www/nextcloud/occ maintenance:mode --off

    echo "----------------------------------------"
    echo "\$(date '+%Y-%m-%d %H:%M:%S') Backup completed successfully"
    notify_admin_gui "Restic backup was successful." "Backup log available at: \$BACKUP_LOG"

} 2>&1 | tee -a "\$BACKUP_LOG"

# Check if any errors occurred in the pipeline
if [ \${PIPESTATUS[0]} -ne 0 ]; then
    notify_admin_gui "Restic backup failed!" "Please check the logs at \$BACKUP_LOG"
    exit 1
fi
BACKUP_SCRIPT

# Make backup script executable
chmod 700 "$BACKUP_SCRIPT_NAME"

# Create cron job
crontab -u root -l | grep -v "$BACKUP_SCRIPT_NAME" | crontab -u root -
crontab -u root -l | { cat; echo "$BACKUP_TIME * * * $BACKUP_SCRIPT_NAME > /dev/null 2>&1"; } | crontab -u root -

# Final message
msg_box "The backup script has been created successfully!
Location: $BACKUP_SCRIPT_NAME

The first backup will run automatically at $BACKUP_TIME.
Please make sure to keep your configuration, API keys and Restic password safe!"

exit 0
