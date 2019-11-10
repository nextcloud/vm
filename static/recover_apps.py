import glob, json, os, subprocess, requests

nc_path      = '/var/www/nextcloud/apps/'
backup_path  = '/var/NCBACKUP/apps/'
shipped_url  = 'http://raw.githubusercontent.com/nextcloud/server/master/core/shipped.json'

json_data    = requests.get(shipped_url, timeout=60).json()
shipped_apps = json_data['shippedApps'] + json_data['alwaysEnabled']

installed_dirs = set(os.path.basename(path) for path in glob.glob(backup_path + '*'))
missing_dirs   = installed_dirs.difference(shipped_apps)

for d in missing_dirs:
#    subprocess.call(['rsync', '-Aax', os.path.join(backup_path, d), nc_path])
#    subprocess.call(['sudo', '-u', 'www-data', '/var/www/nextcloud/occ', 'app:enable', d])
     subprocess.call(['sudo', '-u', 'www-data', '/var/www/nextcloud/occ', 'app:install', d])
