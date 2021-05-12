# Installation

Before install the module you need to configure a profile in your config Lizmap.
You need to add in `lizmap/var/config/profiles.ini.php`:

**Only replace host, database, user and password values.**

```ini
[jdb:pgrouting]

driver=pgsql
host=pgsql
database=lizmap
user=lizmap
password="yourpassword"
search_path=pgrouting,public
```

## Manual installation into lizmap 3.5 only without Composer

* Get the last ZIP archive in the [repository page](https://projects.3liz.org/lizmap-modules/lizmap-pgrouting-module).
* Extract the archive and copy the `pgrouting` directory in Lizmap Web Client folder `lizmap/lizmap-modules/`
* Edit the config file `lizmap/var/config/localconfig.ini.php` and add into 
  the section `[modules]`:

```ini
pgrouting.access=2
pgrouting.installparam="srid=2154"
```
You can replace 2154 by another SRID that you use.

* Then execute Lizmap install scripts into `lizmap/install/` :

```bash
php lizmap/install/installer.php
./lizmap/install/clean_vartmp.sh
./lizmap/install/set_rights.sh
```
