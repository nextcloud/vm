### Download can be found here: https://www.hanssonit.se/nextcloud-vm/ 

Check the latest commits here: https://github.com/nextcloud/vm/commits/master

Documentation can be found here: https://docs.hanssonit.se/s/W6fMouPiqQz3_Mog/virtual-machines-vm/d/W7Du9uPiqQz3_Mr1/nextcloud-vm-machine-configuration

### Good to know
- If you plan to install apps that use docker containers such as Collabora or Full Text Search, you need to raise the amount of RAM to at least 4 GB. If you don't, the startup script will fail to set enough max_children to the PHP-FPM configuration as we calculate on available RAM, and not the total.

    Collabora requires 2 GB additional RAM
    Full Text Search requires 2 GB additional RAM

If you run Hyper-V or want 500 GB, 1 TB or 2 TB VM you can download it from [T&M Hansson IT's shop](https://shop.hanssonit.se/product-category/virtual-machine/nextcloud/). 
**Please note that BOTH disks need to be imported when using the Hyper-V image. The disk ending with _OS for OS, and the disk ending with _DATA for DATA.**

PR's are more than welcome. Happy Nextclouding!

## 20.0.0

### Small changelog:
- Add SMTP email relay to be able to send emails directly from the OS (Ubuntu)
- Make it possible to open ports with UPNP
- Update notify_admin_gui to cache all found admin users (tested with 500 users, and it's MUCH faster now)
- Disable hibernation (Ubuntu)
- Set archive.ubuntu.com as default Repo (Ubuntu)
- Standardize whiptails even more
- Improve fetch_lib
- Use fetch_lib in all scripts to prefer local libary instead of hammering Github with requests in every script
- Update all Docker containers one by one when the update script is run due to compatibility issues with Bitwarden Password manager
- Improve the way passwords are set during the initial setup
- SMBmount: Introduce the option to customize the mount before adding as external storage to Nextcloud
- SMBmount: Add the option to utilize inotify to actively watch over externally changed files and folders
- Repository: cleanup by removing duplicate scripts and not-needed functions
- Repository: added the [not-supported folder](https://github.com/nextcloud/vm/tree/master/not-supported) with additional options like creating a SMB-server

- Minor bugfixes and improvements

### Full changelog:
- https://github.com/nextcloud/vm/compare/19.0.3..20.0.0
- https://nextcloud.com/changelog/#latest20

## 19.0.3

### Small changelog:
- Standardize input_box flow
- Automatically rewrite Webmin to HTTPS
- Add default dark mode theme to Adminer
- Make Adminer work on HTTP/2
- Introduce fetch_lib and chain libaries - this is now the new way of fetching the libs
- Add more menu scripts
- Add more Yes/No boxes and fix occurances where the text wasn't shown due to print_text_in_color
- Standardize Whiptails even more
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
