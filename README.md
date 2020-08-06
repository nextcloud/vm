Nextcloud RPi
============

Server installation. Simplified. :cloud:
--------------------------------

#### Interactive Guidance
> **The Nextcloud RPi** — _(aka **N**ext**c**loud **R**aspberry **Pi**_ or _**NcRPi**)_ — helps you create a personal or corporate [Nextcloud Server] _faster_ and _easier._ Fundamentally, NcRPi is a carefully crafted _family_ of [\*nix] scripts which interactively guide you through a quality-controlled installation to obtain an [A+ security-rated] Nextcloud instance.

#### Curated Extras
> The Nextcloud [app store] extends core features by allowing you to enable a multitude of free one-click apps. However, _integration apps_ there like [Collabora Online] and [ONLYOFFICE] are solely _bridges_ to Nextcloud. You’re still required to install those services _separately_, which can be complex. NcRPi provides optional _**full installation of select curated apps**_, including those and others. Monitor and manage your cloud using any web browser with NcRPi’s hand-picked collection of power utilities featuring stunning, modern UIs.

#### All Systems Go
> NcRPi can check for and install _stable_ updates to keep things current, smooth, and secure.

--------------------

## Dependencies:
(Ubuntu Server 20.04 LTS 64-bit)
<br>
(Linux Kernel: 5.14)
- Apache 2.4
- PostgreSQL 12
- PHP-FPM 7.4
- Redis Memcache (latest stable version from PECL)
- APCu local cache (latest stable version from PECL)
- PHP-igbinary (latest stable version from PECL
- PHP-smbclient (latest stable version from PECL)
- Nextcloud Server Latest

## Support the development
* [Create a PR](https://help.github.com/articles/creating-a-pull-request/) and improve the code
* Report [your issue](https://github.com/nextcloud/vm/issues/new)
* Help us with [existing issues](https://github.com/nextcloud/vm/issues)
* Write scripts so that the release process becomes automated with [Vagrant](https://www.vagrantup.com/docs/getting-started/), [Terraform](https://www.terraform.io/) or similar
* **[Donate](https://shop.hanssonit.se/product-category/donate/)*
  
## Full documentation
* [Install with scripts](https://docs.hanssonit.se/s/bj0vl1ihv0jgrmfm08j0/build-your-own/d/bj0vl4ahv0jgrmfm0950/nextcloud-vm) (if you feel brave)
* [FAQ](https://docs.hanssonit.se/s/bj101nihv0jgrmfm09f0/faq/d/bj101pihv0jgrmfm0a10/nextcloud-vm?currentPageId=bj101sqhv0jgrmfm0a1g) (Frequently Asked Questions)
* [Machine configuration](https://docs.hanssonit.se/s/W6fMouPiqQz3_Mog/virtual-machines-vm/d/W7Du9uPiqQz3_Mr1/machine-setup-nextcloud-vm) (of the released version)

## I want to test a Release Candidate (RC), or Beta!
No problem, brave explorer! We made it simple. 

If you want to try the latest version yourself, there are two variables that you could use:

1. For latest **beta** version: `sudo bash /var/scripts/update.sh beta`

2. For specific **RC** version: `sudo bash /var/scripts/update.sh 19.0.0RC1`

Please keep in mind that this is only intended for testing and might crash your Nextcloud. Please keep backups!


## Vagrant example (Beta)

The `nextcloud_install_production.sh` script can be run as part of Vagrant provisioning.

See [this subrepo](https://github.com/nextcloud/vm/tree/master/vagrant) for more information.

Please report any issues you can find. Improvments are welcome!

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
* [szaimen](https://github.com/szaimen)
* You? :)

## Special thanks to
* [Ezra Holm](https://github.com/ezraholm50) @ [Tech and Me](https://www.techandme.se)
* [Luis Guzman](https://github.com/Ark74) @ [SwITNet](https://switnet.net)
* [Stefan Heitmüller](https://github.com/morph027) @ [morph027's Blog](https://morph027.gitlab.io/)
* [Lorenzo Faleschini](https://github.com/penzoiders)
* [Georg Großmann](https://github.com/ggeorgg)
* [liao20081228](https://github.com/liao20081228)
* [aaaskew](https://github.com/aaaskew)

[Nextcloud Server]: https://bit.ly/2CHIUkA
[app store]: https://bit.ly/2HUy4v9
[\*nix]: https://bit.ly/2UaCC7b
[A+ security-rated]: https://bit.ly/2mvlyJ3
[Collabora Online]: https://bit.ly/2WjVVZ8
[ONLYOFFICE]: https://bit.ly/2FA0TKj
