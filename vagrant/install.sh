#!/bin/bash

apt install curl -y

curl -sLO https://raw.githubusercontent.com/nextcloud/vm/run_locally/nextcloud_install_production.sh

yes no | sudo bash nextcloud_install_production.sh
