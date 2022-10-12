# requirements

- a Postgresql database with the pgrouting extension
- Lizmap 3.5 or above

# Installation


### Automatic installation of files with Composer


* into `lizmap/my-packages`, create the file `composer.json` (if it doesn't exist)
  by copying the file `composer.json.dist`, and install the modules with Composer:

```bash
cp -n lizmap/my-packages/composer.json.dist lizmap/my-packages/composer.json
composer require --working-dir=lizmap/my-packages "lizmap/lizmap-pgrouting-module"
```

### Manual installation of files without Composer

* Get the last ZIP archive in the [repository page](https://projects.3liz.org/lizmap-modules/lizmap-pgrouting-module).
* Extract the archive and copy the `pgrouting` directory in Lizmap Web Client folder `lizmap/lizmap-modules/`
* Edit the config file `lizmap/var/config/localconfig.ini.php` and add into 
  the section `[modules]`:

```ini
pgrouting.access=2
```


### Launching the installer with Lizmap 3.6


If you are using Lizmap 3.6 or higher, execute

```bash
php lizmap/install/configurator.php pgrouting
```

It will ask you all parameters for the database access and the SRID you are using.


* Then, execute Lizmap install scripts into `lizmap/install/` :

```bash
php lizmap/install/installer.php
./lizmap/install/clean_vartmp.sh
./lizmap/install/set_rights.sh
```

### Launching the installer with Lizmap 3.5

* If you are using a SRID other than 2154, edit the config file 
  `lizmap/var/config/localconfig.ini.php` and add into the section `[modules]`:

```ini
pgrouting.installparam="srid=2154"
```
You can replace 2154 by another SRID that you use.

* You need to configure the database access in your Lizmap configuration.
  Add in `lizmap/var/config/profiles.ini.php` the following parameters. 

```ini
[jdb:pgrouting]

driver=pgsql
host=pgsql
port=5432
database=lizmap
user=lizmap
password="yourpassword"
search_path=pgrouting,public
```

**Only replace host, database, user and password values.**

* Then, execute the Lizmap install scripts into `lizmap/install/` :

```bash
php lizmap/install/installer.php
./lizmap/install/clean_vartmp.sh
./lizmap/install/set_rights.sh
```
