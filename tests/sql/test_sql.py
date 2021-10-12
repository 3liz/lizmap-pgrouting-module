#! /usr/bin/env python

import os
from pathlib import Path

import psycopg
import unittest


class TestSql(unittest.TestCase):

    # noinspection PyPep8Naming
    def __init__(self, methodName="runTest"):
        super().__init__(methodName)
        self.cursor = None
        self.connection = None
        module_path = Path(__file__).parent.parent.parent.joinpath('pgrouting')
        sql_install = module_path.joinpath('install/sql/install.pgsql.sql')
        with open(sql_install, "r") as f:
            sql_install = f.read()
        self.sql_install = sql_install.replace("{$srid}", "2154")

    def setUp(self) -> None:
        database = os.getenv("POSTGRES_DB")
        username = os.getenv("POSTGRES_USER")
        password = os.getenv("POSTGRES_PASSWORD")
        port = os.getenv("POSTGRES_PORT", "5432")
        host = os.getenv("POSTGRES_HOST", "localhost")
        self.connection = psycopg.connect(
            f"host={host} user={username} password={password} port={port} dbname={database}"
        )
        self.cursor = self.connection.cursor()
        self.cursor.execute("DROP SCHEMA IF EXISTS pgrouting CASCADE;")
        self.cursor.execute(self.sql_install)

    def tearDown(self) -> None:
        self.cursor.execute("DROP SCHEMA pgrouting CASCADE;")
        self.connection.commit()
        self.connection.close()

    def test_create_edge_1(self):
        self.cursor.execute(
            "SELECT pgrouting.create_edge(ST_GeomFromText('LINESTRING(1 5, 2 7, 1 9, 14 12)',2154), 1, -1);")
        self.cursor.execute("SELECT COUNT(*) FROM pgrouting.nodes;")
        self.assertEqual(2, self.cursor.fetchone()[0])
        self.cursor.execute("SELECT COUNT(*) FROM pgrouting.edges;")
        self.assertEqual(1, self.cursor.fetchone()[0])

    @unittest.expectedFailure
    def test_create_edge_2(self):
        self.cursor.execute(
            "SELECT pgrouting.create_edge(ST_Reverse(ST_GeomFromText('LINESTRING(1 5, 2 7, 1 9, 14 12)',2154)), 1, -1);")
        self.cursor.execute("SELECT COUNT(*) FROM pgrouting.nodes;")
        self.assertEqual(2, self.cursor.fetchone()[0])
        self.cursor.execute("SELECT COUNT(*) FROM pgrouting.edges;")
        self.assertEqual(2, self.cursor.fetchone()[0])

    @unittest.expectedFailure
    def test_create_edge_3(self):
        self.cursor.execute(
            "SELECT pgrouting.create_edge(ST_GeomFromText('LINESTRING(1 5, 2 9, 14 12)',2154), 1, -1);")
        self.cursor.execute("SELECT COUNT(*) FROM pgrouting.nodes;")
        self.assertEqual(2, self.cursor.fetchone()[0])
        self.cursor.execute("SELECT COUNT(*) FROM pgrouting.edges;")
        self.assertEqual(3, self.cursor.fetchone()[0])


if __name__ == "__main__":
    unittest.main()
