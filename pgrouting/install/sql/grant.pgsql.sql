-- Grant
GRANT USAGE ON SCHEMA "pgrouting" TO "{$userGroup}";
GRANT ALL ON ALL TABLES IN SCHEMA "pgrouting" TO "{$userGroup}";
GRANT USAGE ON ALL SEQUENCES IN SCHEMA "pgrouting" TO "{$userGroup}";
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA "pgrouting" TO "{$userGroup}";
