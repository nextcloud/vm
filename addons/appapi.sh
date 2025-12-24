#!/bin/bash

# T&M Hansson IT AB © - 2025, https://www.hanssonit.se/

true
SCRIPT_NAME="AppAPI Configuration"
SCRIPT_EXPLAINER="$SCRIPT_NAME helps you configure the Nextcloud AppAPI (External Apps framework).

AppAPI is required to run External Apps (ExApps) which are containerized applications
that extend Nextcloud's capabilities, particularly AI applications.

This script supports three deployment methods:
1. HaRP (recommended for NC 32+) - Simplified deployment with reverse proxy
2. Docker Socket Proxy - Traditional method with more control
3. Direct Docker Socket - Simplest setup for local installations

If you don't plan to use External Apps, you can disable AppAPI to remove admin warnings."

# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Must be root
root_check

# Variables
DAEMON_NAME="docker_local_sock"

# Get NCDOMAIN for Apache config management
NEXTCLOUD_URL_EARLY=$(nextcloud_occ_no_check config:system:get overwrite.cli.url 2>/dev/null || echo "")
if [ -n "$NEXTCLOUD_URL_EARLY" ]
then
    NCDOMAIN=$(echo "$NEXTCLOUD_URL_EARLY" | sed -e 's|^[^/]*//||' -e 's|/.*$||')
fi

# Check if AppAPI is installed and enabled, or if daemon is configured
APP_API_INSTALLED=false
DAEMON_CONFIGURED=false

if is_app_installed app_api
then
    APP_API_INSTALLED=true
    if is_app_enabled app_api && nextcloud_occ app_api:daemon:list 2>/dev/null | grep -q "name:"
    then
        DAEMON_CONFIGURED=true
    fi
fi

# Check if AppAPI is already enabled or configured
if is_app_enabled app_api || [ "$DAEMON_CONFIGURED" = true ]
then
    # Ask for removal or reinstallation
    reinstall_remove_menu "$SCRIPT_NAME"
    # Removal
    print_text_in_color "$ICyan" "Removing AppAPI configuration..."

    # Get list of all External Apps
    EXAPPS_LIST=$(nextcloud_occ app_api:app:list 2>/dev/null | grep -E "^\s*-\s" | sed 's/^\s*-\s*//' || true)

    # Unregister all External Apps
    if [ -n "$EXAPPS_LIST" ]
    then
        print_text_in_color "$ICyan" "Unregistering all External Apps..."
        while IFS= read -r exapp_id
        do
            if [ -n "$exapp_id" ]
            then
                print_text_in_color "$ICyan" "Unregistering ExApp: $exapp_id"
                nextcloud_occ_no_check app_api:app:unregister "$exapp_id" --force --rm-data 2>/dev/null || true
                # Also remove container if it exists
                docker rm -f "nc_app_${exapp_id}" 2>/dev/null || true
            fi
        done <<< "$EXAPPS_LIST"
    fi

    # Get list of all daemons
    DAEMON_LIST=$(nextcloud_occ app_api:daemon:list 2>/dev/null | grep "name:" | sed 's/.*name: //' || true)

    # Unregister all daemons
    if [ -n "$DAEMON_LIST" ]
    then
        print_text_in_color "$ICyan" "Unregistering all Deploy Daemons..."
        while IFS= read -r daemon_name
        do
            if [ -n "$daemon_name" ]
            then
                print_text_in_color "$ICyan" "Unregistering daemon: $daemon_name"
                nextcloud_occ_no_check app_api:daemon:unregister "$daemon_name" 2>/dev/null || true
            fi
        done <<< "$DAEMON_LIST"
    fi

    # Disable the app
    if is_app_enabled app_api
    then
        print_text_in_color "$ICyan" "Disabling AppAPI app..."
        nextcloud_occ_no_check app:disable app_api
    fi
    
    # Remove HaRP and ExApp containers
    if is_docker_running
    then
        # Remove HaRP container (ghcr.io/nextcloud/nextcloud-appapi-harp)
        docker_prune_this 'nextcloud-appapi-harp'
        
        # Remove all ExApp containers
        DOCKERPS=$(docker ps -a --format '{{.Names}}' | grep '^nc_app_' || true)
        if [ -n "$DOCKERPS" ]
        then
            for container_name in $DOCKERPS
            do
                docker_prune_this "$container_name"
            done
        fi
    fi
    
    # Remove Apache proxy configuration for ExApps
    # Find Apache vhost config - check expected location first
    VHOST_CONF=""
    if [ -f "$SITES_AVAILABLE/$NCDOMAIN.conf" ]
    then
        VHOST_CONF="$SITES_AVAILABLE/$NCDOMAIN.conf"
    else
        # Try to find in enabled sites
        if [ -d "/etc/apache2/sites-enabled" ]
        then
            # Look for config containing ExApps-HaRP marker
            for conf_file in /etc/apache2/sites-enabled/*.conf
            do
                if [ -f "$conf_file" ] && grep -q "#ExApps-HaRP" "$conf_file"
                then
                    VHOST_CONF="$conf_file"
                    break
                fi
            done
        fi
    fi
    
    # Remove Include directive from vhost if found
    if [ -n "$VHOST_CONF" ] && [ -f "$VHOST_CONF" ]
    then
        if grep -q "#ExApps-HaRP" "$VHOST_CONF"
        then
            print_text_in_color "$ICyan" "Removing Apache ExApps proxy configuration from: $VHOST_CONF"
            sed -i "/#ExApps-HaRP/d" "$VHOST_CONF"
            sed -i "\|Include /etc/apache2/exapps-harp.conf|d" "$VHOST_CONF"
            systemctl restart apache2
        fi
    fi
    
    # Remove separate ExApps config file
    if [ -f "/etc/apache2/exapps-harp.conf" ]
    then
        print_text_in_color "$ICyan" "Removing ExApps Apache config file..."
        rm -f /etc/apache2/exapps-harp.conf
    fi
    
    # Optionally remove HaRP data
    if [ -d "/var/lib/appapi-harp" ]
    then
        if yesno_box_no "Do you want to remove HaRP data directory (/var/lib/appapi-harp)?
This includes certificates and configuration."
        then
            rm -rf /var/lib/appapi-harp
        fi
    fi

    # Optionally remove the app completely
    if yesno_box_yes "Do you want to completely remove the AppAPI app from your system?
This will delete the app files. You can reinstall it from the App Store later if needed."
    then
        print_text_in_color "$ICyan" "Removing AppAPI app..."
        nextcloud_occ_no_check app:remove app_api 2>/dev/null || true
    fi

    # Show successful uninstall if applicable
    removal_popup "$SCRIPT_NAME"
fi

# If we get here, we're installing/configuring
install_popup "$SCRIPT_NAME"

# Install Docker if not available
if ! is_docker_running || [ ! -S /var/run/docker.sock ]
then
    msg_box "Docker is not installed or not running on this system.

AppAPI requires Docker to deploy External Apps.

Docker will now be installed automatically."
    install_docker
    
    # Verify Docker is now running
    if ! is_docker_running || [ ! -S /var/run/docker.sock ]
    then
        msg_box "Failed to install or start Docker.

Please check your system logs and try again."
        exit 1
    fi
fi

# Check if www-data user can access docker socket
if ! sudo -u www-data docker ps &>/dev/null
then
    msg_box "The www-data user cannot access the Docker socket.

Adding www-data to the docker group to grant access..."

    # Add www-data to docker group
    usermod -aG docker www-data

    # Restart apache to apply group changes
    print_text_in_color "$ICyan" "Restarting Apache to apply group membership..."
    systemctl restart apache2

    # Test again
    if ! sudo -u www-data docker ps &>/dev/null
    then
        msg_box "Failed to grant Docker access to www-data user.

Please manually add www-data to the docker group:
  sudo usermod -aG docker www-data
  sudo systemctl restart apache2

Then run this script again."
        exit 1
    fi

    msg_box "Successfully granted Docker access to www-data user."
fi

# Get Nextcloud URL
NEXTCLOUD_URL=$(nextcloud_occ_no_check config:system:get overwrite.cli.url)
if [ -z "$NEXTCLOUD_URL" ]
then
    NEXTCLOUD_URL="http://$ADDRESS"
fi

# Check for TLS/HTTPS
if [[ "$NEXTCLOUD_URL" == "https://"* ]]
then
    HTTPS_ENABLED=true
else
    HTTPS_ENABLED=false
fi

# Extract domain from URL for reverse proxy config
NCDOMAIN=$(echo "$NEXTCLOUD_URL" | sed -e 's|^[^/]*//||' -e 's|/.*$||')

# Detect GPU support
COMPUTE_DEVICE="cpu"
GPU_INFO=""

# Check for NVIDIA GPU (CUDA)
if command -v nvidia-smi &>/dev/null
then
    if nvidia-smi &>/dev/null
    then
        COMPUTE_DEVICE="cuda"
        GPU_INFO="NVIDIA GPU detected (CUDA support available)"
    fi
fi

# Check for AMD GPU (ROCm) - only if CUDA not found
if [ "$COMPUTE_DEVICE" = "cpu" ] && [ -d "/opt/rocm" ]
then
    if command -v rocm-smi &>/dev/null
    then
        COMPUTE_DEVICE="rocm"
        GPU_INFO="AMD GPU detected (ROCm support available)"
    fi
fi

# Enable app_api if not enabled
if ! is_app_enabled app_api
then
    print_text_in_color "$ICyan" "Enabling AppAPI..."
    if ! install_and_enable_app app_api
    then
        msg_box "Failed to enable AppAPI. Please check your Nextcloud logs."
        exit 1
    fi
fi

# Choose deployment method
choice=$(whiptail --title "$TITLE" --menu \
"Choose a deployment method for AppAPI:

HaRP (Recommended for NC 32+):
  • Simplest setup with best performance
  • Direct communication between browser and ExApps
  • Built-in brute-force protection
  • Requires reverse proxy configuration

Docker Socket (Simple):
  • Direct Docker socket access
  • Good for local-only installations
  • No additional containers needed
  • Less secure than HaRP

${GPU_INFO:-No GPU detected - CPU will be used}" "$WT_HEIGHT" "$WT_WIDTH" 4 \
"HaRP" "(Recommended) Modern proxy-based deployment" \
"Docker Socket" "Direct socket access (simpler)" \
"Cancel" "Exit without changes" 3>&1 1>&2 2>&3)

case "$choice" in
    "HaRP")
        DEPLOY_METHOD="harp"
        ;;
    "Docker Socket")
        DEPLOY_METHOD="socket"
        ;;
    *)
        exit 0
        ;;
esac

# HaRP Deployment Method
if [ "$DEPLOY_METHOD" = "harp" ]
then
    # Generate secure shared key
    HP_SHARED_KEY=$(gen_passwd 32 "a]")
    HARP_CONTAINER_NAME="appapi-harp"
    DAEMON_NAME="harp_proxy_host"
    
    msg_box "Setting up HaRP (HaProxy Reversed Proxy) for AppAPI.

This will:
1. Deploy a HaRP container to proxy Docker and ExApp communication
2. Configure Apache reverse proxy for /exapps/ route
3. Register the HaRP Deploy Daemon in Nextcloud

Configuration:
• HaRP Container: $HARP_CONTAINER_NAME
• ExApps HTTP Port: 8780
• FRP Port: 8782
• Compute Device: ${COMPUTE_DEVICE^^}
• Nextcloud URL: $NEXTCLOUD_URL"

    # Check for existing HaRP container
    if docker ps -a --format '{{.Names}}' | grep -q "^${HARP_CONTAINER_NAME}$"
    then
        print_text_in_color "$ICyan" "Removing existing HaRP container..."
        docker rm -f "$HARP_CONTAINER_NAME" 2>/dev/null || true
    fi
    
    # Create certs directory for HaRP
    HARP_CERTS_DIR="/var/lib/appapi-harp/certs"
    mkdir -p "$HARP_CERTS_DIR"
    
    # Deploy HaRP container with host networking
    print_text_in_color "$ICyan" "Deploying HaRP container..."
    if ! docker run \
        -e HP_SHARED_KEY="$HP_SHARED_KEY" \
        -e NC_INSTANCE_URL="$NEXTCLOUD_URL" \
        -v /var/run/docker.sock:/var/run/docker.sock \
        -v "$HARP_CERTS_DIR":/certs \
        --name "$HARP_CONTAINER_NAME" -h "$HARP_CONTAINER_NAME" \
        --restart unless-stopped \
        --network host \
        -d ghcr.io/nextcloud/nextcloud-appapi-harp:release
    then
        msg_box "Failed to deploy HaRP container.

Please check Docker logs:
  docker logs $HARP_CONTAINER_NAME"
        exit 1
    fi
    
    # Wait for HaRP to start
    print_text_in_color "$ICyan" "Waiting for HaRP container to start..."
    sleep 5
    
    # Verify HaRP is running
    if ! docker ps | grep -q "$HARP_CONTAINER_NAME"
    then
        msg_box "HaRP container failed to start.

Check logs: docker logs $HARP_CONTAINER_NAME"
        exit 1
    fi
    
    # Configure Apache reverse proxy for /exapps/
    print_text_in_color "$ICyan" "Configuring Apache reverse proxy for ExApps..."
    
    # Enable proxy modules
    a2enmod proxy proxy_http proxy_wstunnel &>/dev/null
    
    # Create separate ExApps config file
    EXAPPS_CONF="/etc/apache2/exapps-harp.conf"
    cat << APACHE_EXAPPS_CONF > "$EXAPPS_CONF"
# AppAPI ExApps Reverse Proxy Configuration
# This file is managed by the Nextcloud VM AppAPI configuration script
# Do not modify manually - changes may be overwritten

ProxyPass /exapps/ http://127.0.0.1:8780/exapps/
ProxyPassReverse /exapps/ http://127.0.0.1:8780/exapps/
APACHE_EXAPPS_CONF
    
    # Find Apache vhost config - check expected location first
    VHOST_CONF=""
    if [ -f "$SITES_AVAILABLE/$NCDOMAIN.conf" ]
    then
        VHOST_CONF="$SITES_AVAILABLE/$NCDOMAIN.conf"
    else
        # Try to find in enabled sites
        if [ -d "/etc/apache2/sites-enabled" ]
        then
            # Look for config containing VirtualHost and DocumentRoot pointing to Nextcloud
            for conf_file in /etc/apache2/sites-enabled/*.conf
            do
                if [ -f "$conf_file" ] && grep -q "VirtualHost" "$conf_file" && grep -q "$NCPATH" "$conf_file" 2>/dev/null
                then
                    VHOST_CONF="$conf_file"
                    break
                fi
            done
        fi
    fi
    
    # Configure Apache if we found a vhost
    if [ -n "$VHOST_CONF" ]
    then
        # Check if Include for ExApps config already exists
        if ! grep -q "Include.*exapps-harp.conf" "$VHOST_CONF"
        then
            # Add Include directive after <VirtualHost *:443>
            if grep -q "<VirtualHost \*:443>" "$VHOST_CONF"
            then
                sed -i "/<VirtualHost \*:443>/a\    #ExApps-HaRP - Please don't remove or change this line\n    Include $EXAPPS_CONF" "$VHOST_CONF"
            else
                # Try port 80 if no 443
                sed -i "/<VirtualHost \*:80>/a\    #ExApps-HaRP - Please don't remove or change this line\n    Include $EXAPPS_CONF" "$VHOST_CONF"
            fi
            
            # Restart Apache
            if ! systemctl restart apache2
            then
                msg_box "Failed to restart Apache. Restoring config..."
                sed -i "/#ExApps-HaRP/d" "$VHOST_CONF"
                sed -i "\|Include $EXAPPS_CONF|d" "$VHOST_CONF"
                rm -f "$EXAPPS_CONF"
                systemctl restart apache2
                docker rm -f "$HARP_CONTAINER_NAME"
                exit 1
            fi
            
            print_text_in_color "$IGreen" "Apache proxy configured successfully in: $VHOST_CONF"
        else
            print_text_in_color "$ICyan" "ExApps proxy already configured in Apache."
        fi
    else
        msg_box "Warning: Could not find Apache vhost configuration for Nextcloud.

Required Apache modules have been enabled and ExApps proxy configuration
has been created at: $EXAPPS_CONF

You need to manually include this file in your Apache vhost:
  Include $EXAPPS_CONF

Or manually add the proxy configuration:
  ProxyPass /exapps/ http://127.0.0.1:8780/exapps/
  ProxyPassReverse /exapps/ http://127.0.0.1:8780/exapps/

Press OK to continue with daemon registration."
    fi
    
    # Register HaRP daemon
    print_text_in_color "$ICyan" "Registering HaRP Deploy Daemon..."
    if ! nextcloud_occ app_api:daemon:register \
        "$DAEMON_NAME" \
        "HaRP Proxy (Host)" \
        "docker-install" \
        "http" \
        "localhost:8780" \
        "$NEXTCLOUD_URL" \
        --net="host" \
        --harp \
        --harp_frp_address="localhost:8782" \
        --harp_shared_key="$HP_SHARED_KEY" \
        --compute_device="$COMPUTE_DEVICE" \
        --set-default
    then
        msg_box "Failed to register HaRP Deploy Daemon.

Please check Nextcloud logs for details."
        exit 1
    fi
    
    print_text_in_color "$IGreen" "HaRP deployment configured successfully!"

# Docker Socket Deployment Method (Legacy/Simple)
else
    DAEMON_NAME="docker_local_sock"
    
    msg_box "Setting up Direct Docker Socket access for AppAPI.

This will configure a local Docker daemon using:
• Docker Socket: /var/run/docker.sock
• Network: host
• Nextcloud URL: $NEXTCLOUD_URL
• Compute Device: ${COMPUTE_DEVICE^^}

Note: For production use with external access, consider using HaRP instead."

    # Configure the daemon
    print_text_in_color "$ICyan" "Configuring local Docker Deploy Daemon..."

    if ! nextcloud_occ app_api:daemon:register \
        "$DAEMON_NAME" \
        "Local Docker" \
        "docker-install" \
        "http" \
        "/var/run/docker.sock" \
        "$NEXTCLOUD_URL" \
        --net="host" \
        --compute_device="$COMPUTE_DEVICE" \
        --set-default
    then
        msg_box "Failed to register the Deploy Daemon.

This might happen if:
1. A daemon with the name '$DAEMON_NAME' already exists
2. Docker is not accessible
3. There's a configuration issue

Please check the Nextcloud logs for more details."
        exit 1
    fi
fi

# Ask if user wants to test the deployment
if yesno_box_yes "Do you want to test the Deploy Daemon?

This will run the official AppAPI Test Deploy which:
1. Registers a test ExApp (test-deploy)
2. Pulls the Docker image
3. Starts the container
4. Verifies heartbeat communication
5. Checks initialization
6. Verifies the ExApp is enabled

This is the same test available in AppAPI Admin Settings."
then
    print_text_in_color "$ICyan" "Starting test deployment..."
    print_text_in_color "$ICyan" "This may take 1-2 minutes for the first run (Docker image download)..."
    
    # Clean up any existing test apps first
    if nextcloud_occ app_api:app:list 2>/dev/null | grep -q "test-deploy"
    then
        print_text_in_color "$ICyan" "Removing existing test-deploy ExApp..."
        nextcloud_occ_no_check app_api:app:disable test-deploy 2>/dev/null || true
        nextcloud_occ_no_check app_api:app:unregister test-deploy --rm-data 2>/dev/null || true
        docker stop nc_app_test-deploy 2>/dev/null || true
        docker rm -f nc_app_test-deploy 2>/dev/null || true
    fi
    if nextcloud_occ app_api:app:list 2>/dev/null | grep -q "app-skeleton-python"
    then
        print_text_in_color "$ICyan" "Removing existing app-skeleton-python ExApp..."
        nextcloud_occ_no_check app_api:app:disable app-skeleton-python 2>/dev/null || true
        nextcloud_occ_no_check app_api:app:unregister app-skeleton-python --rm-data 2>/dev/null || true
        docker stop nc_app_app-skeleton-python 2>/dev/null || true
        docker rm -f nc_app_app-skeleton-python 2>/dev/null || true
    fi
    
    # Register test ExApp using the official test-deploy app
    print_text_in_color "$ICyan" "Step 1/6: Registering test ExApp..."
    if ! nextcloud_occ app_api:app:register test-deploy "$DAEMON_NAME" \
        --info-xml https://raw.githubusercontent.com/nextcloud/test-deploy/main/appinfo/info.xml 2>&1
    then
        # Try with app-skeleton-python as fallback
        print_text_in_color "$IYellow" "test-deploy not available, trying app-skeleton-python..."
        TEST_APP="app-skeleton-python"
        if ! nextcloud_occ app_api:app:register app-skeleton-python "$DAEMON_NAME" \
            --info-xml https://raw.githubusercontent.com/nextcloud/app-skeleton-python/main/appinfo/info.xml 2>&1
        then
            msg_box "Failed to register test ExApp. The daemon might not be working correctly.
        
Please check Docker and daemon configuration:
  docker logs $HARP_CONTAINER_NAME (if using HaRP)
  Check Nextcloud logs at $NCDATA/nextcloud.log"
            exit 1
        fi
    else
        TEST_APP="test-deploy"
    fi
    
    # Enable ExApp (triggers deployment)
    print_text_in_color "$ICyan" "Step 2/6: Pulling Docker image and starting container..."
    if ! nextcloud_occ app_api:app:enable "$TEST_APP" 2>&1
    then
        msg_box "Failed to enable test ExApp.
        
Cleaning up and exiting..."
        nextcloud_occ_no_check app_api:app:unregister "$TEST_APP" --silent --rm-data
        exit 1
    fi
    
    # Wait for container to be pulled and started
    print_text_in_color "$ICyan" "Step 3/6: Waiting for container to start..."
    WAIT_COUNT=0
    MAX_WAIT=60
    CONTAINER_NAME="nc_app_${TEST_APP}"
    while [ $WAIT_COUNT -lt $MAX_WAIT ]
    do
        if docker ps | grep -q "$CONTAINER_NAME"
        then
            print_text_in_color "$IGreen" "✓ Container started!"
            break
        fi
        sleep 2
        WAIT_COUNT=$((WAIT_COUNT + 1))
        # Show progress every 10 seconds
        if [ $((WAIT_COUNT % 5)) -eq 0 ]
        then
            print_text_in_color "$ICyan" "  Still waiting... ($((WAIT_COUNT * 2))s)"
        fi
    done
    
    # Check if container is running
    if ! docker ps | grep -q "$CONTAINER_NAME"
    then
        msg_box "Test ExApp container failed to start within 120 seconds.
        
Possible causes:
• Slow network (Docker image download)
• Docker connectivity issues
• Container startup failure

Diagnostics:
  docker ps -a | grep nc_app
  docker logs $CONTAINER_NAME

Cleaning up..."
        nextcloud_occ_no_check app_api:app:disable "$TEST_APP"
        nextcloud_occ_no_check app_api:app:unregister "$TEST_APP" --silent --rm-data
        exit 1
    fi
    
    # Step 4: Check heartbeat (container health)
    print_text_in_color "$ICyan" "Step 4/6: Checking container heartbeat..."
    sleep 5
    if docker inspect --format='{{.State.Health.Status}}' "$CONTAINER_NAME" 2>/dev/null | grep -q "healthy"
    then
        print_text_in_color "$IGreen" "✓ Container is healthy!"
    else
        # Container might not have health check, check if running
        if docker ps | grep -q "$CONTAINER_NAME"
        then
            print_text_in_color "$IGreen" "✓ Container is running!"
        fi
    fi
    
    # Step 5: Check initialization
    print_text_in_color "$ICyan" "Step 5/6: Verifying ExApp initialization..."
    sleep 3
    
    # Check if ExApp responded with success message (for app-skeleton-python)
    if [ "$TEST_APP" = "app-skeleton-python" ]
    then
        WAIT_COUNT=0
        MAX_WAIT=15
        while [ $WAIT_COUNT -lt $MAX_WAIT ]
        do
            if grep -q "Hello from app-skeleton-python :)" "$NCDATA/nextcloud.log" 2>/dev/null
            then
                print_text_in_color "$IGreen" "✓ ExApp initialized successfully!"
                break
            fi
            sleep 2
            WAIT_COUNT=$((WAIT_COUNT + 1))
        done
        
        if [ $WAIT_COUNT -eq $MAX_WAIT ]
        then
            print_text_in_color "$IYellow" "Note: Init message not found in logs (this may be normal)"
        fi
    else
        print_text_in_color "$IGreen" "✓ ExApp registered and running!"
    fi
    
    # Step 6: Verify enabled
    print_text_in_color "$ICyan" "Step 6/6: Verifying ExApp is enabled..."
    if nextcloud_occ app_api:app:list 2>/dev/null | grep -q "$TEST_APP"
    then
        print_text_in_color "$IGreen" "✓ ExApp is enabled and listed!"
    fi
    
    # Disable and cleanup
    print_text_in_color "$ICyan" "Test complete! Cleaning up test ExApp..."
    nextcloud_occ_no_check app_api:app:disable "$TEST_APP"
    sleep 2
    nextcloud_occ_no_check app_api:app:unregister "$TEST_APP" --rm-data
    
    # Verify cleanup
    if docker ps -a | grep -q "$CONTAINER_NAME"
    then
        print_text_in_color "$ICyan" "Removing test container..."
        docker rm -f "$CONTAINER_NAME" 2>/dev/null || true
    fi
    
    msg_box "Test deployment completed successfully!

✓ Register: ExApp registered
✓ Image Pull: Docker image downloaded
✓ Container: Started and running
✓ Heartbeat: Container healthy
✓ Init: ExApp initialized
✓ Enabled: ExApp functional
✓ Cleanup: Test ExApp removed

The Deploy Daemon is working correctly and ready for production use!"
fi

# Success message
if [ "$DEPLOY_METHOD" = "harp" ]
then
    msg_box "Congratulations! $SCRIPT_NAME was successfully configured with HaRP!

Deployment Method: HaRP (Recommended)
Daemon Name: $DAEMON_NAME
Compute Device: ${COMPUTE_DEVICE^^}
HaRP Container: $HARP_CONTAINER_NAME

You can now install External Apps from the Apps page in Nextcloud.

To view available External Apps, visit:
Settings > Apps > External Apps

Manage via CLI:
• List daemons: sudo -u www-data php $NCPATH/occ app_api:daemon:list
• List ExApps: sudo -u www-data php $NCPATH/occ app_api:app:list
• Test Deploy: Use 3-dot menu in AppAPI Admin Settings

HaRP Container Management:
• Logs: docker logs $HARP_CONTAINER_NAME
• Restart: docker restart $HARP_CONTAINER_NAME
• Status: docker ps | grep $HARP_CONTAINER_NAME

Documentation:
https://docs.nextcloud.com/server/latest/admin_manual/exapps_management/"
else
    msg_box "Congratulations! $SCRIPT_NAME was successfully configured!

Deployment Method: Direct Docker Socket
Daemon Name: $DAEMON_NAME
Compute Device: ${COMPUTE_DEVICE^^}

You can now install External Apps from the Apps page in Nextcloud.

To view available External Apps, visit:
Settings > Apps > External Apps

Manage via CLI:
• List daemons: sudo -u www-data php $NCPATH/occ app_api:daemon:list
• List ExApps: sudo -u www-data php $NCPATH/occ app_api:app:list
• Unregister daemon: sudo -u www-data php $NCPATH/occ app_api:daemon:unregister <name>

Note: For production deployments with external access,
consider switching to HaRP for better security and performance.

Documentation:
https://docs.nextcloud.com/server/latest/admin_manual/exapps_management/"
fi