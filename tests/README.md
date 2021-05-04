# Run Lizmap stack with docker-compose

Just do:

```
make run
```

Then add `pgrouting.access=2` in `[modules]` section of `lizmap/var/lizmap-config/localconfig.ini.php`

Stop execution then `make run` again to launch module installer.

Open your browser at `http://localhost:9090`

For more informations, refer to the [docker-compose documentation](https://docs.docker.com/compose/)
