CREATE SCHEMA IF NOT EXISTS pgrouting;

-- metadata table
CREATE TABLE IF NOT EXISTS pgrouting.qgis_plugin (
    id integer PRIMARY KEY NOT NULL,
    version text NOT NULL,
    version_date date NOT NULL,
    status smallint NOT NULL
);

COMMENT ON TABLE pgrouting.qgis_plugin IS 'Metadata of the schema structure, related to the version of the QGIS plugin. This is used for scripts to migrate the structure between 2 versions.';

COMMENT ON COLUMN pgrouting.qgis_plugin.id IS 'Unique identifier.';
COMMENT ON COLUMN pgrouting.qgis_plugin.version IS 'Version of the current state of the database structure.';
COMMENT ON COLUMN pgrouting.qgis_plugin.version_date IS 'Date of implementation of the current version of the structure.';
COMMENT ON COLUMN pgrouting.qgis_plugin.status IS 'of the current version.';

INSERT INTO pgrouting.qgis_plugin (id, version, version_date, status)
VALUES (1, '0.2.0', '2021-10-12', 1)
ON CONFLICT (id)
DO UPDATE
SET (version, version_date, status) = (EXCLUDED.version, EXCLUDED.version_date, EXCLUDED.status)
;

-- nodes
CREATE TABLE IF NOT EXISTS pgrouting.nodes(
    id serial primary key,
    geom geometry('POINT', 2154)
);
COMMENT ON TABLE pgrouting.nodes IS 'PgRouging graph nodes';

-- edges
CREATE TABLE IF NOT EXISTS pgrouting.edges(
    id serial PRIMARY key,
    label text,
    length double precision,
    source integer,
    target integer,
    cost double precision,
    reverse_cost double precision,
    source_data jsonb,
    geom geometry('LINESTRING', 2154)
);
COMMENT ON TABLE pgrouting.nodes IS 'PgRouging graph edges, with costs';

-- routing optional POI
CREATE TABLE IF NOT EXISTS pgrouting.routing_poi(
    id serial PRIMARY key,
    label text,
    type text,
    description text,
    geom geometry('POINT', 2154)
);
COMMENT ON TABLE pgrouting.routing_poi IS 'Points of interests (POI) to search around the calculated route.';


-- Adding contraints
ALTER TABLE pgrouting.edges
DROP CONSTRAINT IF EXISTS edges_source_fkey;

ALTER TABLE pgrouting.edges
ADD CONSTRAINT edges_source_fkey FOREIGN KEY (source)
REFERENCES pgrouting.nodes(id);

ALTER TABLE pgrouting.edges
DROP CONSTRAINT IF EXISTS edges_target_fkey;

ALTER TABLE pgrouting.edges
ADD CONSTRAINT edges_target_fkey FOREIGN KEY (target)
REFERENCES pgrouting.nodes(id);

ALTER TABLE pgrouting.edges
DROP CONSTRAINT IF EXISTS edges_route_id_fkey;

--Adding indexes
-- edges
DROP INDEX IF EXISTS pgrouting.edges_geom_idx;
CREATE INDEX edges_geom_idx ON pgrouting.edges USING GIST (geom);
DROP INDEX IF EXISTS pgrouting.edges_source_idx;
CREATE INDEX edges_source_idx ON pgrouting.edges (source);
DROP INDEX IF EXISTS pgrouting.edges_target_idx;
CREATE INDEX edges_target_idx ON pgrouting.edges (target);
DROP INDEX IF EXISTS pgrouting.edges_source_data_idx;
CREATE INDEX edges_source_data_idx ON pgrouting.edges USING GIN (source_data);
-- nodes
DROP INDEX IF EXISTS pgrouting.nodes_geom_idx;
CREATE INDEX nodes_geom_idx ON pgrouting.nodes USING GIST (geom);
-- routing_poi
DROP INDEX IF EXISTS pgrouting.routing_poi_geom_idx;
CREATE INDEX routing_poi_geom_idx ON pgrouting.routing_poi USING GIST (geom);


-- Create Functions

-- Get closer edge id from a given point
DROP FUNCTION IF EXISTS pgrouting.get_closest_edge_id(geometry);
CREATE OR REPLACE FUNCTION pgrouting.get_closest_edge_id(_source_point geometry(POINT, 2154))
RETURNS integer
LANGUAGE 'plpgsql'
AS $BODY$
DECLARE
    edge_id integer;
BEGIN
    -- get closer edges
    -- First test within a small circle 10km to improve performances
    SELECT e.id
        INTO edge_id
    FROM pgrouting.edges e
    WHERE ST_DWithin(_source_point, e.geom, 10000)
    ORDER BY ST_distance(_source_point, e.geom)
    LIMIT 1;
    -- Test without the ST_DWithin to find the closest
    IF edge_id IS NULL THEN
        SELECT e.id
            INTO edge_id
        FROM pgrouting.edges e
        ORDER BY ST_distance(_source_point, e.geom)
        LIMIT 1;
    END IF;

    RETURN edge_id;

END;
$BODY$;
COMMENT ON FUNCTION pgrouting.get_closest_edge_id(geometry)
IS 'Get the closest edge id from a given Point geometry';

-- Function to create temporary edges with the origin and destination points
DROP FUNCTION IF EXISTS pgrouting.create_temporary_edges(text,text,integer);
CREATE OR REPLACE FUNCTION pgrouting.create_temporary_edges(
    point_a text,
    point_b text,
    crs integer
)
RETURNS TABLE(
    id integer,
    source integer,
    target integer,
    cost double precision,
    reverse_cost double precision,
    geom geometry('LINESTRING', 2154),
    ref_edge_id integer,
    label text,
    length double precision
)
LANGUAGE 'plpgsql'
AS $BODY$
DECLARE
    geom_a geometry('POINT', 2154);
    geom_b geometry('POINT', 2154);
    edge_id_a integer;
    edge_id_b integer;
    locate_a double precision;
    locate_b double precision;
    on_the_fly_edge_label text;
  BEGIN

    -- Label of the created edges between start.end points and edges
    on_the_fly_edge_label = 'Accès à la voie';

    -- Make points geom
    geom_a = ST_Transform(ST_GeomFromText(point_a, crs), 2154);
    geom_b = ST_Transform(ST_GeomFromText(point_b, crs), 2154);

    -- Get closes edges
    SELECT pgrouting.get_closest_edge_id(geom_a) INTO edge_id_a;
    SELECT pgrouting.get_closest_edge_id(geom_b) INTO edge_id_b;

    -- calculate line locate point
    SELECT ST_LineLocatePoint(e.geom, geom_a) INTO locate_a FROM pgrouting.edges e WHERE e.id = edge_id_a;
    SELECT ST_LineLocatePoint(e.geom, geom_b) INTO locate_b FROM pgrouting.edges e WHERE e.id = edge_id_b;

    -- Create all temporary edges
    RETURN query
    WITH
    -- get edge
    edge_a AS (
        SELECT *
        FROM pgrouting.edges e
        WHERE e.id = edge_id_a
        LIMIT 1
    ),
    edge_b AS (
        SELECT *
        FROM pgrouting.edges e
        WHERE e.id = edge_id_b
        LIMIT 1
    ),
    -- Create start segment to access at the first segment
    edge_start AS(
        SELECT
            -6 as id, -4 as source, -3 as target,
            st_length(ST_MakeLine(geom_a, ST_endpoint(ST_lineSubstring(e.geom, 0, locate_a)))) as cost,
            -1 as reverse_cost,
            ST_MakeLine(geom_a, ST_endpoint(ST_lineSubstring(e.geom, 0, locate_a))) as geom,
            edge_id_a as ref_edge_id,
            on_the_fly_edge_label AS label
        FROM edge_a AS e
    ),
    -- division of the first segment into two
    edge_a_1 AS (
        SELECT
            -5 as id, e.source as source, -3 as target,
            CASE WHEN e.cost <> -1 THEN
                ST_length(ST_lineSubstring(e.geom, 0, locate_a))
                ELSE -1
            END as cost,
            CASE WHEN e.reverse_cost <> -1 THEN
                ST_length(ST_lineSubstring(e.geom, 0, locate_a))
                ELSE -1
            END as reverse_cost,
            ST_lineSubstring(e.geom, 0, locate_a) as geom,
            edge_id_a as ref_edge_id,
            e.label AS label
        FROM edge_a AS e
    ),
    edge_a_2 AS (
        SELECT
            -4 as id, -3 as source, e.target as target,
            CASE WHEN e.cost <> -1 THEN
                ST_length(ST_lineSubstring(e.geom, locate_a, 1))
                ELSE -1
            END as cost,
            CASE WHEN e.reverse_cost <> -1 THEN
                ST_length(ST_lineSubstring(e.geom, locate_a, 1))
                ELSE -1
            END as reverse_cost,
            ST_lineSubstring(e.geom, locate_a, 1) as geom,
            edge_id_a as ref_edge_id,
            e.label AS label
        FROM edge_a AS e
    ),
    -- division of the last segment into two
    edge_b_1 AS (
        SELECT
            -3 as id, e.source as source, -2 as target,
            CASE WHEN e.cost <> -1 THEN
                ST_length(ST_lineSubstring(e.geom, 0, locate_b))
                ELSE -1
            END as cost,
            CASE WHEN e.reverse_cost <> -1 THEN
                ST_length(ST_lineSubstring(e.geom, 0, locate_b))
                ELSE -1
            END as reverse_cost,
            ST_lineSubstring(e.geom, 0, locate_b) as geom,
            edge_id_b as ref_edge_id,
            e.label AS label
        FROM edge_b AS e
    ),
    edge_b_2 AS (
        SELECT
            -2 as id, -2 as source, e.target as target,
            CASE WHEN e.cost <> -1 THEN
                ST_length(ST_lineSubstring(e.geom, locate_b, 1))
                ELSE -1
            END as cost,
            CASE WHEN e.reverse_cost <> -1 THEN
                ST_length(ST_lineSubstring(e.geom, locate_b, 1))
                ELSE -1
            END as reverse_cost,
            ST_lineSubstring(e.geom, locate_b, 1) as geom,
            edge_id_b as ref_edge_id,
            e.label AS label
        FROM edge_b AS e
    ),
    -- Create end segment
    edge_end AS(
        SELECT
            -1 as id, -2 as source, -1 as target,
            st_length(st_makeline(geom_b,ST_endpoint(ST_lineSubstring(e.geom, 0, locate_b)))) as cost,
            -1 as reverse_cost,
            st_makeline(geom_b,ST_endpoint(ST_lineSubstring(e.geom, 0, locate_b))) as geom,
            edge_id_b as ref_edge_id,
            on_the_fly_edge_label AS label
        FROM edge_b AS e
    ),
    union_all AS (
        SELECT *
        FROM edge_start e
        UNION ALL
        SELECT *
        FROM edge_a_1 e
        UNION ALL
        SELECT *
        FROM edge_a_2 e
        UNION ALL
        SELECT *
        FROM edge_b_1 e
        UNION ALL
        SELECT *
        FROM edge_b_2 e
        UNION ALL
        SELECT *
        FROM edge_end e
    )
    SELECT
        e.id, e.source, e.target,
        e.cost, e.reverse_cost,
        e.geom, e.ref_edge_id,
        e.label, ST_Length(e.geom) AS length
    FROM union_all AS e
    ;

  END;
$BODY$;
COMMENT ON FUNCTION pgrouting.create_temporary_edges(text,text,integer)
IS 'Function to create temporary edges with the origin and destination points';


-- Function to generate pgrouting alg query
DROP FUNCTION IF EXISTS pgrouting.route_request(text,text,integer,text);
CREATE OR REPLACE FUNCTION pgrouting.route_request(
    point_a text,
    point_b text,
    crs integer,
    engine text
)
RETURNS text
LANGUAGE 'plpgsql'
AS $BODY$
DECLARE
    geom_a geometry('POINT', 2154);
    geom_b geometry('POINT', 2154);
    edge_id_a integer;
    edge_id_b integer;
    edge_query text;
  BEGIN

    -- Make points geom
    geom_a = ST_Transform(ST_GeomFromText(point_a, crs), 2154);
    geom_b = ST_Transform(ST_GeomFromText(point_b, crs), 2154);

    -- get closer edges
    SELECT pgrouting.get_closest_edge_id(geom_a) INTO edge_id_a;
    SELECT pgrouting.get_closest_edge_id(geom_b) INTO edge_id_b;

    -- request to get all edges in buffer around the points
    IF engine = 'dijkstra' THEN
        edge_query = CONCAT('
        SELECT d.id, d.source, d.target, d.cost, d.reverse_cost
        FROM pgrouting.create_temporary_edges(''',point_a,''',''',point_b,''',',crs,') AS d
        UNION ALL
        SELECT e.id, e.source, e.target, e.cost, e.reverse_cost
        FROM pgrouting.edges e
        WHERE True
        AND e.id NOT IN (', edge_id_a::text,',', edge_id_b::text,')
        AND ST_intersects(ST_Buffer(ST_Envelope(ST_Collect(''',geom_a::text,''',''',geom_b::text,''')), 10000), e.geom);');
    ELSIF engine = 'astar' THEN
        edge_query = CONCAT('
        SELECT d.id, d.source, d.target, d.cost, d.reverse_cost,
            ST_XMin(d.geom) as x1, ST_YMin(d.geom) as y1,
            ST_XMax(d.geom) as x2, ST_YMax(d.geom) as y2
        FROM pgrouting.create_temporary_edges(''',point_a,''',''',point_b,''',',crs,') AS d
        UNION ALL
        SELECT e.id, e.source, e.target, e.cost, e.reverse_cost,
            ST_XMin(e.geom) as x1, ST_YMin(e.geom) as y1,
            ST_XMax(e.geom) as x2, ST_YMax(e.geom) as y2
        FROM pgrouting.edges e
        WHERE e.id NOT IN (', edge_id_a::text,',', edge_id_b::text,')
        AND ST_intersects(ST_Buffer(ST_Envelope(ST_Collect(''',geom_a::text,''',''',geom_b::text,''')), 10000), e.geom);');
    END IF;

    RETURN edge_query;
  END;
$BODY$;
COMMENT ON FUNCTION pgrouting.route_request(text,text,integer,text)
IS 'Generates the query gathering the edges and costs to pass to the PgRouting algorithms. It also creates the temporary edges between the source/destination given points and the closest edges.';

-- FUnction to choose the pgrouting
DROP FUNCTION IF EXISTS pgrouting.routing_alg(text,text,integer,text);
CREATE OR REPLACE FUNCTION pgrouting.routing_alg(
    point_a text, point_b text, crs integer, engine text
)
RETURNS TABLE (
    seq integer,
    path_seq integer,
    node bigint,
    edge bigint,
    cost double precision,
    agg_cost double precision
)
LANGUAGE 'plpgsql'
AS $BODY$
DECLARE
BEGIN
    IF engine = 'dijkstra' THEN
        RETURN QUERY SELECT *
        FROM pgr_dijkstra(
            (SELECT pgrouting.route_request(point_a, point_b, crs, engine)), -4, -1, FALSE
        );
    ELSIF engine = 'astar' THEN
        RETURN QUERY SELECT *
        FROM pgr_astar(
            (SELECT pgrouting.route_request(point_a, point_b, crs, engine)), -4, -1, FALSE
        );
    END IF;
END;
$BODY$;
COMMENT ON FUNCTION pgrouting.routing_alg(text,text,integer,text)
IS 'Selects the PgRouting engine based on a parameter. At present: pgr_dijkstra or pgr_astar';

-- Function to make the RoadMap
DROP FUNCTION IF EXISTS pgrouting.create_roadmap(text,text,integer,text);
CREATE OR REPLACE FUNCTION pgrouting.create_roadmap(
    point_a text,
    point_b text,
    crs integer,
    engine text
)
RETURNS TABLE (
    seq integer,
    edge bigint,
    geom geometry('LINESTRING', 4326),
    label text,
    dist double precision,
    cost double precision,
    agg_cost double precision
)
LANGUAGE 'plpgsql'
AS $BODY$
DECLARE
BEGIN
    RETURN QUERY
    WITH
    -- First get route from pgrouting alg
    -- Needed to then JOIN the edges
    routing AS (
        SELECT * FROM pgrouting.routing_alg(point_a, point_b, crs, engine)
    ),
    route_edges AS
    (
        -- Edges from the table
        SELECT
            r.seq, r.edge, r.agg_cost,
            e.id, e.source, e.target, e.cost, e.reverse_cost, e.geom,
            e.label, e.length
        FROM pgrouting.edges AS e
        JOIN routing AS r
            ON r.edge = e.id AND node <> -1
        -- UNION
        UNION ALL
        -- Temporary edges from the start and end points
        SELECT
            r.seq, r.edge, r.agg_cost,
            te.id, te.source, te.target, te.cost, te.reverse_cost, te.geom,
            te.label, te.length
        FROM pgrouting.create_temporary_edges(
                point_a, point_b, crs
        ) AS te
        JOIN routing AS r
            ON r.edge = te.id AND node <> -1
    )
    SELECT
        re.seq, re.edge, ST_Transform(re.geom, 4326) AS geom,
        re.label, re.length, re.cost, re.agg_cost
    FROM route_edges AS re
    ORDER BY re.seq;

END;
$BODY$;
COMMENT ON FUNCTION pgrouting.create_roadmap(text,text,integer,text)
IS 'Returns the geometries, labels, calculated costs and aggregated costs of all the linestrings of the resulting route.';

-- Function to get roadmap in GeoJson
DROP FUNCTION IF EXISTS pgrouting.get_geojson_roadmap(text, text, integer,text);
CREATE OR REPLACE FUNCTION pgrouting.get_geojson_roadmap(
    point_a text,
    point_b text,
    crs integer,
    engine text
)
RETURNS TABLE(
    routing json,
    poi json
)
LANGUAGE 'plpgsql'
AS $BODY$
DECLARE
    geojson text;
BEGIN

    RETURN QUERY
    WITH source AS (
        SELECT "seq", "edge", "geom", "label", "dist", "cost", "agg_cost"
        FROM pgrouting.create_roadmap(point_a,point_b, crs, engine)
    ),
    extent as (
        SELECT ST_Extent(ST_Union(ARRAY(SELECT geom FROM source))) AS bbox
    ),
    fc as (
        SELECT
        'FeatureCollection' As type,
        -- ST_AsGeoJSON(ST_Union(ARRAY(SELECT geom FROM source)))::json AS total_path,
        (select array[ST_XMin(bbox) , ST_YMin(bbox), ST_XMax(bbox), ST_YMax(bbox)] from extent) AS bbox,
        json_build_object(
            'total_length', (SELECT SUM( dist) FROM source),
            'total_cost', (SELECT SUM( cost) FROM source)
        ) AS routing,
        array_to_json(array_agg(f)) As features
        -- SELECT row_to_json(f, True) AS geojson
        FROM (
            SELECT
                'Feature' AS type,
                Concat(
                    'pgrouting',
                    '.',
                    "seq") AS id,
                ST_AsGeoJSON(lg.geom)::json As geometry,
                row_to_json(
                    ( SELECT l FROM
                        (
                            SELECT "seq", "edge", "label", "dist", "cost", "agg_cost"
                        ) As l
                    )
                ) As properties
            FROM source As lg
        ) AS f
    ),
    point_interest as (
        SELECT
        'FeatureCollection' As type,
        array_to_json(array_agg(f)) As features
        FROM (
            SELECT
                'Feature' AS type,
                Concat(
                    'poi',
                    '.',
                    "id") AS id,
                ST_AsGeoJSON(ST_Transform(lg.geom, 4326))::json As geometry,
                row_to_json(
                    ( SELECT l FROM
                        (
                            SELECT MIN(s.seq) AS seq, lg.id, lg.label, lg.type, lg.description
                        ) As l
                    )
                ) As properties
            FROM pgrouting.routing_poi As lg
            JOIN source as s
                ON ST_DWithin(ST_Transform(s.geom, 2154), lg.geom, 1)
            GROUP BY s.seq, lg.id, lg.label, lg.type, lg.description
            ORDER BY s.seq
        ) AS f
    )

    SELECT row_to_json(fc, True) as routing, row_to_json(point_interest, True) as poi
    FROM fc, point_interest;
    END;
$BODY$;
COMMENT ON FUNCTION pgrouting.get_geojson_roadmap(text, text, integer,text)
IS 'Returns a complete GeoJSON with all the geometries, labels, calculated costs and aggregated costs of all the linestrings of the resulting route.
It also contains the nearby found Points of interests.';
