import os


def pytest_report_header(config):
    msg = (
        f"PostGIS credentials for tests :\n"
        f"  Host : {os.getenv('POSTGRES_HOST', 'localhost')}\n"
        f"  Name : {os.getenv('POSTGRES_DB')}\n"
        f"  Port : {os.getenv('POSTGRES_PORT', '5432')}\n"
        f"  Username : {os.getenv('POSTGRES_USER')}\n"
        f"  Password : {os.getenv('POSTGRES_PASSWORD')}"
    )
    return msg
