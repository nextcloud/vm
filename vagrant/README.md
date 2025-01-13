# Nextcloud VM with vagrant
This subrepo contains all the Vagrant config to get an Ubuntu 24.04 VM with the latest version of Nextcloud installed.

**Please note that this is __not__ the preferred way to install Nextcloud. It's also untested in the current state.**

# Setup

## Host setup
Running this cloud image requires you to use libvirt.
Tested working on stock Ubuntu 22.04 LTS

1. Install `qemu-kvm`, `libvirt-daemon-system`, `bridge-utils`, `libvirt-dev` and `libvirt-clients` packages-

Then install the vagrant libvirt plugin: `vagrant plugin install vagrant-libvirt`

Then we need to make sure nested virtualization is initialized, as Nextcloud VM uses QEMU to run apps etc:

Check that nested virtualization is enabled:
Intel systems: `cat /sys/module/kvm_intel/parameters/nested`
AMD systems: `/sys/module/kvm_amd/parameters/nested`

Must return Y or 1.

Following must be done after each reboot:
**Intel setup**
sudo modprobe -r kvm_intel
sudo modprobe kvm_intel nested=1

**AMD setup**
sudo modprobe -r kvm_amd
sudo modprobe kvm_amd nested=1


## VM Setup
`vagrant up` will install everything

Go to [https://localhost:8080/](https://localhost:8080/) and access Nextcloud with credentials `ncadmin / nextcloud`

# Information
- `VagrantFile` contains instructions to run an inline script: `install.sh`
- `install.sh` does the following
    - Clones https://github.com/nextcloud/vm
    - Runs `yes no | sudo bash nextcloud_install_production.sh` which uses the default values for each prompt

See https://raw.githubusercontent.com/nextcloud/vm/main/lib.sh for default values.

# Special thanks to
- @gjgd for providing https://github.com/gjgd/vagrant-nextcloud which this is based upon
- @celeroncool for updating it to 24.04 :)
