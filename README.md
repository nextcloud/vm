# Nextcloud VM
[![irc](https://img.shields.io/badge/irc%20channel-%23nextcloud--vm%20on%20freenode-blue.svg)](https://webchat.freenode.net/?channels=techandme)

## Maintainers
* [Daniel Hanson](https://github.com/enoch85) @ [Tech and Me](https://www.techandme.se)
* [Ezra Holm](https://github.com/ezraholm50) @ [Tech and Me](https://www.techandme.se)
* [Ark74](https://github.com/Ark74)
* You? :)


## Build Requirements
These requirements are only applied if you build from the scripts:
* Ubuntu Server 16.04.X Server
* OpenSSH (preferred)

If you install this on a clean Ubuntu 16.04.X VM, the only script you need to run is "nextcloud_install_production.sh". All the other scripts are fetched from this repository during the installation.

It would be really nice if someone could develop the scripts so that they worked "out of the box", without having to use a "base VM" with Ubuntu 16.04 pre-installed. Vagrant is an option.

## Machine configuration
Please check the configuration here: https://www.techandme.se/machine-setup-nextcloud/

## FAQ

Keep asking questions so that we can add them here.

**Q:** The script says: "WARNING: apt does not have a stable CLI interface yet. Use with caution in scripts"
<br />
**A:** http://askubuntu.com/a/463966

**Q:** I get NETWORK NOT OK when booting the VM. How do I solve that?
<br />
**A:** There are a few causes to this error, most of them are your own network or firewall settings.
<br />
- Remove the VM NIC adapter in settings on VMware/Virtualbox and then re-adding a NIC adapter.
![alt_tag](https://goo.gl/gWg9JN)
<br />
- Check your firewall so that it doesn't block this specific IP
<br />
- Check your router/firewall that you have DHCP enabled.

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
