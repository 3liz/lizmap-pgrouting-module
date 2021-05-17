# Run Lizmap stack with docker-compose

Steps:

```
make run
```

Add `pgrouting.access=2` and `pgrouting.installparam="srid=2154"` in `[modules]` section of `lizmap/var/lizmap-config/localconfig.ini.php`

Add in `lizmap/var/lizmap-config/profiles.ini.php`

```ini
[jdb:pgrouting]

driver=pgsql
host=pgsql
database=lizmap
user=lizmap
password="lizmap1234!"
search_path=pgrouting,public
```

Stop execution then `make run` again to launch module installer.

Open your browser at `http://localhost:9090`

For more informations, refer to the [docker-compose documentation](https://docs.docker.com/compose/)
