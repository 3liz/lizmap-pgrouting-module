CREATE SCHEMA IF NOT EXISTS pgrouting;

CREATE TABLE pgrouting.nodes(
    id serial primary key,
    geom geometry('POINT', {$srid})
);

CREATE TABLE IF NOT EXISTS pgrouting.edges(
    id serial PRIMARY key,
    source integer,
    target integer,
    cost integer,
    reverse_cost integer,
    geom geometry('LINESTRING', {$srid})
);

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

-- Create Functions

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

CREATE OR REPLACE FUNCTION pgrouting.create_edge(
	geom_val geometry('LINESTRING', {$srid}), cost_val float, reverse_cost_val float)
    RETURNS void
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
		);
	ELSE
		UPDATE pgrouting.edges
		SET cost = cost_val, reverse_cost = reverse_cost_val
		WHERE id = id_val;
	END IF;
  END;
$BODY$;
