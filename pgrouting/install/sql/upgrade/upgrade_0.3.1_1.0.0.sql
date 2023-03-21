

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
            ST_Reverse(ST_lineSubstring(e.geom, 0, locate_a)) as geom,
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
            ST_Reverse(ST_lineSubstring(e.geom, locate_b, 1)) as geom,
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
            st_makeline(ST_endpoint(ST_lineSubstring(e.geom, 0, locate_b)), geom_b) as geom,
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
        RETURN QUERY SELECT
            d.seq, d.path_seq, d.node, d.edge, d.cost, d.agg_cost
        FROM pgr_dijkstra(
            (SELECT pgrouting.route_request(point_a, point_b, crs, engine)), -4, -1, FALSE
        ) AS d;
    ELSIF engine = 'astar' THEN
        RETURN QUERY SELECT
            a.seq, a.path_seq, a.node, a.edge, a.cost, a.agg_cost
        FROM pgr_astar(
            (SELECT pgrouting.route_request(point_a, point_b, crs, engine)), -4, -1, FALSE
        ) AS a;
    END IF;
END;
$BODY$;
COMMENT ON FUNCTION pgrouting.routing_alg(text,text,integer,text)
IS 'Selects the PgRouting engine based on a parameter. At present: pgr_dijkstra or pgr_astar';


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
            e.id, e.source, e.target, e.cost, e.reverse_cost,
            -- adjusting directionality
            CASE
                WHEN node = e.source THEN e.geom
                ELSE ST_Reverse(e.geom)
            END AS geom,
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
