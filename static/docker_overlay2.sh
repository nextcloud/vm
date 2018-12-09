#!/bin/bash
# shellcheck disable=2034,2059
true
# shellcheck source=lib.sh
DOCKEROVERLAY2=1 . <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)
unset DOCKEROVERLAY2

# T&M Hansson IT AB © - 2018, https://www.hanssonit.se/

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

### Migrating Docker images to overlay2 ###
# https://www.techandme.se/changes-to-docker-ce-in-the-nextcloud-vm/
# Credits to: https://gist.github.com/hydra1983/22b2bed38b4f5f56caa87c830c96378d

# Check if aufs and don't run
if grep -q "aufs" /etc/default/docker
then
msg_box "This script doesn't support images that uses the AUFS driver, sorry

You are welcome to send a PR, or report an issue here: $ISSUES"
    exit 1
fi

readonly DB_FILE="$DOCKERBACKUP/images.db"
readonly IMG_DIR="$DOCKERBACKUP/images"

save_images() {
  echo "Create ${IMG_DIR}"
  if [[ ! -d "${IMG_DIR}" ]]; then
    mkdir "${IMG_DIR}"
  fi
  
  echo "Create ${DB_FILE}"
  docker images|grep -v 'IMAGE ID'|awk '{printf("%s %s %s\n", $1, $2, $3)}'|column -t > "${DB_FILE}"
  
  echo "Read ${DB_FILE}"
  local images
  while read -r image; do
     images+=("$image"); 
  done <<< "$(cat "${DB_FILE}")"
  
  local name tag id
  for image in "${images[@]}"; do
    name=$(echo "$image"|awk '{print $1}')
    tag=$(echo "$image"|awk '{print $2}')
    id=$(echo "$image"|awk '{print $3}')
        
    if [[ "${id}" != "" ]]; then
      local imgPath="${IMG_DIR}/${id}.dim"

      if [[ ! -f "${imgPath}" ]] ; then
        echo "[DEBUG] save ${id} ${name}:${tag} to ${imgPath}"
        (time  docker save -o "${imgPath}" "${name}":"${tag}") 2>&1 | grep real
      else
        echo "[DEBUG] ${id} ${name}:${tag} already saved"
      fi
    fi    
  done
}

load_images() {
  if [[ ! -f "${DB_FILE}" ]]; then
    echo "No ${DB_FILE} to read"
    exit 0
  fi

  if [[ ! -d "${IMG_DIR}" ]]; then
    echo "No ${IMG_DIR} to load images"
    exit 0
  fi

  echo "Read ${DB_FILE}"
  local images
  while read -r image; do
     images+=("$image"); 
  done <<< "$(cat "${DB_FILE}")"

  local name tag id
  for image in "${images[@]}"; do
    name=$(echo "$image"|awk '{print $1}')
    tag=$(echo "$image"|awk '{print $2}')
    id=$(echo "$image"|awk '{print $3}')
        
    if [[ "${id}" != "" ]]; then
      local imgPath="${IMG_DIR}/${id}.dim"

      if [[ "$(docker images|grep "${id}" | grep "${name}" | grep "${tag}")" == "" ]]; then        
        if [[ "$(docker images|grep "${id}")" == "" ]]; then
          echo "[DEBUG] load ${id} ${name}:${tag} from ${imgPath}"
          docker load -i "${imgPath}"
        else
          echo "[DEBUG] tag ${id} as ${name}:${tag}"
          docker tag "${id}" "${name}":"${tag}"
        fi
      else
        echo "[DEBUG] ${id} ${name}:${tag} already loaded"
      fi
    fi
  done
}

# Save all docker images in one file
check_command docker ps -a > "$DOCKERBACKUP"/dockerps.txt
check_command docker images | sed '1d' | awk '{print $1 " " $2 " " $3}' > "$DOCKERBACKUP"/mydockersimages.list
msg_box "The following images will be saved to $DOCKERBACKUP/images

$(cat "$DOCKERBACKUP"/mydockersimages.list)

It may take a while so please be patient."

check_command save_images

# Set overlay2
echo "Setting overlay2 in /etc/docker/daemon.json"

cat << OVERLAY2 > /etc/docker/daemon.json
{
  "storage-driver": "overlay2"
}
OVERLAY2
rm -f /etc/systemd/system/docker.service
systemctl restart docker.service
echo "Reloading daemon"
systemctl daemon-reload
echo "Restarting the docker service"
check_command systemctl restart docker
apt-mark unhold docker-ce

# Remove old cached versions to avoid failures on update to new version
rm -Rf /var/cache/apt/archives/docker*
rm -Rf /var/cache/apt/archives/container*
rm -Rf /var/cache/apt/archives/aufs*

# Upgrade docker to latest version
rm -Rf /var/lib/docker
apt update -q4 & spinner_loading
apt upgrade docker-ce -y

# Load docker images back
echo "Importing saved docker images to overlay2..."
check_command load_images
msg_box "Your Docker images are now imported to overlay2, but not yet running.

To start the images again, please run the appropriate 'docker run' command for each docker.
These are all the imported docker images:
$(cat "${DB_FILE}")

You can also find the file with the imported docker images here:
$DB_FILE

If you experiance any issues, please report them to $ISSUES."
rm -f "$DOCKERBACKUP"/mydockersimages.list
