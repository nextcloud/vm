Nextcloud VM
============

Server installation. Simplified. :cloud:
--------------------------------

#### Interactive Guidance
> **The Nextcloud VM** — _(aka **N**ext**c**loud **V**irtual **M**achine_ or _**NcVM**)_ — helps you create a personal or corporate [Nextcloud Server] _faster_ and _easier._ Fundamentally, NcVM is a carefully crafted _family_ of [\*nix] scripts which interactively guide you through a quality-controlled installation to obtain an [A+ security-rated] Nextcloud instance.

#### Curated Extras
> The Nextcloud [app store] extends core features by allowing you to enable a multitude of free one-click apps. However, _integration apps_ there like [Collabora Online] and [ONLYOFFICE] are solely _bridges_ to Nextcloud. You’re still required to install those services _separately_, which can be complex. NcVM provides optional _**full installation of select curated apps**_, including those and others. Monitor and manage your cloud using any web browser with NcVM’s hand-picked collection of power utilities featuring stunning, modern UIs.

#### All Systems Go
> NcVM can check for and install _stable_ updates to keep things current, smooth, and secure.

--------------------

## Support the development
* [Create a PR](https://help.github.com/articles/creating-a-pull-request/) and improve the code
* Report [your issue](https://github.com/nextcloud/vm/issues/new)
* Help us with [existing issues](https://github.com/nextcloud/vm/issues)
* Write scripts so that the release process becomes automated with [Vagrant](https://www.vagrantup.com/docs/getting-started/), [Terraform](https://www.terraform.io/) or similar
* **[Donate](https://shop.hanssonit.se/product-category/donate/) or buy our [pre-configured VMs](https://shop.hanssonit.se/product-category/virtual-machine/): 500 GB, 1 TB, 2TB or Hyper-V.**
  
## Full documentation
* [VM](https://docs.hanssonit.se/s/W6fMouPiqQz3_Mog/virtual-machines-vm/d/W6fMquPiqQz3_Moi/nextcloud-vm) (the easiest option)
* [Install with scripts](https://docs.hanssonit.se/s/bj0vl1ihv0jgrmfm08j0/build-your-own/d/bj0vl4ahv0jgrmfm0950/nextcloud-vm) (if you feel brave)
* [FAQ](https://docs.hanssonit.se/s/bj101nihv0jgrmfm09f0/faq/d/bj101pihv0jgrmfm0a10/nextcloud-vm?currentPageId=bj101sqhv0jgrmfm0a1g) (Frequently Asked Questions)
* [Machine configuration](https://docs.hanssonit.se/s/W6fMouPiqQz3_Mog/virtual-machines-vm/d/W7Du9uPiqQz3_Mr1/machine-setup-nextcloud-vm) (of the released version)

## I want to test a Release Candidate (RC), or Beta!
No problem, brave explorer! We made it simple. 

In some cases we do pre-releases of the VM as well. Those can be found in the [TESTING](https://cloud.hanssonit.se/s/zjsqkrSpzqJGE9N?path=%2FTESTING) folder on the download server. If you want to try the latest version yourself, just follow the steps below:
1. Download the latest [nextcloud_update.sh](https://raw.githubusercontent.com/nextcloud/vm/master/nextcloud_update.sh) to your server.
2. Put the below variables right above line 256 **(# Major versions unsupported)**
3. Run nextcloud_update.sh

To test a specific RC version:

```
NCREPO="https://download.nextcloud.com/server/prereleases"
NCVERSION=16.0.0RC1
STABLEVERSION="nextcloud-$NCVERSION"
```

Or the latest Beta:
```
NCREPO="https://download.nextcloud.com/server/prereleases"
NCVERSION=$(curl -s -m 900 $NCREPO/ | sed --silent 's/.*href="nextcloud-\([^"]\+\).zip.asc".*/\1/p' | sort --version-sort | tail -1)
STABLEVERSION="nextcloud-$NCVERSION"
```

## Vagrant example (Alpha)
Apperantly the install script is possible to run straight up via Vagrant. This is the file that a user posted:
```
vagrant init
vim Vagrantfile
# Change the box to `ubuntu/bionic64`
  config.vm.box = "ubuntu/bionic64"
# Add a public IP: you can either do this, a local IP, or port forward
  config.vm.network "public_network", ip: "192.168.1.99", bridge: "en1"
# Increase memory to 2 GB (this is for virtualbox, see documentation for other providers)
  config.vm.provider "virtualbox" do |vb|
    vb.memory = "2048"
  end
# start up the box
vagrant up
# SSH in, clone vm repo, and run script
vagrant ssh
git clone https://github.com/nextcloud/vm.git
cd vm
yes no | sudo bash nextcloud_install_production.sh
```
Though I (@enoch85) haven't tested this yet, so testing and reporting is welcome! What I think will happen without having tested it, is that the different questions will be skipped, but I'm not sure about which questions, and the outcome. So if someone could please try this and post the debug output that would be awesome!

## First look
![alt tag](https://github.com/nextcloud/nextcloud.com/blob/master/assets/img/features/VMwelcome.png)

## The usual tags
**Downloads from Github (not the main downloads location):**
<br>
![Downloads](https://img.shields.io/github/downloads/nextcloud/vm/total.svg)
<br>
**Downloads from main server:**
<br>
~100 per day since 2016
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
