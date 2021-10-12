# Configuration

## Data integration

Once the module is installed, you have to fill the tables with your data, for example from a road table containing linestrings.

* `pgrouting.nodes`: nodes of the routing graph, for example the start and end nodes of the linestrings,
* `pgrouting.edges`: edges of the graph, which mean the links between the nodes, characterized by their source and target nodes,
* `pgrouring.routing_poi`: optional points of interests along the roads (point geometries)

We presented below an example of data import based on the French **IGN BDTopo** road layer loaded in a table `bdtopo.troncon_de_route`.

* The first step is to import the data to your PostgreSQL database. We recommend to use another schema, such as `bdtopo`.
* The second step is to add data in the pgrouting `nodes` and `edges` tables, taken from the source table.

### Import your source data in PostgreSQL

Your source data must be **topological**, which means roads must be cut at each physical intersection and do not overlap other roads.

```mermaid
graph TD;
    A-->B;
    A-->C;
    A-->E;
    B-->D;
    B-->C;
    C-->D;
    C-->E;
    D-->E;
```

You can use `ogr2ogr` to import your data in batch, for example with

```bash
ogr2ogr -progress --config PG_USE_COPY YES -f PostgreSQL PG:'service=lizmap-pgrouting active_schema=bdtopo' -lco DIM=2 -append -lco GEOMETRY_NAME=geom -lco FID=gid -nln bdtopo.troncon_de_route -t_srs EPSG:2154 -nlt PROMOTE_TO_MULTI "TRONCON_DE_ROUTE.shp"
```

In the example above, the `-append` option allows to import several SHP inside the same table if needed. This command will add a `gid` column as the primary key.

Be careful to delete the duplicate geometries, for example when you import data from multiple
source files with overlapping data (such as in the French IGN BDTOPO "département" extracts).
You can use this kind of query to remove the duplicates based on the primary key `gid` and the IGN BDTOPO key `id`:

```sql
DELETE FROM bdtopo.troncon_de_route AS a USING bdtopo.troncon_de_route AS b WHERE a.gid < b.gid AND a.id = b.id;
```

### Import the road data into PgRouting graph (nodes and edges)

Depending on your source layer, you might not have the same field names. Here, `geom` is
the geometry field, `sens` is the direction field, `nom_1_g` is the road name field.

```sql
BEGIN;

-- Copy data from the route source table
-- For example: bdtopo.troncon_de_route
-- to create the temporary edges
-- with added start and end point point geometries.
DROP TABLE IF EXISTS temp_edges;
CREATE TABLE temp_edges AS
WITH source AS (
    SELECT
        -- Stores the original data inside a JSON field
        to_jsonb(t.*) AS raw_data,
        -- Move the geometries nodes to a grid
        ST_SnapToGrid(ST_geometryN(geom, 1), 0.1) AS geom
    -- bdtopo.troncon_de_route is the source road table
    FROM bdtopo.troncon_de_route AS t
    WHERE TRUE
)
SELECT
    source.*,
    -- get the start point
    ST_StartPoint(geom) AS start_point,
    -- get the end point
    ST_EndPoint(geom) AS end_point
FROM source
;
-- Create the needed indexes
CREATE INDEX ON temp_edges USING GIST (geom);
CREATE INDEX ON temp_edges USING GIST (start_point);
CREATE INDEX ON temp_edges USING GIST (end_point);

-- Create the temporary nodes from the start and end points
DROP TABLE IF EXISTS temp_nodes;
CREATE TABLE temp_nodes AS
WITH
union_start_end AS (
    SELECT raw_data->>'id' AS start_of, NULL AS end_of, start_point AS geom
    FROM temp_edges
    UNION ALL
    SELECT NULL AS start_of, raw_data->>'id' AS end_of, end_point AS geom
    FROM temp_edges
),
distinct_nodes AS (
    SELECT
        json_agg(DISTINCT start_of) FILTER (WHERE start_of IS NOT NULL) AS start_of,
        json_agg(DISTINCT end_of) FILTER (WHERE end_of IS NOT NULL) AS end_of,
        geom
    FROM union_start_end
    GROUP BY geom
)
SELECT *
FROM distinct_nodes
;
CREATE INDEX ON temp_nodes USING GIST (geom);

-- Insert them in the pgrouting.nodes table
TRUNCATE pgrouting.nodes RESTART IDENTITY CASCADE;
INSERT INTO pgrouting.nodes (geom)
SELECT geom
FROM temp_nodes
;

-- Insert the temporary edges into the pgrouting.edges table
-- with additional information about nodes, costs, etc.
TRUNCATE pgrouting.edges RESTART IDENTITY CASCADE;
INSERT INTO pgrouting.edges (label, length, source, target, cost, reverse_cost, source_data, geom)
SELECT DISTINCT
    -- label of the edge
    e.raw_data->>'nom_1_g' AS label,
    -- length
    ST_length(e.geom) AS "length",
    -- start and end nodes id
    ns.id, ne.id,
    -- cost based on the length
    CASE
        WHEN e.raw_data->>'sens' in ('Sans objet', 'Double sens', 'Sens direct')
            THEN ST_length(e.geom)
        ELSE -1
    END AS cost,
    -- reverse cost based on the length
    CASE
        WHEN e.raw_data->>'sens' in ('Sans objet', 'Double sens', 'Sens inverse')
            THEN ST_length(e.geom)
        ELSE -1
    END AS reverse_cost,
    -- Keep some useful columns from the source table
    jsonb_build_object(
        'id', e.raw_data->'id', 'nature', e.raw_data->'nature', 'importance', e.raw_data->'importance',
        'etat', e.raw_data->'etat', 'largeur', e.raw_data->'largeur', 'prive', e.raw_data->'prive',
        'sens', e.raw_data->'sens', 'vit_moy_vl', e.raw_data->'vit_moy_vl', 'acces_vl', e.raw_data->'acces_vl'
    ) AS source_data,
    -- geometry. Needed for the astar route engine
    e.geom
FROM temp_edges AS e
LEFT JOIN pgrouting.nodes AS ns
    -- = is faster than ST_Equals
    ON ns.geom = e.start_point
LEFT JOIN pgrouting.nodes AS ne
    ON ne.geom = e.end_point
;

-- Drop the temporary tables
DROP TABLE IF EXISTS temp_nodes;
DROP TABLE IF EXISTS temp_edges;

COMMIT;

-- VACUUM and analyse
VACUUM ANALYSE pgrouting.nodes;
VACUUM ANALYSE pgrouting.edges;

```

### Import data in the POI tables (optional)

Here is an example based on a points of interest layer loaded in a table called `your_schema.point_of_interest`.

This query fill the `pgrouting.routing_poi` table. In the `SELECT` you can replace the fields by
your fields of your point of interest layer.

```sql
INSERT INTO pgrouting.routing_poi (label, type, description, geom)
SELECT poi.label, poi.type, poi.description, poi.geom
FROM your_schema.point_of_interest AS poi;
```

## In QGIS

### Configure the QGIS project

To use the pgrouting module in **Lizmap Web Client** you must first configure
a **QGIS project**:

We offer you [here](../tests/lizmap/instances/pgrouting) a basic project which contains
only the layers required and configured for Lizmap.

If you want create your project or use another existing project to use this module:

* Add the **Edges** and **Nodes** layers
* The QGIS project must be called `pgrouting.qgs`

![pgrouting_layers](media/pgrouting_layers.jpg)

* You must then create a configuration for Lizmap with the **Lizmap plugin**. No specific
  configuration is needed for the module. You can configure like you want or just click on the
  apply button.
