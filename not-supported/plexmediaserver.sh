#!/bin/bash

# T&M Hansson IT AB © - 2024, https://www.hanssonit.se/
# Copyright © 2021 Simon Lindner (https://github.com/szaimen)

true
SCRIPT_NAME="PLEX Media Server"
SCRIPT_EXPLAINER="PLEX Media Server is a server application that let's \
you enjoy all your photos, music, videos, and movies in one place."
# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Check if root
root_check

# Check if already installed
if is_this_installed plexmediaserver
then
    msg_box "It seems like PLEX Media Server is already installed.

If you want to delete PLEX Media Server and it's data to be able \
to start from scratch, run the following two commands:
'sudo apt-get purge plexmediaserver'
'sudo deluser plex'

Attention! This will delete the user-data:
'sudo rm -r /var/lib/plexmediaserver'"
    exit 1
fi
if is_docker_running && docker ps -a --format "{{.Names}}" | grep -q "^plex$"
then
    msg_box "It seems like PLEX Media Server is already installed.

If you want to delete PLEX Media Server and it's data to be able \
to start from scratch, run the following two commands:
'sudo docker stop plex'
'sudo docker rm plex'

Attention! This will delete the user-data:
'sudo rm -r /home/plex'"
    exit 1
fi

# Ask for installing
install_popup "$SCRIPT_NAME"

# Test Hardware transcoding
DRI_DEVICE=(--device=/dev/dri:/dev/dri -d)
if lspci -v -s "$(lspci | grep VGA | cut -d" " -f 1)" | grep -q "Kernel driver in use: i915"
then
    msg_box "Hardware transcoding is available. It is recommended to activate this in Plex later \
but requires a Plex Pass. You can learn more about Plex Pass here: 'www.plex.tv/plex-pass'"
else
    msg_box "Hardware transcoding is NOT available. It is not recommended to continue."
    if ! yesno_box_no "Do you want to continue nonetheless?"
    then
        exit 1
    fi
    # -d is here since the docker run command would fail if DRI_DEVICE is empty
    DRI_DEVICE=(-d)
fi

# Find mounts
DIRECTORIES=$(find /mnt/ -mindepth 1 -maxdepth 2 -type d | grep -v "/mnt/ncdata")
mapfile -t DIRECTORIES <<< "$DIRECTORIES"
for directory in "${DIRECTORIES[@]}"
do
    # Open directory to make sure that it is accessible
    ls "$directory" &>/dev/null

    # Continue with the logic
    if mountpoint -q "$directory" && [ "$(stat -c '%a' "$directory")" = "770" ]
    then
        if [ "$(stat -c '%U' "$directory")" = "www-data" ] && [ "$(stat -c '%G' "$directory")" = "www-data" ]
        then
            MOUNTS+=(-v "$directory:$directory:ro")
        elif [ "$(stat -c '%U' "$directory")" = "plex" ] && [ "$(stat -c '%G' "$directory")" = "plex" ]
        then
            MOUNTS+=(-v "$directory:$directory:ro")
        fi
    fi
done
if [ -z "${MOUNTS[*]}" ]
then
    msg_box "No usable drive found. You have to mount a new drive in /mnt."
    exit 1
fi

# Install Docker
install_docker

# Create plex user
if ! id plex &>/dev/null
then
    check_command adduser --no-create-home --quiet --disabled-login --uid 1005 --gid 1006 --force-badname --gecos "" "plex"
fi

PLEX_UID="$(id -u plex)"
PLEX_GID="$(id -g www-data)"

# Create home directory
mkdir -p /home/plex/config
mkdir -p /home/plex/transcode
chown -R plex:plex /home/plex
chmod -R 770 /home/plex

# Get docker container
print_text_in_color "$ICyan" "Getting Plex Media Server..."
docker pull plexinc/pms-docker

# Create Plex
# Plex needs ports: 32400/tcp 3005/tcp 8324/tcp 32469/tcp 1900/udp 32410/udp 32412/udp 32413/udp 32414/udp
print_text_in_color "$ICyan" "Installing Plex Media Server..."
docker run \
--name plex \
--restart always \
--network=host \
-e PLEX_UID="$PLEX_UID" \
-e PLEX_GID="$PLEX_GID" \
-v /etc/timezone:/etc/timezone:ro \
-v /etc/localtime:/etc/localtime:ro \
-v /home/plex/config:/config \
-v /home/plex/transcode:/transcode \
"${MOUNTS[@]}" \
"${DRI_DEVICE[@]}" \
plexinc/pms-docker

# Add prune command
add_dockerprune

# Crontab entry no longer needed
crontab -u root -l | grep -v "docker restart plex"  | crontab -u root -

# Add firewall rules
for port in 32400/tcp 3005/tcp 8324/tcp 32469/tcp 1900/udp 32410/udp 32412/udp 32413/udp 32414/udp
do
    ufw allow "$port" comment "Plex $port" &>/dev/null
done

# Inform the user
msg_box "PLEX Media Server was successfully installed.
This script is not at the end yet so please continue."

# Ask if external acces shall get activated
if yesno_box_yes "Do you want to enable access for PLEX from outside of your LAN?"
then
    msg_box "You will have to open port 32400 TCP to make this work.
You will have the option to automatically open this port by using UPNP in the next step."
    if yesno_box_no "Do you want to use UPNP to open port 32400 TCP?"
    then
        unset FAIL
        open_port 32400 TCP
        cleanup_open_port
    fi
    msg_box "After you hit okay, we will check if port 32400 TCP is open."
    check_open_port 32400 "$WANIP4"
fi

msg_box "You should visit 'http://$ADDRESS:32400/web' to set up your PLEX Media Server next.
Advice: All your drives should be mounted in a subfolder of '/mnt'"

exit
