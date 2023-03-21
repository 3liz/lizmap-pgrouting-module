--
-- PostgreSQL database dump
--

-- Dumped from database version 14.7 (Debian 14.7-1.pgdg110+1)
-- Dumped by pg_dump version 14.7 (Ubuntu 14.7-0ubuntu0.22.04.1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: edition; Type: TABLE; Schema: pgrouting; Owner: -
--

CREATE TABLE pgrouting.edition (
    id integer NOT NULL,
    geom public.geometry(LineString,2154)
);


--
-- Name: edition_id_seq; Type: SEQUENCE; Schema: pgrouting; Owner: -
--

CREATE SEQUENCE pgrouting.edition_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: edition_id_seq; Type: SEQUENCE OWNED BY; Schema: pgrouting; Owner: -
--

ALTER SEQUENCE pgrouting.edition_id_seq OWNED BY pgrouting.edition.id;


--
-- Name: edition id; Type: DEFAULT; Schema: pgrouting; Owner: -
--

ALTER TABLE ONLY pgrouting.edition ALTER COLUMN id SET DEFAULT nextval('pgrouting.edition_id_seq'::regclass);


--
-- Data for Name: edition; Type: TABLE DATA; Schema: pgrouting; Owner: -
--

COPY pgrouting.edition (id, geom) FROM stdin;
\.


--
-- Name: edition_id_seq; Type: SEQUENCE SET; Schema: pgrouting; Owner: -
--

SELECT pg_catalog.setval('pgrouting.edition_id_seq', 1, false);


--
-- Name: edition edition_pkey; Type: CONSTRAINT; Schema: pgrouting; Owner: -
--

ALTER TABLE ONLY pgrouting.edition
    ADD CONSTRAINT edition_pkey PRIMARY KEY (id);


--
-- Name: sidx_edition_geom; Type: INDEX; Schema: pgrouting; Owner: -
--

CREATE INDEX sidx_edition_geom ON pgrouting.edition USING gist (geom);


--
-- PostgreSQL database dump complete
--

