# Run Lizmap stack with docker-compose

Steps:

- Launch Lizmap with docker-compose

```bash
# Clean previous versions (optional)
make clean

# Run the different services
make run

```

- call these commands if you are using Lizmap <=3.5

```bash
make import-lizmap-acl-3-5
```

- else call these commands if you are using Lizmap >=3.6

```bash
# install the module (for Lizmap 3.6+)
make install-module

make import-lizmap-acl
```

- import data

```bash
make import-data
```

- Open your browser at http://localhost:9090

For more information, refer to the [docker-compose documentation](https://docs.docker.com/compose/)

## Access to the dockerized PostgreSQL instance

You can access the docker PostgreSQL test database `lizmap` from your host by configuring a
[service file](https://docs.qgis.org/latest/en/docs/user_manual/managing_data_source/opening_data.html#postgresql-service-connection-file).
The service file can be stored in your user home `~/.pg_service.conf` and should contain this section

```ini
[lizmap-pgrouting]
dbname=lizmap
host=localhost
port=9032
user=lizmap
password=lizmap1234!
```

Then you can use any PostgreSQL client (psql, QGIS, PgAdmin, DBeaver) and use the `service`
instead of the other credentials (host, port, database name, user and password).

```bash
psql service=lizmap-pgrouting
```

## SQL Tests

### Docker

Inside the docker compose project :

```bash
docker compose run --rm pytest
```

### Local

To run SQL based tests, you need to call `pytest` :

```bash
# In a venv, it's better, but this is out of scope
pip install -r requirements/tests.txt
cd tests/sql
pytest
pytest -s -v
```

```bash
POSTGRES_DB=lizmap POSTGRES_USER=lizmap POSTGRES_PASSWORD=lizmap1234! POSTGRES_PORT=9032 pytest -s -v
```

or

```bash
docker run --rm -e POSTGRES_PASSWORD=docker -e POSTGRES_USER=docker -e POSTGRES_DB=gis -p 127.0.0.1:35432:5432 3liz/postgis:13-2.5
cd tests/sql
POSTGRES_DB=gis POSTGRES_USER=docker POSTGRES_PASSWORD=docker POSTGRES_PORT=35432 pytest -v
```
