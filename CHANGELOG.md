### Download can be found here: https://www.hanssonit.se/nextcloud-vm/ 

Check the latest commits here: https://github.com/nextcloud/vm/commits/master

Documentation can be found here: https://docs.hanssonit.se/s/W6fMouPiqQz3_Mog/virtual-machines-vm/d/W7Du9uPiqQz3_Mr1/nextcloud-vm-machine-configuration

### Small changelog:
- Introduce fetch_liband chain libaries - this is now the new way of fetching the libs
- Add more menu scripts
- Add more Yes/No boxes and fix occurances where the text wasn't shown due to print_text_in_color
- Standarlize Whiptails even more
- Change to TLS1.2 all over
- Make functions out of all special variables
- Create a new (smart) startup script with basic server settings
- Automatically get the main domain for all scripts with built in proxies
- Minor bugfixes and improvements

### Full changelog:
- https://github.com/nextcloud/vm/compare/19.0.2..19.0.3
- https://nextcloud.com/changelog/#latest19

### Known errors:
- N/A

### Good to know
- If you plan to install apps that use docker containers such as Collabora or Full Text Search, you need to raise the amount of RAM to at least 4 GB. If you don't, the startup script will fail to set enough max_children to the PHP-FPM configuration as we calculate on available RAM, and not the total.

    Collabora requires 2 GB additional RAM
    Full Text Search requires 2 GB additional RAM

If you run Hyper-V or want 500 GB, 1 TB or 2 TB VM you can download it from [T&M Hansson IT's shop](https://shop.hanssonit.se/product-category/virtual-machine/nextcloud/). 
**Please note that BOTH disks need to be imported when using the Hyper-V image. The disk ending with _OS for OS, and the disk ending with _DATA for DATA.**

PR's are more than welcome. Happy Nextclouding!
