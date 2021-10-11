# Run Lizmap stack with docker-compose

Steps:

- Launch Lizmap with docker-compose
    ```
    make run
    ```

- A simple `pgrouting` project is present but you have to set rights in administration to view it.

- Open your browser at `http://localhost:9090`

For more information, refer to the [docker-compose documentation](https://docs.docker.com/compose/)

## Access to the dockerized PostgreSQL instance

You can access the database by configuring a [service file](https://docs.qgis.org/3.16/fr/docs/user_manual/managing_data_source/opening_data.html#postgresql-service-connection-file). The service file can be stored in your user home `~/.pg_service.conf` and should contains this section

```ini
[lizmap-pgrouting]
dbname=lizmap
host=pgsql
user=lizmap
password=lizmap1234!
```

Then you can use any PostgreSQL client (psql, QGIS, PgAdmin, DBeaver) and use the `service` instead of the other credentials (host, port, dabase name, user and password).

```bash
psql service=lizmap-pgrouting
```

## SQL Tests

To run SQL based tests, you need to call `pytest` :

```bash
# In a venv, it's better, but this is out of scope
pip install -r requirements/tests.txt
cd tests/sql
pytest
pytest -s -v
```

You must have set some environment variables for the database to use (either local or in docker) :

The CI will test against Docker images PostGIS 2 and 3 : `3liz/postgis:13-2.5` and `3liz/postgis:13-3`.

```bash
docker run --rm -e POSTGRES_PASSWORD=docker -e POSTGRES_USER=docker -e POSTGRES_DB=gis -p 127.0.0.1:35432:5432 3liz/postgis:13-2.5
cd tests/sql
POSTGRES_DB=gis POSTGRES_USER=docker POSTGRES_PASSWORD=docker POSTGRES_PORT=35432 pytest -v
```
