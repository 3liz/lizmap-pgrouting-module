#!/bin/bash

# Create user lizmap which will create and own the pgrouting database & schema
psql --username postgres --no-password <<-EOSQL
    CREATE ROLE lizmap WITH LOGIN CREATEDB PASSWORD 'lizmap1234!';
    CREATE DATABASE lizmap WITH OWNER lizmap;
EOSQL

# Create extensions postgis & pgrouting
psql --username postgres --no-password -d lizmap <<-EOSQL
    CREATE EXTENSION IF NOT EXISTS postgis SCHEMA public;
    CREATE EXTENSION IF NOT EXISTS pgrouting SCHEMA public;
EOSQL

# Create another test user and group which must be able to read & write
# data inside the pgrouting schema
psql --username postgres --no-password <<-EOSQL
    CREATE ROLE "gis_user"  WITH LOGIN CREATEDB PASSWORD 'lizmap1234!';
    CREATE ROLE "gis_group";
    GRANT "gis_group" TO "gis_user";
    GRANT CONNECT ON DATABASE "lizmap" TO "gis_user";
EOSQL
