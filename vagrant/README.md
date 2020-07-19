# Nextcloud VM with vagrant
This subrepo contains all the Vagrant config to get an Ubuntu 20.04 VM with the latest version of Nextcloud installed.

**Please note that this is __not__ the preferred way to install Nextcloud. It's also untested in the current state.**

# Setup
`vagrant up` will install everything

Go to [https://localhost:8080/](https://localhost:8080/) and access Nextcloud with credentials `ncadmin / nextcloud`

# Information
- `VagrantFile` contains instructions to run an inline script: `install.sh`
- `install.sh` does the following
    - Clones https://github.com/nextcloud/vm
    - Runs `yes no | sudo bash nextcloud_install_production.sh` which uses the default values for each prompt

See https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh for default values.

# Special thanks to
@gjgd for providing https://github.com/gjgd/vagrant-nextcloud which this is based upon

