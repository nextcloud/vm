import glob, json, os, subprocess, urllib2

nc_path      = '/var/www/nextcloud/apps/'
backup_path  = '/var/NCBACKUP/apps/'
shipped_url  = 'http://raw.githubusercontent.com/nextcloud/server/master/core/shipped.json'

json_data    = json.load(urllib2.urlopen(shipped_url))
shipped_apps = json_data['shippedApps'] + json_data['alwaysEnabled']

installed_dirs = set(os.path.basename(path) for path in glob.glob(backup_path + '*'))
missing_dirs   = installed_dirs.difference(shipped_apps)

for d in missing_dirs:
    subprocess.call(['rsync', '-Aax', os.path.join(backup_path, d), nc_path])
    subprocess.call(['sudo', '-u', 'www-data', '/var/www/nextcloud/occ', 'app:enable', d])
