<<<<<<< HEAD
# Nextcloud for your RaspberryPI 2 or 3

[![irc](https://img.shields.io/badge/irc%20channel-%23techandme%20on%20freenode-blue.svg)](https://webchat.freenode.net/?channels=techandme)

# Login screen
![alt tag](https://raw.githubusercontent.com/techandme/NextBerry/master/nextberry-login-screen1.jpeg)

## What is NextBerry?
[More info](https://www.techandme.se/nextberry-vm/)
=======
# Nextcloud VM
[![irc](https://img.shields.io/badge/irc%20channel-%23techandme%20on%20freenode-blue.svg)](https://webchat.freenode.net/?channels=techandme)
>>>>>>> 62edc2fb096dd9380838ccb38c1b65f1150d02ff

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
* You? :)

<<<<<<< HEAD
## Image
* [Image link](https://cloud.waaromzomoeilijk.nl/s/oM25mziMEN6aAkJ)
* [Mirror 1](https://cloud.techandme.se/s/G6PaI0miBibhDwj)

## Documentation
[How to](https://github.com/techandme/NextBerry/wiki)

## Version info
[Versions](https://github.com/techandme/NextBerry/releases)

## Machine configuration
=======
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
2. Run the script with your sudo user:<br> 
`sudo -u <user> sudo bash nextcloud_install_production.sh`<br>
Or, download the adduser script and run it:<br>
`https://raw.githubusercontent.com/nextcloud/vm/master/static/adduser.sh && sudo bash adduser.sh`
3. When the VM is installed it will automatically reboot. Remember to login with the user you created:<br>
`ssh <user>@IP-ADDRESS`

## Machine configuration of the released version
>>>>>>> 62edc2fb096dd9380838ccb38c1b65f1150d02ff
Please check the configuration here: https://www.techandme.se/machine-setup-nextcloud/

Note: this build does not inlude Webmin.

## FAQ
[FAQ](https://github.com/techandme/NextBerry/wiki/FAQ)
