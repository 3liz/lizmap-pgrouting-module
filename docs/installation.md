# requirements

* a PostgreSQL database with the **postgis** and **pgrouting** extensions installed
* Lizmap Web Client 3.5 or above

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
* Extract the archive and copy the `pgrouting` directory (the one containing the `module.xml` file) into the Lizmap Web Client folder `lizmap/lizmap-modules/`
* With **Lizmap 3.5** or lower: edit the config file `lizmap/var/config/localconfig.ini.php` and add into
  the section `[modules]`:

```ini
pgrouting.access=2
```


### Launching the installer with Lizmap Web Client 3.6/3.7

Use following instructions if you are using Lizmap Web Client **3.6 or higher**.

First you need to configure the database access in your Lizmap configuration.
Add in `lizmap/var/config/profiles.ini.php` the following parameters, by replacing values with your own credentials.
**Only replace host, database, user and password values.**


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

Then execute:

```bash
php lizmap/install/configurator.php pgrouting
```

It will install some files, and ask you some parameters:

* The **SRID** (code of spatial coordinate system). It must correspond to the projection of your source data
  and will be used for the tables created by the module. Default is 2154 (French official code)
* The name of the **PostgreSQL role** that need to be granted with write access on the tables
  in the PostgreSQL schema `pgrouting` (that will be created by the module installation
  script).

  
Then, execute Lizmap install scripts into `lizmap/install/` :

```bash
php lizmap/install/installer.php
./lizmap/install/clean_vartmp.sh
./lizmap/install/set_rights.sh
```

A new schema `pgrouting` must be visible in your PostgreSQL database, containing the needed
tables and functions used by the module.

### Launching the installer with Lizmap 3.5

If you are using Lizmap Web Client **3.5**, you must manually edit the configuration
file of your instance to specify some options. Edit the file `lizmap/var/config/localconfig.ini.php`
and add the following variable in the section `[modules]`:

```ini
pgrouting.installparam="srid=2154;postgresql_user_group=gis_group"
```

You can replace:

* `2154` by another SRID that you use. It must correspond to the projection of your source data.
* `gis_group` must be replaced by the name of the **PostgreSQL role** that need to be granted with write
  access on the tables in the PostgreSQL schema `pgrouting` (that will be created by the module installation
  script).

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
