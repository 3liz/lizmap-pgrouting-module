select pgrouting.create_edge(ST_GeomFromText('LINESTRING(1 5, 2 7, 1 9, 14 12)',2154), 1, -1);
select count(*) from pgrouting.nodes; --2 rows
select count(*) from pgrouting.edges; --1 row

select pgrouting.create_edge(ST_Reverse(ST_GeomFromText('LINESTRING(1 5, 2 7, 1 9, 14 12)',2154)), 1, -1);
select count(*) from pgrouting.nodes; --2 rows
select count(*) from pgrouting.edges; --2 rows

select pgrouting.create_edge(ST_GeomFromText('LINESTRING(1 5, 2 9, 14 12)',2154), 1, -1);
select count(*) from pgrouting.nodes; --2 rows
select count(*) from pgrouting.edges; --3 rows
