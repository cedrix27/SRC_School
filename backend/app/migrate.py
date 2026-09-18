"""Versioned initial schema migration. Run before starting the API."""
from sqlalchemy import text
from .db import Base, engine


def migrate():
    with engine.begin() as connection:
        connection.execute(text('CREATE TABLE IF NOT EXISTS schema_migrations (version VARCHAR PRIMARY KEY)'))
        if not connection.execute(text("SELECT version FROM schema_migrations WHERE version = '001'")).first():
            Base.metadata.create_all(connection)
            connection.execute(text("INSERT INTO schema_migrations(version) VALUES ('001')"))


if __name__ == '__main__':
    migrate()
