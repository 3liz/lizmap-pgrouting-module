CREATE SCHEMA IF NOT EXISTS pgrouting;

CREATE TABLE IF NOT EXISTS pgrouting.nodes(
    id serial primary key,
    geom geometry('POINT', {$srid})
);

CREATE TABLE IF NOT EXISTS pgrouting.edges(
    id serial PRIMARY key,
    source integer,
    target integer,
    cost double precision,
    reverse_cost double precision,
    geom geometry('LINESTRING', {$srid})
);

CREATE TABLE IF NOT EXISTS pgrouting.routing_poi(
    id serial PRIMARY key,
    label text,
    type text,
    description text,
    geom geometry('POINT', {$srid})
);

-- Adding constarints

CREATE TABLE IF NOT EXISTS pgrouting.edges_info(
id integer PRIMARY KEY,
label text,
length double precision
);

ALTER TABLE pgrouting.edges_info
DROP CONSTRAINT IF EXISTS edges_id_fkey;

ALTER TABLE pgrouting.edges_info
ADD CONSTRAINT edges_id_fkey FOREIGN KEY (id)
REFERENCES pgrouting.edges(id);


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

--Adding spatial index

DROP INDEX IF EXISTS edges_index_spatial;
CREATE INDEX edges_index_spatial
  ON pgrouting.edges
  USING GIST (geom);

DROP INDEX IF EXISTS nodes_index_spatial;
CREATE INDEX nodes_index_spatial
  ON pgrouting.nodes
  USING GIST (geom);

DROP INDEX IF EXISTS routing_poi_index_spatial;
CREATE INDEX routing_poi_index_spatial
  ON pgrouting.routing_poi
  USING GIST (geom);

-- Create Functions

-- Fonction de création de nodes
DROP FUNCTION IF EXISTS pgrouting.create_node(geometry);
CREATE OR REPLACE FUNCTION pgrouting.create_node(
	geom_val geometry('POINT', {$srid}))
    RETURNS integer
    LANGUAGE 'plpgsql'

    COST 100
    VOLATILE 
AS $BODY$
DECLARE
	id_val integer;
  BEGIN
	
	SELECT id into id_val FROM pgrouting.nodes WHERE ST_DWithin(geom, geom_val, 0.001);
	
	IF id_val IS NULL THEN 
		INSERT INTO pgrouting.nodes(geom)
			values(geom_val)
		RETURNING id INTO id_val;
	END IF;
   	RETURN id_val;
  END;
$BODY$;

-- Fonction de création des edges
DROP FUNCTION IF EXISTS pgrouting.create_edge(geometry, double precision, double precision);
CREATE OR REPLACE FUNCTION pgrouting.create_edge(
	geom_val geometry('LINESTRING', {$srid}), cost_val double precision, reverse_cost_val double precision)
    RETURNS integer
    LANGUAGE 'plpgsql'

    COST 100
    VOLATILE 
AS $BODY$
DECLARE
    id_val integer;
  BEGIN
	
	SELECT id into id_val FROM pgrouting.edges 
	WHERE ST_DWithin(ST_StartPoint(geom), ST_StartPoint(geom_val), 0.001)
    AND ST_DWithin(ST_EndPoint(geom), ST_EndPoint(geom_val), 0.001)
    AND ST_Contains(ST_BUFFER(geom, 0.01), geom_val);
	
	IF id_val IS NULL THEN 
		INSERT INTO pgrouting.edges(geom,source,target,cost,reverse_cost)
		VALUES(
			geom_val,
			(select pgrouting.create_node(st_startpoint(geom_val))),
			(select pgrouting.create_node(st_endpoint(geom_val))),
			cost_val,
			reverse_cost_val
		) RETURNING id INTO id_val;
	ELSE
		UPDATE pgrouting.edges
		SET cost = cost_val, reverse_cost = reverse_cost_val
		WHERE id = id_val;
	END IF;
	RETURN id_val;
  END;
$BODY$;

-- Fonction de création des edges temporaires à partir de A et B
DROP FUNCTION IF EXISTS pgrouting.create_temporary_edges(text,text,integer);
CREATE OR REPLACE FUNCTION pgrouting.create_temporary_edges(
	point_a text,
	point_b text,
	crs integer)
    RETURNS TABLE(id integer, source integer, target integer, cost double precision, reverse_cost double precision, geom geometry('LINESTRING', {$srid}), ref_edge_id integer) 
    LANGUAGE 'plpgsql'

    COST 100
    VOLATILE 
    ROWS 1000
AS $BODY$
DECLARE
	geom_a geometry('POINT', {$srid});
	geom_b geometry('POINT', {$srid});
	edge_id_a integer;
	edge_id_b integer;
	locate_a double precision;
	locate_b double precision;
  BEGIN
  
  	-- Make points geom
	geom_a = ST_Transform(ST_GeomFromText(point_a, crs), {$srid});
	geom_b = ST_Transform(ST_GeomFromText(point_b, crs), {$srid});

	-- get closer edges
	SELECT e.id into edge_id_a FROM pgrouting.edges e ORDER BY ST_distance(geom_a, e.geom) LIMIT 1;
	SELECT e.id into edge_id_b FROM pgrouting.edges e ORDER BY ST_distance(geom_b, e.geom) LIMIT 1;

	-- calculate line locate point
	SELECT ST_LineLocatePoint(e.geom, geom_a) into locate_a FROM pgrouting.edges e where e.id = edge_id_a;
	SELECT ST_LineLocatePoint(e.geom, geom_b) into locate_b FROM pgrouting.edges e where e.id = edge_id_b;

	-- Create all temporary edges
	return query WITH
	-- Create start segment to access at the first segment
	edge_start AS(
		SELECT -6 as id, -4 as source, -3 as target,
		st_length(st_makeline(geom_a,ST_endpoint(ST_lineSubstring(e.geom, 0, locate_a)))) as cost,
		-1 as reverse_cost,
		st_makeline(geom_a,ST_endpoint(ST_lineSubstring(e.geom, 0, locate_a))) as geom,
		edge_id_a as ref_edge_id
		FROM pgrouting.edges e
		WHERE e.id= edge_id_a
	),
	-- division of the first segment into two
	edge_a_1 AS (
		SELECT -5 as id, e.source as source, -3 as target,
			CASE WHEN e.cost <> -1 THEN
				ST_length(ST_lineSubstring(e.geom, 0, locate_a))
				ELSE -1
			END as cost,
			CASE WHEN e.reverse_cost <> -1 THEN
				ST_length(ST_lineSubstring(e.geom, 0, locate_a))
				ELSE -1
			END as reverse_cost,
			ST_lineSubstring(e.geom, 0, locate_a) as geom,
			edge_id_a as ref_edge_id
		FROM pgrouting.edges e
		WHERE e.id= edge_id_a
	),
	edge_a_2 AS (
		SELECT -4 as id, -3 as source, e.target as target,
			CASE WHEN e.cost <> -1 THEN
				ST_length(ST_lineSubstring(e.geom, locate_a, 1))
				ELSE -1
			END as cost,
			CASE WHEN e.reverse_cost <> -1 THEN
				ST_length(ST_lineSubstring(e.geom, locate_a, 1))
				ELSE -1
			END as reverse_cost,
			ST_lineSubstring(e.geom, locate_a, 1) as geom,
			edge_id_a as ref_edge_id
		FROM pgrouting.edges e
		WHERE e.id=edge_id_a
	),
	-- division of the last segment into two
	edge_b_1 AS (
		SELECT -3 as id, e.source as source, -2 as target,
			CASE WHEN e.cost <> -1 THEN
				ST_length(ST_lineSubstring(e.geom, 0, locate_b))
				ELSE -1
			END as cost,
			CASE WHEN e.reverse_cost <> -1 THEN
				ST_length(ST_lineSubstring(e.geom, 0, locate_b))
				ELSE -1
			END as reverse_cost,
		ST_lineSubstring(e.geom, 0, locate_b) as geom,
		edge_id_b as ref_edge_id
		FROM pgrouting.edges e
		WHERE e.id=edge_id_b
	),
	edge_b_2 AS (
		SELECT -2 as id, -2 as source, e.target as target,
			CASE WHEN e.cost <> -1 THEN
				ST_length(ST_lineSubstring(e.geom, locate_b, 1))
				ELSE -1
			END as cost,
			CASE WHEN e.reverse_cost <> -1 THEN
				ST_length(ST_lineSubstring(e.geom, locate_b, 1))
				ELSE -1
			END as reverse_cost,
			ST_lineSubstring(e.geom, locate_b, 1) as geom,
			edge_id_b as ref_edge_id
		FROM pgrouting.edges e
		WHERE e.id=edge_id_b
	),
	-- Create end segment
	edge_end AS(
		SELECT -1 as id, -2 as source, -1 as target,
		st_length(st_makeline(geom_b,ST_endpoint(ST_lineSubstring(e.geom, 0, locate_b)))) as cost,
		-1 as reverse_cost,
		st_makeline(geom_b,ST_endpoint(ST_lineSubstring(e.geom, 0, locate_b))) as geom,
		edge_id_b as ref_edge_id
		FROM pgrouting.edges e
		WHERE e.id= edge_id_b
	)
	SELECT e.id, e.source, e.target, e.cost, e.reverse_cost, e.geom, e.ref_edge_id FROM edge_start e
	UNION ALL
	SELECT e.id, e.source, e.target, e.cost, e.reverse_cost, e.geom, e.ref_edge_id FROM edge_a_1 e
	UNION ALL 
	SELECT e.id, e.source, e.target, e.cost, e.reverse_cost, e.geom, e.ref_edge_id FROM edge_a_2 e
	UNION ALL 
	SELECT e.id, e.source, e.target, e.cost, e.reverse_cost, e.geom, e.ref_edge_id FROM edge_b_1 e
	UNION ALL 
	SELECT e.id, e.source, e.target, e.cost, e.reverse_cost, e.geom, e.ref_edge_id FROM edge_b_2 e
	UNION ALL 
	SELECT e.id, e.source, e.target, e.cost, e.reverse_cost, e.geom, e.ref_edge_id FROM edge_end e;
  END;
$BODY$;

-- Fonction de création de la requête
DROP FUNCTION IF EXISTS pgrouting.route_request(text,text,integer,text);
CREATE OR REPLACE FUNCTION pgrouting.route_request(
	point_a text, point_b text, crs integer, opt text)
    RETURNS text
    LANGUAGE 'plpgsql'

    COST 100
    VOLATILE 
AS $BODY$
DECLARE
	geom_a geometry('POINT', {$srid});
	geom_b geometry('POINT', {$srid});
	edge_id_a integer;
	edge_id_b integer;
	edge_query text;
  BEGIN
	
	-- Make points geom
	geom_a = ST_Transform(ST_GeomFromText(point_a, crs), {$srid});
	geom_b = ST_Transform(ST_GeomFromText(point_b, crs), {$srid});
	
	-- get closer edges
	SELECT e.id into edge_id_a FROM pgrouting.edges e ORDER BY ST_distance(geom_a, e.geom) LIMIT 1;
	SELECT e.id into edge_id_b FROM pgrouting.edges e ORDER BY ST_distance(geom_b, e.geom) LIMIT 1;
	
	-- request to get all edges in buffer around the points
	IF opt = 'dijkstra' THEN
		edge_query = CONCAT('
		SELECT d.id, d.source, d.target, d.cost, d.reverse_cost
		FROM pgrouting.create_temporary_edges(''',point_a,''',''',point_b,''',',crs,') AS d
		UNION ALL
		SELECT e.id, e.source, e.target, e.cost, e.reverse_cost
		FROM pgrouting.edges e
		WHERE e.id NOT IN (', edge_id_a::text,',', edge_id_b::text,') 
		AND ST_intersects(ST_Buffer(ST_Envelope(ST_Collect(''',geom_a::text,''',''',geom_b::text,''')), 1000), e.geom);');
	ELSIF opt = 'astar' THEN
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
		AND ST_intersects(ST_Buffer(ST_Envelope(ST_Collect(''',geom_a::text,''',''',geom_b::text,''')), 1000), e.geom);');
	END IF;
  
	RETURN edge_query;
  END;
$BODY$;

-- Fonction de la RoadMap
DROP FUNCTION IF EXISTS pgrouting.create_roadmap(text,text,integer,text);
CREATE OR REPLACE FUNCTION pgrouting.create_roadmap(
	point_a text, point_b text, crs integer, opt text)
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

    COST 100
    VOLATILE 
AS $BODY$
DECLARE
BEGIN
	RETURN QUERY WITH edges AS(
		SELECT e.*, ei.label, ei.length 
		FROM pgrouting.edges e, pgrouting.edges_info ei
		WHERE e.id=ei.id
		UNION ALL 
		SELECT te.id, te.source, te.target, te.cost, te.reverse_cost, te.geom,
		CASE 
			WHEN te.id = -6 OR te.id = -1 THEN
				'Accès à la voie'
			ELSE ei.label  
		END AS label,
		CASE 
			WHEN te.id = -6 OR te.id = -1 THEN
				ST_length(te.geom)
			ELSE ei.length
		END AS length
		FROM pgrouting.create_temporary_edges(
				point_a, point_b, crs
		) AS te,
		pgrouting.edges_info ei
		WHERE te.ref_edge_id = ei.id
	)
	SELECT d.seq, d.edge, ST_Transform(e.geom, 4326), e.label, e.length, d.cost, d.agg_cost
	FROM (SELECT * FROM pgrouting.routing_alg(point_a, point_b, crs, opt)) AS d,
	edges e
	WHERE d.edge = e.id AND node <> -1
	ORDER BY d.seq;
END;
$BODY$;

-- Fonction de récupération de la RoadMap en GeoJson
DROP FUNCTION IF EXISTS pgrouting.get_geojson_roadmap(text, text, integer,text);
CREATE OR REPLACE FUNCTION pgrouting.get_geojson_roadmap(
	point_a text,
	point_b text,
	crs integer,
	opt text)
    RETURNS TABLE(
		routing json,
		poi json
	)
    LANGUAGE 'plpgsql'

    COST 100
    VOLATILE 
AS $BODY$
DECLARE
	geojson text;
BEGIN
 RETURN QUERY WITH source AS (
 SELECT "seq", "edge", "geom", "label", "dist", "cost", "agg_cost"
 FROM pgrouting.create_roadmap(point_a,point_b, crs, opt)
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
		FROM pgrouting.routing_poi As lg, source as s
		WHERE ST_DWithin(s.geom, ST_Transform(lg.geom, 4326), 1)
		GROUP BY lg.id, lg.label, lg.type, lg.description
		ORDER BY seq
	) AS f
)
SELECT row_to_json(fc, True) as routing, row_to_json(point_interest, True) as poi
FROM fc, point_interest;
END;
$BODY$;

DROP FUNCTION IF EXISTS pgrouting.routing_alg(text,text,integer,text);
CREATE OR REPLACE FUNCTION pgrouting.routing_alg(
	point_a text, point_b text, crs integer, opt text)
    RETURNS TABLE (
		seq integer,
		path_seq integer,
		node bigint,
		edge bigint,
		cost double precision,
		agg_cost double precision
	)
    LANGUAGE 'plpgsql'

    COST 100
    VOLATILE 
AS $BODY$
DECLARE
BEGIN
	IF opt = 'dijkstra' THEN
		RETURN QUERY SELECT *
		FROM pgr_dijkstra(
			(SELECT pgrouting.route_request(point_a, point_b, crs, opt)), -4, -1, FALSE
		);
	ELSIF opt = 'astar' THEN
		RETURN QUERY SELECT *
		FROM pgr_astar(
			(SELECT pgrouting.route_request(point_a, point_b, crs, opt)), -4, -1, FALSE
		);
	END IF;
END;
$BODY$;
