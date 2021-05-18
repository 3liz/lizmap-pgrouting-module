# Run Lizmap stack with docker-compose

Steps:

```
make run
```

Add in `[modules]` section of `lizmap/var/lizmap-config/localconfig.ini.php`

```ini
pgrouting.access=2
pgrouting.installparam="srid=2154"
```

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

For more information, refer to the [docker-compose documentation](https://docs.docker.com/compose/)

## SQL Tests

To run SQL based tests, you need to call `unitest` :

```bash
cd tests/sql
python -m unittest -v
```

You must have set some environment variables for the database to use (either local or in docker) :

```bash
docker run --rm -e POSTGRES_PASSWORD=docker -e POSTGRES_USER=docker -e POSTGRES_DB=gis -p 127.0.0.1:35432:5432 3liz/postgis:13-2.5
cd tests/sql
POSTGRES_DB=gis POSTGRES_USER=docker POSTGRES_PASSWORD=docker POSTGRES_PORT=35432 python -m unittest -v
```
