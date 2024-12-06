#!/bin/bash

# T&M Hansson IT AB © - 2024, https://www.hanssonit.se/
# Sami Nieminen - 2024 https://nenimein.fi
true

SCRIPT_NAME="Nextcloud Restic cloud backup wizard"
SCRIPT_EXPLAINER="This script helps creating a backup script for your Nextcloud instance to various cloud storage providers.\nIt uses Restic and backs up your configuration and database."

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

# Variables
BACKUP_SCRIPT_NAME="$SCRIPTS/restic-cloud-backup.sh"
BACKUP_CONFIG="$HOME/.restic_cloud_backup_config"

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
            AZURE_ACCOUNT_NAME=$(input_box_flow "Enter Azure Storage Account Name:")
            AZURE_ACCOUNT_KEY=$(input_box_flow "Enter Azure Storage Account Key:")
            AZURE_CONTAINER_NAME=$(input_box_flow "Enter Azure Container Name:")
            RESTIC_REPOSITORY="azure:${AZURE_CONTAINER_NAME}:"
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

# Ask for execution
msg_box "$SCRIPT_EXPLAINER"
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
if ! command -v restic &> /dev/null
then
    msg_box "Press ok to install Restic"
    apt-get update -q4 & spinner_loading
    apt-get install restic -y
fi

# Configure PostgreSQL credentials
POSTGRES_DB=$NCDB
POSTGRES_USER=$NCDBUSER
POSTGRES_PASSWORD=$NCDBPASS
POSTGRES_HOST=$NCDBHOST

# Configure backup destination
choose_backup_location

# Choose backup scope
choose_backup_scope

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
POSTGRES_DB="$POSTGRES_DB"
POSTGRES_USER="$POSTGRES_USER"
POSTGRES_PASSWORD="$POSTGRES_PASSWORD"
POSTGRES_HOST="$POSTGRES_HOST"
BACKUP_TYPE="$BACKUP_TYPE"
BACKUP_SCOPE="$BACKUP_SCOPE"
BACKUP_NCDATA="$BACKUP_NCDATA"
RESTIC_PASSWORD="$RESTIC_PASSWORD"
RESTIC_REPOSITORY="$RESTIC_REPOSITORY"
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
cat << 'BACKUP_SCRIPT' > "$BACKUP_SCRIPT_NAME"
#!/bin/bash

# T&M Hansson IT AB © - 2024, https://www.hanssonit.se/
# Sami Nieminen - 2024 https://nenimein.fi
true

SCRIPT_NAME="Daily Restic Backup"
SCRIPT_EXPLAINER="This script executes the daily backup to cloud storage."

# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh

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
        ;;
esac

export RESTIC_REPOSITORY="$RESTIC_REPOSITORY"
export RESTIC_PASSWORD="$RESTIC_PASSWORD"

# Execute backup if network is available
if network_ok
then
    # Enable maintenance mode
    sudo -u www-data php /var/www/nextcloud/occ maintenance:mode --on

    # Create backup directory
    BACKUP_DIR="/tmp/nextcloud_backup"
    mkdir -p "$BACKUP_DIR"

    # Backup PostgreSQL database
    PGPASSWORD="$POSTGRES_PASSWORD" pg_dump -U "$POSTGRES_USER" -h "$POSTGRES_HOST" -d "$POSTGRES_DB" > "$BACKUP_DIR/nextcloud_db.sql"

    # Backup Nextcloud config
    cp /var/www/nextcloud/config/config.php "$BACKUP_DIR/"

    # Initialize repository if needed
    restic snapshots || restic init

    # Create backup based on scope
    if [ "$BACKUP_NCDATA" = "yes" ]
    then
        print_text_in_color "$ICyan" "Creating full backup including /mnt/ncdata..."
        restic backup "$BACKUP_DIR" /mnt/ncdata
    else
        print_text_in_color "$ICyan" "Creating minimal backup (config and database only)..."
        restic backup "$BACKUP_DIR"
    fi

    # Clean up
    rm -rf "$BACKUP_DIR"

    # Apply retention policy
    restic forget --keep-daily "$BACKUP_RETENTION_DAILY" \
                  --keep-weekly "$BACKUP_RETENTION_WEEKLY" \
                  --keep-monthly "$BACKUP_RETENTION_MONTHLY" --prune

    # Check repository
    restic check

    # Disable maintenance mode
    sudo -u www-data php /var/www/nextcloud/occ maintenance:mode --off

    # Notify on success
    if [ $? -eq 0 ]
    then
        notify_admin_gui "Restic backup was successfull."
    else
        notify_admin_gui "Restic backup failed!" "Please check the logs for more information."
    fi
else
    notify_admin_gui "Unable to execute backup" "No network connection."
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
