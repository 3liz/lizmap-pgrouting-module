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
        self.sql_install = sql_install

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
        self.cursor.execute("CREATE EXTENSION IF NOT EXISTS pgrouting;")
        self.cursor.execute(self.sql_install)

        # Import test data
        self.import_test_data()

    def import_test_data(self):
        test_path = Path(__file__)
        sql_data = test_path.parent.joinpath('test_data.sql')
        with open(sql_data, "r") as f:
            sql_data = f.read()
        sql = 'TRUNCATE pgrouting.nodes RESTART IDENTITY CASCADE;'
        sql += 'TRUNCATE pgrouting.edges RESTART IDENTITY CASCADE;'
        sql += sql_data
        self.cursor.execute(sql)
        self.connection.commit()

    def tearDown(self) -> None:
        self.cursor.execute("DROP SCHEMA pgrouting CASCADE;")
        self.connection.commit()
        self.connection.close()

    def test_get_closest_edge_id(self):
        sql = 'SELECT pgrouting.get_closest_edge_id(ST_SetSRID(ST_MakePoint(829667, 6288540), 2154));'
        self.cursor.execute(sql)
        self.assertEqual(327, self.cursor.fetchone()[0])

    def test_route_dijkstra(self):
        sql = """
SELECT *
FROM pgrouting.create_roadmap(
    'POINT(4.607761 43.684038)', 'POINT(4.611381 43.685356)', 4326, 'dijkstra'
)"""
        self.cursor.execute(sql)
        ids = [a[1] for a in self.cursor.fetchall()]
        expected = [-6, -5, 322, 231, 224, 225, 223, 230, 579, 538, -3, -1]
        self.assertEqual(ids, expected)


if __name__ == "__main__":
    unittest.main()
