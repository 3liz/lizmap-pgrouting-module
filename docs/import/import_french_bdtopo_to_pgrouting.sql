BEGIN;

-- Copy data from the route source table
-- bdtopo.troncon_de_route
-- to create the temporary edges
-- with added start and end point point geometries.
DROP TABLE IF EXISTS temp_edges;
CREATE TABLE temp_edges AS
WITH source AS (
    SELECT
        to_jsonb(t.*) AS raw_data,
        ST_SnapToGrid(ST_geometryN(geom, 1), 0.1) AS geom
    FROM bdtopo.troncon_de_route AS t
    WHERE TRUE
)
SELECT
    source.*,
    ST_StartPoint(geom) AS start_point,
    ST_EndPoint(geom) AS end_point
FROM source
;
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
