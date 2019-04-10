# Nextcloud VM
**Downloads from Github:**
![Downloads](https://img.shields.io/github/downloads/nextcloud/vm/total.svg)
<br>
**Build Status:**
[![Build Status](https://travis-ci.org/nextcloud/vm.svg?branch=master)](https://travis-ci.org/nextcloud/vm)
<br>
**Well, is this stable?**
![Stability Status](https://img.shields.io/badge/stability-stable-brightgreen.svg)
## Support the development
* [Create a PR](https://help.github.com/articles/creating-a-pull-request/) and improve the code
* Report [your issue](https://github.com/nextcloud/vm/issues/new)
* Help us with [existing issues](https://github.com/nextcloud/vm/issues)
* Write scripts so that this can be installed with [Vagrant](https://www.vagrantup.com/docs/getting-started/) or similar
* **[Donate](https://shop.hanssonit.se/product-category/donate/) or buy our [pre-configured VMs](https://shop.hanssonit.se/product-category/virtual-machine/): 500 GB, 1 TB, 2TB or Hyper-V.**

## Current [maintainers](https://github.com/nextcloud/vm/graphs/contributors)
* [Daniel Hanson](https://github.com/enoch85) @ [T&M Hansson IT AB](https://www.hanssonit.se)
* You? :)

## Special thanks to
* [Ezra Holm](https://github.com/ezraholm50) @ [Tech and Me](https://www.techandme.se)
* [Luis Guzman](https://github.com/Ark74) @ [SwITNet](https://switnet.net)
* [Stefan Heitmüller](https://github.com/morph027) @ [morph027's Blog](https://morph027.gitlab.io/)
* [Lorenzo Faleschini](https://github.com/penzoiders)
* [Georg Großmann](https://github.com/ggeorgg)

## Build your own VM, or install on a VPS
DigitalOcean example: https://youtu.be/LlqY5Y6P9Oc<br>
The script will mount and format the drive. Please select Manually Format & Mount when adding the second volume.

#### Minimum requirements:
* A clean [Ubuntu Server 18.04.X](http://cdimage.ubuntu.com/releases/18.04/release/ubuntu-18.04.2-server-amd64.iso) using the alternative installer
* OpenSSH (preferred)
* 20 GB HDD for OS
* XX GB HDD for DATA (/mnt/ncdata)
* Absolute minimum is 1 vCPU and 2 GB RAM (4 GB minimum if you are running OnlyOffice)
* A working internet connection (the script needs it to download files and variables)
* [VMware Player](https://www.vmware.com/products/workstation-player/workstation-player-evaluation.html) (fully tested with Hyper-V and KVM as well).

#### Recommended
* DHCP available
* 40 GB HDD for OS
* 4 vCPU
* 4 GB RAM
* Port 80 and 443 open to the server. [Here's](https://letsencrypt.org/docs/allow-port-80/) why port 80 is recomended. Yes, the VM handles redirection to 443.

#### Installation
1. Get the latest install script from master and install it with a sudo user:<br>
`curl https://raw.githubusercontent.com/nextcloud/vm/master/nextcloud_install_production.sh | sudo bash"`
2. When the VM is installed it will automatically reboot. Remember to login with the user you created:<br>
`ssh <user>@IP-ADDRESS`<br>
If it automatically runs as root when you reboot the machine, you have to abort it by pressing `CTRL+C` and run the script as the user you just created:<br>
`sudo -u <user> sudo bash /var/scripts/nextcloud-startup-script.sh` <br>
3. Please note that the installation/setup is *not* finished by just running the `nextcloud_install_production.sh` When you login with the (new) sudo user you ran the script with in step 2 you will automatically be presented with the setup script.

## Machine configuration of the released version
Please check the configuration [here](https://docs.hanssonit.se/s/W6fMouPiqQz3_Mog/virtual-machines-vm/d/W7Du9uPiqQz3_Mr1/machine-setup-nextcloud-vm).

## Full documentation
You can find the full documentation [here](https://docs.hanssonit.se/s/W6fMouPiqQz3_Mog/virtual-machines-vm/d/W6fMquPiqQz3_Moi/nextcloud-vm)

## Do you want to run this on your Raspberry Pi?
Great news! We have forked this repository and created a Raspberry Pi image that you can download from here: 
https://github.com/techandme/NextBerry or here https://www.techandme.se/nextberry-rpi/.

We call it NextBerry and it's confirmed to be working on Raspberry Pi 2 & 3.

NOTE (2018-08-01): This is not maintained anymore, but keeping the info in case someone wants to pick it up again.

## I want to test RC!
No problem! We made it simple. Run `update.sh` but abort it before it starts so that you have the latest `nextcloud_update.sh`. Then put this in your `nextcloud_update.sh` below the curl command (lib.sh) but before everything else and run it:

To test a specific RC version:

```
NCREPO="https://download.nextcloud.com/server/prereleases"
NCVERSION=12.0.1RC5
STABLEVERSION="nextcloud-$NCVERSION"
```

Or the latest RC:
```
NCREPO="https://download.nextcloud.com/server/prereleases"
NCVERSION=$(curl -s -m 900 $NCREPO/ | sed --silent 's/.*href="nextcloud-\([^"]\+\).zip.asc".*/\1/p' | sort --version-sort | tail -1)
STABLEVERSION="nextcloud-$NCVERSION"
```

## FAQ

Keep asking questions so that we can add them here.

**Q: Where can i dowload VMware Player?**
<br />
**A:** You can download the latest release [here](https://my.vmware.com/web/vmware/free#desktop_end_user_computing/vmware_workstation_player/12_0).

**Q: Why are my apps are disabled during an upgrade?**
<br />
**A:** Check [here](https://github.com/nextcloud/server/issues/11102#issuecomment-427685621
).

**Q: How to update Nextcloud VM?**
<br />
**A:** You cannot use the built in updater in Nextcloud GUI due to secure permissions on this VM. Use the built-in script instead:
`sudo bash /var/scripts/update.sh` or run `run_update_nextcloud` as root from your terminal.

**Q: How do I run the occ command?**
<br />
**A:** We've added an alias for that as well. As root, just run `nextcloud_occ`

**Q: The mcrypt module is missing in the VM, why?**
<br />
**A:** https://github.com/nextcloud/vm/issues/629

**Q: Where do I tweak the settings for php-fpm?**
<br />
**A:** You can change the settings in `/etc/php/7.2/fpm/pool.d/nextcloud.conf`, but be aware; only change it if you know what you are doing!

**Q: Some apps are not installed (like issuetemplate for example), when running the setup script**
<br />
**A:** https://github.com/nextcloud/vm/issues/639#issuecomment-416472543

**Q: The downloaded file is just a few kilobytes, or corrupted**
<br />
**A:** This is due to heavy load on the server. Please try again in a few minutes.

**Q: The script says: "WARNING: apt does not have a stable CLI interface yet. Use with caution in scripts"**
<br />
**A:** http://askubuntu.com/a/463966

**Q: I get NETWORK NOT OK when booting the VM. How do I solve that?**
<br />
**A:** There are a few causes to this error, most of them are your own network or firewall settings.
<br />
- Remove the VM NIC adapter in settings on VMware/Virtualbox and then re-adding a NIC adapter.
![alt_tag](https://goo.gl/gWg9JN)
- Check your firewall so that it doesn't block this specific IP
- Check your router/firewall that you have DHCP enabled.

**Q: I get a message that I'm not root, but I am.**
<br />
**A:** Please see here: https://github.com/nextcloud/vm/issues/200

**Q: Which Hyper-V generation should we chose when creating a machine to load this image?**
<br />
**A:** You currently need to use a 1st generation machine.

**Q: Do you have a pre-configured Hyper-V VM?**
<br />
**A:** Yes we have, you can download it here: https://shop.hanssonit.se/product/nextcloud-vm-microsoft-hyper-v-vhd/

**Q: I want a bigger version of this VM, where can I find that?**
<br />
**A:** You can download it here: https://shop.hanssonit.se/product/nextcloud-vm-500gb/

**Q: I have found a bug that I want to report, where do I do that?**
<br />
**A:** Just submit your report here: https://github.com/nextcloud/vm/issues/new

**Q: How to install apps if not selected during first install?**
<br />
**A:** Go to the apps folder in this repo and download the script in raw format and run them. For installing Talk:
`curl -sLO https://raw.githubusercontent.com/nextcloud/vm/master/apps/talk.sh && sudo bash talk.sh`

**Q: How to continue from partially installed system? - You got the FQDN wrong/You put in a bad password/ etc...**
<br />
**A:** Extract the VM again and start over. The script can *not* be run twice in a row.

**Q: Does automatic update update Ubuntu and Nextcloud?**
<br />
**A:** if you want automatic updates of both Ubuntu and Nextcloud then check out this blog post: https://www.techandme.se/nextcloud-update-is-now-fully-automated/

**Q: Can I enable-disable automatic update later of OS/Nextcloud?**
<br />
**A:** Yes, it's controlled by a cronjob. Just disable the cronjob to disable automatic updates.

**Q: How to backup?**
<br />
**A:** There are several ways. We recommend Rsync to a NAS or similar. You can find a script here: https://www.techandme.se/rsync-backup-script/

**Q:  Can I install in a VM with a NAT and port redirection of port 443 & 10000 & 22?**
<br />
**A:** Yes, check this out: https://docs.hanssonit.se/s/W6fMouPiqQz3_Mog/virtual-machines-vm/d/W6-83ePiqQz3_MrT/publish-your-server-online

## First look
![alt tag](https://github.com/nextcloud/nextcloud.com/blob/master/assets/img/features/VMwelcome.png)
