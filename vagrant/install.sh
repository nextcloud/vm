#!/bin/bash

git clone https://github.com/nextcloud/vm.git

cd vm

yes no | sudo bash nextcloud_install_production.sh

