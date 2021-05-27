# Run Lizmap stack with docker-compose

Steps:

- Launch Lizmap with docker-compose
    ```
    make run
    ```

- A simple `pgrouting` project is present but you have to set rights in administration to view it.

- Open your browser at `http://localhost:9090`

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
