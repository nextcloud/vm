This repo is intended to help migrate an existing Nextcloud VM installation to a Docker container.
The Docker container will use the existing Postgresql Database (and it may update it) and the existing datadir.

# WARNING
This subfolder, and the migration tool have not been tested by the main maintainers of this repo. We put this here solely for inspiration, and you're on your own if something fails. We would still appreciate if you told us what went wrong though, by creating an issue. 

How to use:
1. clone git
2. cd nc_migration
3. chmod +x migrate.sh
4. sudo ./migrate.sh destinationdir nc_username nc_password nc_port
5. change the trusted_domainssection in the config/config.php file to you needs
6. run it: 'docker-compose up-d'

Explanation of the bash script arguments:
- destinationdir = the folder containing all the files needed to run the Docker container
- nc_user = the Nextcloud administrator user
- nc_password = password for this user
- nc_port = port exposed by the container


TBD:
1. Implement SSL
2. Change bash script to include 'help' section and to be more versatile
3. Add redis
