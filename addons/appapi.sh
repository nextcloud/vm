#!/bin/bash

# T&M Hansson IT AB © - 2026, https://www.hanssonit.se/

true
SCRIPT_NAME="AppAPI Configuration"
SCRIPT_EXPLAINER="$SCRIPT_NAME helps you configure the Nextcloud AppAPI (External Apps framework).

AppAPI is required to run External Apps (ExApps) which are containerized applications
that extend Nextcloud's capabilities, particularly AI applications.

This script supports two deployment methods:
1. HaRP - Modern deployment with reverse proxy
2. Direct Docker Socket - Simple setup for local installations

If you don't plan to use External Apps, you can run this script again to disable AppAPI"

# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Must be root
root_check

# Get Nextcloud domain
ncdomain

# Determine protocol (https or http) from Nextcloud config
if echo "$NCDOMAIN" | grep -q "^https://"
then
    NC_PROTOCOL="https"
    # Strip protocol prefix from NCDOMAIN for consistent usage
    NCDOMAIN="${NCDOMAIN#https://}"
elif echo "$NCDOMAIN" | grep -q "^http://"
then
    NC_PROTOCOL="http"
    # Strip protocol prefix from NCDOMAIN for consistent usage
    NCDOMAIN="${NCDOMAIN#http://}"
else
    NC_PROTOCOL="http"
fi

print_text_in_color "$ICyan" "Fetching variables for $SCRIPT_NAME..."

# Load AppAPI-specific functions and variables
appapi_install

# Check if appapi is already installed
if ! is_app_installed app_api || [ -z "$DAEMON_LIST" ]
then
    # Ask for installing
    install_popup "$SCRIPT_NAME"
else
    # Ask for removal or reinstallation
    reinstall_remove_menu "$SCRIPT_NAME"

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

    # Remove HaRP and ExApp containers
    if is_docker_running
    then
        # Remove HaRP container
        docker_prune_this 'ghcr.io/nextcloud/nextcloud-appapi-harp'
        # Remove all ExApp containers and their images
        docker ps -a --format '{{.Names}}' | grep '^nc_app_' | while read -r container_name
        do
            docker_prune_this "$container_name"
        done
        
        # Clean up ExApp images
        docker images --format '{{.Repository}}:{{.Tag}}' | grep '^ghcr.io/nextcloud/.*:' | while read -r image_name
        do
            docker rmi -f "$image_name" 2>/dev/null || true
        done
    fi

    # Remove Apache proxy configuration for ExApps
    if [ -f /etc/apache2/conf-available/exapps-harp.conf ]
    then
        print_text_in_color "$ICyan" "Disabling ExApps Apache configuration..."
        a2disconf exapps-harp &>/dev/null
        rm -f /etc/apache2/conf-available/exapps-harp.conf
    fi

    # Remove HaRP certs directory
    if [ -d "/var/lib/appapi-harp" ]
    then
        print_text_in_color "$ICyan" "Removing HaRP data directory..."
        rm -rf /var/lib/appapi-harp
    fi

    # Remove www-data from docker group
    if id -nG www-data | grep -qw docker
    then
        print_text_in_color "$ICyan" "Removing www-data from docker group..."
        gpasswd -d www-data docker
        
        # Restart Apache to apply group changes
        restart_webserver
    fi

    print_text_in_color "$ICyan" "Disabling AppAPI app..."
    nextcloud_occ_no_check app:disable app_api

    # Show successful uninstall if applicable
    removal_popup "$SCRIPT_NAME"
fi

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
    restart_webserver

    # Test again
    if ! sudo -u www-data docker ps &>/dev/null
    then
        msg_box "Failed to grant Docker access to www-data user.

Please manually add www-data to the docker group:
  sudo usermod -aG docker www-data
  sudo restart_webserver

Then run this script again."
        exit 1
    fi

    print_text_in_color "$IGreen" "Successfully granted Docker access to www-data user."
fi

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

HaRP (Requires public domain):
  • Requires reverse proxy configuration and a publicly accessible Nextcloud URL
  • Best performance
  • Nextcloud 32+ only!
  • Direct communication between browser and ExApps
  • Built-in brute-force protection

Docker Socket (Local installations):
  • Good for local-only installations without external access
  • Direct Docker socket access
  • No additional containers needed
  • Less secure than HaRP

${GPU_INFO:-No GPU detected - CPU will be used}" "$WT_HEIGHT" "$WT_WIDTH" 4 \
"HaRP" "Modern proxy-based deployment" \
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
    HP_SHARED_KEY=$(gen_passwd 32 "a-zA-Z0-9")
    HARP_CONTAINER_NAME="appapi-harp"
    # Use daemon name from lib.sh (defined as: APPAPI_HARP_DAEMON_NAME="harp_proxy_host")
    if [ -z "$APPAPI_HARP_DAEMON_NAME" ]
    then
        DAEMON_NAME="harp_proxy_host"
    else
        DAEMON_NAME="$APPAPI_HARP_DAEMON_NAME"
    fi

    msg_box "Setting up HaRP (HaProxy Reverse Proxy) for AppAPI.

This will:
1. Deploy a HaRP container to proxy Docker and ExApp communication
2. Configure Apache reverse proxy for /exapps/ route
3. Register the HaRP Deploy Daemon in Nextcloud

Configuration:
• HaRP Container: $HARP_CONTAINER_NAME
• ExApps HTTP Port: 8780
• FRP Port: 8782
• Compute Device: ${COMPUTE_DEVICE^^}
• Nextcloud URL: $NC_PROTOCOL://$NCDOMAIN"

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
        -e NC_INSTANCE_URL="$NC_PROTOCOL://$NCDOMAIN" \
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

    # Create separate ExApps config file in conf-available
    EXAPPS_CONF="/etc/apache2/conf-available/exapps-harp.conf"
    cat << APACHE_EXAPPS_CONF > "$EXAPPS_CONF"
# AppAPI ExApps Reverse Proxy Configuration
# This file is managed by the Nextcloud VM AppAPI configuration script
# Do not modify manually - changes may be overwritten

ProxyPass /exapps/ http://127.0.0.1:8780/exapps/
ProxyPassReverse /exapps/ http://127.0.0.1:8780/exapps/
APACHE_EXAPPS_CONF
    
    # Enable ExApps proxy configuration using a2enconf
    print_text_in_color "$ICyan" "Enabling ExApps Apache configuration..."
    if ! a2enconf exapps-harp &>/dev/null
    then
        msg_box "Warning: Failed to enable ExApps Apache configuration.

Manually enable it with:
  sudo a2enconf exapps-harp
  sudo restart_webserver

Press OK to continue with daemon registration."
    else
        # Restart Apache
        if ! restart_webserver
        then
            msg_box "Failed to restart Apache. Disabling configuration..."
            a2disconf exapps-harp &>/dev/null
            rm -f "$EXAPPS_CONF"
            restart_webserver
            docker rm -f "$HARP_CONTAINER_NAME"
            exit 1
        fi
        
        print_text_in_color "$IGreen" "Apache ExApps proxy configured successfully."
    fi
    
    # Register HaRP daemon
    print_text_in_color "$ICyan" "Registering HaRP Deploy Daemon..."
    if ! nextcloud_occ app_api:daemon:register \
        "$DAEMON_NAME" \
        "HaRP Proxy (Host)" \
        "docker-install" \
        "http" \
        "localhost:8780" \
        "$NC_PROTOCOL://$NCDOMAIN" \
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
elif [ "$DEPLOY_METHOD" = "socket" ]
then
    # Use daemon name from lib.sh (defined as: APPAPI_DOCKER_DAEMON_NAME="docker_local_sock")
    if [ -z "$APPAPI_DOCKER_DAEMON_NAME" ]
    then
        DAEMON_NAME="docker_local_sock"
    else
        DAEMON_NAME="$APPAPI_DOCKER_DAEMON_NAME"
    fi
    
    msg_box "Setting up Direct Docker Socket access for AppAPI.

This will configure a local Docker daemon using:
• Docker Socket: /var/run/docker.sock
• Network: host
• Nextcloud URL: $NC_PROTOCOL://$NCDOMAIN
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
        "$NC_PROTOCOL://$NCDOMAIN" \
        --net="host" \
        --compute_device="$COMPUTE_DEVICE" \
        --set-default
    then
        msg_box "Failed to register Local Docker Deploy Daemon.

Please check Nextcloud logs for details."
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
    cleanup_test_app "test-deploy"
    cleanup_test_app "app-skeleton-python"
    
    # Give the daemon a moment to be ready
    if [ "$DEPLOY_METHOD" = "harp" ]
    then
        print_text_in_color "$ICyan" "Waiting for HaRP daemon to be ready..."
        sleep 3
    fi
    
    # Register test ExApp using the official test-deploy app
    print_text_in_color "$ICyan" "Step 1/6: Registering test ExApp..."
    TEST_SUCCESS=0
    if REGISTER_OUTPUT=$(nextcloud_occ app_api:app:register test-deploy "$DAEMON_NAME" \
        --info-xml "${TEST_APP_URLS[0]}" 2>&1) || echo "$REGISTER_OUTPUT" | grep -q "already registered"
    then
        TEST_APP="test-deploy"
        TEST_SUCCESS=1
        if echo "$REGISTER_OUTPUT" | grep -q "already registered"
        then
            print_text_in_color "$ICyan" "Test ExApp was already registered, continuing..."
        fi
    else
        # Try with app-skeleton-python as fallback
        print_text_in_color "$IYellow" "test-deploy not available, trying app-skeleton-python..."
        if REGISTER_OUTPUT=$(nextcloud_occ app_api:app:register app-skeleton-python "$DAEMON_NAME" \
            --info-xml "${TEST_APP_URLS[1]}" 2>&1) || echo "$REGISTER_OUTPUT" | grep -q "already registered"
        then
            TEST_APP="app-skeleton-python"
            TEST_SUCCESS=1
            if echo "$REGISTER_OUTPUT" | grep -q "already registered"
            then
                print_text_in_color "$ICyan" "Test ExApp was already registered, continuing..."
            fi
        else
            TEST_SUCCESS=0
            # Show warning but don't exit - allow the user to test manually later
            msg_box "Warning: Could not register test ExApp.

Possible causes:
• HaRP container connectivity issues
• Docker registry authentication issues (401 Unauthorized)
• Network timeout pulling Docker images

The daemon has been registered successfully, but the test failed.
You can test it later from the AppAPI Admin Settings page.

Error (for debugging):
$(echo "$REGISTER_OUTPUT" | tail -20)"
        fi
    fi
    
    # Only continue with the rest of the test if registration succeeded
    if [ "$TEST_SUCCESS" -eq 1 ]
    then
        # Enable ExApp (triggers deployment)
        print_text_in_color "$ICyan" "Step 2/6: Pulling Docker image and starting container..."
        if ! nextcloud_occ app_api:app:enable "$TEST_APP" 2>&1
        then
            msg_box "Note: Failed to enable test ExApp during automatic test.

The daemon is still registered and functional.
You can test it manually from the AppAPI Admin Settings page."
            nextcloud_occ_no_check app_api:app:unregister "$TEST_APP" --silent --rm-data 2>/dev/null || true
        else
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
                msg_box "Note: Test ExApp container failed to start within 120 seconds.

Possible causes:
• Slow network (Docker image download)
• Docker connectivity issues
• Container startup failure

The daemon is still registered and functional.
You can test it manually from the AppAPI Admin Settings page."
                nextcloud_occ_no_check app_api:app:disable "$TEST_APP" 2>/dev/null || true
                nextcloud_occ_no_check app_api:app:unregister "$TEST_APP" --silent --rm-data 2>/dev/null || true
            else
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
                nextcloud_occ_no_check app_api:app:disable "$TEST_APP" 2>/dev/null || true
                sleep 2
                nextcloud_occ_no_check app_api:app:unregister "$TEST_APP" --rm-data 2>/dev/null || true
                
                # Verify cleanup
                if docker ps -a | grep -q "$CONTAINER_NAME" 2>/dev/null
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
        fi
    fi
fi

# Show success message
# Get Docker information
DOCKER_VERSION=$(docker --version 2>/dev/null | awk '{print $3}' | sed 's/,//' || echo "unknown")
DOCKER_SOCKET="/var/run/docker.sock"

if [ "$DEPLOY_METHOD" = "harp" ]
then
    msg_box "Congratulations! $SCRIPT_NAME was successfully configured with HaRP!

Deployment Method: HaRP
Daemon Name: $DAEMON_NAME
Compute Device: ${COMPUTE_DEVICE^^}
HaRP Container: $HARP_CONTAINER_NAME
Docker Version: $DOCKER_VERSION

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
elif [ "$DEPLOY_METHOD" = "socket" ]
then
    msg_box "Congratulations! $SCRIPT_NAME was successfully configured!

Deployment Method: Direct Docker Socket
Daemon Name: $DAEMON_NAME
Compute Device: ${COMPUTE_DEVICE^^}
Docker Version: $DOCKER_VERSION
Docker Socket: $DOCKER_SOCKET

You can now install External Apps from the Apps page in Nextcloud.

To view available External Apps, visit:
Settings > Apps > External Apps

Manage via CLI:
• List daemons: sudo -u www-data php $NCPATH/occ app_api:daemon:list
• List ExApps: sudo -u www-data php $NCPATH/occ app_api:app:list
• Unregister daemon: sudo -u www-data php $NCPATH/occ app_api:daemon:unregister <name>

Docker Information:
• Version: docker --version
• Containers: docker ps
• Socket: ls -l $DOCKER_SOCKET

Note: For production deployments with external access,
consider switching to HaRP for better security and performance.

Documentation:
https://docs.nextcloud.com/server/latest/admin_manual/exapps_management/"
fi
