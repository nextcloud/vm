Nextcloud VM
============

Server installation. Simplified. :cloud:
--------------------------------

#### Interactive Guidance
> **Nextcloud VM** — _(aka **N**extcloud **V**irtual **M**achine_ or _**NVM**)_ — helps you create a personal or corporate [Nextcloud Server] _faster_ and _easier._ Fundamentally, NVM is a carefully crafted _family_ of [\*nix] scripts which interactively guide you through a quality-controlled installation to obtain an [A+ security-rated] Nextcloud instance.

#### Curated Extras
> The Nextcloud [app store] extends core features by allowing you to enable a multitude of free one-click apps. However, _integration apps_ there like [Collabora Online] and [ONLYOFFICE] are solely _bridges_ to Nextcloud. You’re still required to install those services _separately_, which can be complex. NVM provides optional _**full installation of select curated apps**_, including those and others. Monitor and manage your cloud using any web browser with NVM’s hand-picked collection of power utilities featuring stunning, modern UIs.

#### All Systems Go
> NVM can check for and install _stable_ updates to keep things current, smooth, and secure.

--------------------

## Support the development
* [Create a PR](https://help.github.com/articles/creating-a-pull-request/) and improve the code
* Report [your issue](https://github.com/nextcloud/vm/issues/new)
* Help us with [existing issues](https://github.com/nextcloud/vm/issues)
* Write scripts so that this can be installed with [Vagrant](https://www.vagrantup.com/docs/getting-started/) or similar
* **[Donate](https://shop.hanssonit.se/product-category/donate/) or buy our [pre-configured VMs](https://shop.hanssonit.se/product-category/virtual-machine/): 500 GB, 1 TB, 2TB or Hyper-V.**
  
## Build your own VM, or install on a VPS
DigitalOcean example: https://youtu.be/LlqY5Y6P9Oc<br>
The script will mount and format the drive. Please select Manually Format & Mount when adding the second volume.

#### MINIMUM SYSTEM REQUIREMENTS
* A clean [Ubuntu Server 18.04.X](http://cdimage.ubuntu.com/releases/18.04/release/ubuntu-18.04.2-server-amd64.iso) using the alternative installer
* OpenSSH (preferred)
* 20 GB HDD for OS
* XX GB HDD for DATA (/mnt/ncdata)
* Absolute minimum is 1 vCPU and 2 GB RAM (4 GB minimum if you are running OnlyOffice)
* A working internet connection (the script needs it to download files and variables)
* [VMware Player](https://www.vmware.com/products/workstation-player/workstation-player-evaluation.html) (fully tested with Hyper-V and KVM as well).

#### RECOMMENDED
* DHCP available
* 40 GB HDD for OS
* 4 vCPU
* 4 GB RAM
* Ports 80 and 443 open to the server. [Here’s](https://letsencrypt.org/docs/allow-port-80/) why port 80 is recomended. Yes: the VM handles redirection to 443.

#### INSTALLATION: OVERVIEW

_**Two**_ scripts run _**consecutively**_ to create your Nextcloud instance, seperated by a reboot. The first script (`nextcloud_install_production.sh`) automatically executes when launching your new VM for the first time. It helps you choose and install features, create your user account, and then reboots. After the VM reboots and you login with the new user name you created, the second script (`nextcloud-startup-script.sh`) completes setup.

#### INSTALLATION: STEP-BY-STEP

- **STEP 1** — Download and execute the latest Nextcloud VM installer script using _**su**per user **do** (sudo):_<br>
`sudo bash -c "$(wget -q -O - https://raw.githubusercontent.com/nextcloud/vm/master/nextcloud_install_production.sh)"` <br>
After the first script completes ...
- **STEP 2** — The VM automatically reboots.
- **STEP 3** — Login with your new user name locally or remotely (via CLI: `ssh <user>@IP-ADDRESS`). The second script executes and completes installation.

> ##### AN IMPORTANT NOTE
> *If the VM automatically runs as **root** after rebooting,
> press `CTRL+C` to abort `nextcloud-startup-script.sh.`
> Then manually run the startup script
> as your newly-created **user**:*
> `sudo -u <user> sudo bash /var/scripts/nextcloud-startup-script.sh` — 
> **Setup is *not* finished after running the *first* script.
> *Both* must execute *consecutively*.**

## Machine configuration of the released version
Please check the configuration [here](https://docs.hanssonit.se/s/W6fMouPiqQz3_Mog/virtual-machines-vm/d/W7Du9uPiqQz3_Mr1/machine-setup-nextcloud-vm).

## Full documentation
You can find the full documentation [here](https://docs.hanssonit.se/s/W6fMouPiqQz3_Mog/virtual-machines-vm/d/W6fMquPiqQz3_Moi/nextcloud-vm)

## Do you want to run this on your Raspberry Pi?
Great news! We’ve forked this repository and created a Raspberry Pi image. Download it [here](https://github.com/techandme/NextBerry) or [here](https://www.techandme.se/nextberry-rpi/).

We call it NextBerry and it’s confirmed to be working on Raspberry Pi 2 & 3.

NOTE (2018-08-01): This is not maintained anymore, but keeping the info in case someone wants to pick it up again.

## I want to test a Release Candidate (RC)!
No problem, brave explorer! We made it simple. Run `update.sh` but abort it before it starts so that you have the latest `nextcloud_update.sh`. Then put this in your `nextcloud_update.sh` below the curl command (lib.sh) but before everything else and run it.

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

Keep asking questions so we can add them here.

**Q: Where can I download VMware Player?**
<br />
**A:** Get the latest release [here](https://my.vmware.com/web/vmware/free#desktop_end_user_computing/vmware_workstation_player/12_0).

**Q: Why are my apps disabled during an upgrade?**
<br />
**A:** To ensure compatibility with a newer system. (Read [further](https://github.com/nextcloud/server/issues/11102#issuecomment-427685621).)

**Q: How do I update my Nextcloud VM?**
<br />
**A:** Use our script — `sudo bash /var/scripts/update.sh` — or, as root in the terminal — `run_update_nextcloud`


**Q: How do I run the occ command?**
<br />
**A:** We’ve added an alias for that as well. As root, just run `nextcloud_occ`

**Q: The Mcrypt module is missing in the VM. Why?**
<br />
**A:** It’s deprecated[¹](https://wiki.php.net/rfc/mcrypt-viking-funeral) abandonware[²](http://php.net/manual/en/migration71.deprecated.php). (More [here](https://github.com/nextcloud/vm/issues/629).)

**Q: Where do I tweak PHP-FPM settings?**
<br />
**A:** You can change them in `/etc/php/7.2/fpm/pool.d/nextcloud.conf` but **BE AWARE**: Only alter them if you know what you’re doing!

**Q: Some apps like _issuetemplate_ aren’t installed by the setup script.**
<br />
**A:** We’ve seen this temporary [network irregularity](https://github.com/nextcloud/vm/issues/639#issuecomment-416472543) before. Try again. It’ll work!

**Q: The downloaded file is just a few kilobytes, or corrupted.**
<br />
**A:** That’s due to heavy server load. Wait a few minutes and try again.

**Q: The script says: “WARNING: apt does not have a stable CLI interface yet. Use with caution in scripts.”**
<br />
**A:** Read [here](http://askubuntu.com/a/463966).

**Q: How do I fix a “NETWORK NOT OK” error when booting the VM?**
<br />
**A:** Check the most likely culprits: your network and firewall settings.
<br />
- Open VMware / Virtualbox Settings. Remove your VM’s network adapter (aka Network Interface Card or NIC). Add a new NIC.<br>
![alt_tag](https://goo.gl/gWg9JN)
- Set the NIC to **Bridged**, not **Shared** mode.
- Ensure your firewall isn't blocking the VM’s IP address.
- Ensure either:
  - (a) your router has DHCP enabled so it *automatically* assigns the VM a unique IP address or
  - (b) you *manually* assign your VM a unique static IP (preferably locked to its MAC address)

**Q: I get a message that I'm not root, but I am.**
<br />
**A:** Is your net connection solid? See more [here](https://github.com/nextcloud/vm/issues/200)

**Q: Which Hyper-V generation should we chose when creating a machine to load this image?**
<br />
**A:** Currently, use a first generation machine.

**Q: Do you have a pre-configured Hyper-V VM?**
<br />
**A:** Yep! Download it [here.](https://shop.hanssonit.se/product/nextcloud-vm-microsoft-hyper-v-vhd/)

**Q: I want a bigger version of this VM. Where can I find that?**
<br />
**A:** Download 500GB, 1T, 2T, and order custom sizes [here.](https://shop.hanssonit.se/product-category/virtual-machine/nextcloud-vm/)

**Q: I found a bug! How do I report it?**
<br />
**A:** Submit bug sightings [here.](https://github.com/nextcloud/vm/issues/new)

**Q: How do I install apps that weren’t selected during the first install?**
<br />

**A:** Easy! All app installer scripts are [in our repo](https://github.com/nextcloud/vm/tree/master/apps). Just download and execute the script(s) for your desired app(s). For example, to install Nextcloud Talk run:
`curl -sLO https://raw.githubusercontent.com/nextcloud/vm/master/apps/talk.sh && sudo bash talk.sh`

**Q: I typed in the wrong \[domain name | password | etc]! Can I abort and resume?**
<br />
**A:** Sorry, *no.* Extract the VM again and start over. The script can *not* be run twice in a row.

**Q: Does automatic update affect both Ubuntu and Nextcloud?**
<br />
**A:** If you want to auto update Ubuntu *and* Nextcloud check [this blog post](https://www.techandme.se/nextcloud-update-is-now-fully-automated/). 

**Q: Can I enable / disable auto updates of my OS / Nextcloud?**
<br />
**A:** Yes. It’s controlled by a cronjob. Disable the cronjob to disable auto updates.

**Q: How do I backup?**
<br />
**A:** There are several ways. We recommend [Rsync](https://rsync.samba.org/) to a NAS or similar. You can find a script [here](https://www.techandme.se/rsync-backup-script/).

**Q: How do I route ports 443, 10000, and 22 to my VM? Can you help me with NAT loopback?**
<br />
**A:** Sure can. Check [this](https://docs.hanssonit.se/s/W6fMouPiqQz3_Mog/virtual-machines-vm/d/W6-83ePiqQz3_MrT/publish-your-server-online) out.

## First look
![alt tag](https://github.com/nextcloud/nextcloud.com/blob/master/assets/img/features/VMwelcome.png)

## The usual tags
**Downloads from Github:**
<br>
![Downloads](https://img.shields.io/github/downloads/nextcloud/vm/total.svg)
<br>
**Build Status:**
<br>
[![Build Status](https://travis-ci.org/nextcloud/vm.svg?branch=master)](https://travis-ci.org/nextcloud/vm)
<br>
**Stability Status:**
<br>
![Stability Status](https://img.shields.io/badge/stability-stable-brightgreen.svg)

## Current [maintainers](https://github.com/nextcloud/vm/graphs/contributors)
* [Daniel Hanson](https://github.com/enoch85) @ [T&M Hansson IT AB](https://www.hanssonit.se)
* You? :)

## Special thanks to
* [Ezra Holm](https://github.com/ezraholm50) @ [Tech and Me](https://www.techandme.se)
* [Luis Guzman](https://github.com/Ark74) @ [SwITNet](https://switnet.net)
* [Stefan Heitmüller](https://github.com/morph027) @ [morph027's Blog](https://morph027.gitlab.io/)
* [Lorenzo Faleschini](https://github.com/penzoiders)
* [Georg Großmann](https://github.com/ggeorgg)

[Nextcloud Server]: https://bit.ly/2CHIUkA
[app store]: https://bit.ly/2HUy4v9
[\*nix]: https://bit.ly/2UaCC7b
[A+ security-rated]: https://bit.ly/2mvlyJ3
[Collabora Online]: https://bit.ly/2WjVVZ8
[ONLYOFFICE]: https://bit.ly/2FA0TKj
