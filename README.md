# Nextcloud VM
[![irc](https://img.shields.io/badge/irc%20channel-%23techandme%20on%20freenode-blue.svg)](https://webchat.freenode.net/?channels=techandme) [![Build Status](https://travis-ci.org/nextcloud/vm.svg?branch=master)](https://travis-ci.org/nextcloud/vm)

## Support the development
* [Create a PR](https://help.github.com/articles/creating-a-pull-request/) and improve the code
* Report [your issue](https://github.com/nextcloud/vm/issues/new)
* Help us with [existing issues](https://github.com/nextcloud/vm/issues)
* Write scripts so that this can be installed with [Vagrant](https://www.vagrantup.com/docs/getting-started/) or similar
* [Donate](https://shop.techandme.se/index.php/product-category/donate/) or buy our [pre-configured VMs](https://shop.techandme.se/index.php/product-category/virtual-machine/): 500 GB, 1 TB or Hyper-V.

## Current [maintainers](https://github.com/nextcloud/vm/graphs/contributors)
* [Daniel Hanson](https://github.com/enoch85) @ [Tech and Me](https://www.techandme.se)
* [Ezra Holm](https://github.com/ezraholm50) @ [Tech and Me](https://www.techandme.se)
* [Luis Guzman](https://github.com/Ark74) @ [SwITNet](https://switnet.net)
* [Stefan Heitmüller](https://github.com/morph027) @ [morph027's Blog](https://morph027.gitlab.io/)
* You? :)

## Build your own VM, or install on a VPS

#### Minimum requirements:
* A clean Ubuntu Server 16.04.X
* OpenSSH (preferred)
* 20 GB HDD
* At least 1 vCPU and 2 GB RAM

#### Recommended
* Thick provisioned (better performance and easier to maintain)
* DHCP available

#### Installation
1. Get the latest install script from master:<br>
`wget https://raw.githubusercontent.com/nextcloud/vm/master/nextcloud_install_production.sh`
2. Run the script with:<br>
`sudo bash nextcloud_install_production.sh`
3. When the VM is installed it will automatically reboot. Remember to login with the user you created:<br>
`ssh <user>@IP-ADDRESS`<br>
4. Please note that the installation/setup is *not* finnished by just running the `nextcloud_install_production.sh` When you login with the (new) sudo user you ran the script with in step 2 you will automatically be presented with the setup script.

## Machine configuration of the released version
Please check the configuration here: https://www.techandme.se/machine-setup-nextcloud/

## FAQ

Keep asking questions so that we can add them here.

**Q:** Where can i dowload VMware Player?
<br />
**A:** You can download the latest release [here](https://my.vmware.com/web/vmware/free#desktop_end_user_computing/vmware_workstation_player/12_0).

**Q:** The script says: "WARNING: apt does not have a stable CLI interface yet. Use with caution in scripts"
<br />
**A:** http://askubuntu.com/a/463966

**Q:** I get NETWORK NOT OK when booting the VM. How do I solve that?
<br />
**A:** There are a few causes to this error, most of them are your own network or firewall settings.
<br />
- Remove the VM NIC adapter in settings on VMware/Virtualbox and then re-adding a NIC adapter.
![alt_tag](https://goo.gl/gWg9JN)
- Check your firewall so that it doesn't block this specific IP
- Check your router/firewall that you have DHCP enabled.

**Q:** I get a message that I'm not root, but I am.
<br />
**A:** Please see here: https://github.com/nextcloud/vm/issues/200

**Q:** Which Hyper-V generation should we chose when creating a machine to load this image?
<br />
**A:** You currently need to use a 1st generation machine.

**Q:** Do you have a pre-configured Hyper-V VM?
<br />
**A:** Yes we have, you can download it here: https://shop.techandme.se/index.php/product/nextcloud-vm-microsoft-hyper-v-vhd/

**Q:** I want a bigger version of this VM, where can I find that?
<br />
**A:** You can download it here: https://shop.techandme.se/index.php/product/nextcloud-vm-500gb/

**Q:** I have found a bug that I want to report, where do I do that?
<br />
**A:** Just submit your report here: https://github.com/nextcloud/vm/issues/new

## First look

![alt tag](https://raw.githubusercontent.com/nextcloud/screenshots/master/vm/first-look.jpg)
