from logging.config import fileConfig
import os

from sqlalchemy import create_engine
from sqlalchemy import pool

from alembic import context

# Load environment variables if needed
from dotenv import load_dotenv
load_dotenv()

# Pull in your DATABASE_URL from .env
DATABASE_URL = os.getenv("DATABASE_URL", "")

# Strip +asyncpg for alembic migrations
# This will convert postgresql+asyncpg to postgresql, which works for Alembic
SYNC_DATABASE_URL = DATABASE_URL.replace("+asyncpg", "")

# this is the Alembic Config object, which provides
# access to the values within the .ini file in use.
config = context.config

# Interpret the config file for Python logging.
fileConfig(config.config_file_name)

from app.database import Base  # Adjust path to your model Base

target_metadata = Base.metadata

def run_migrations_offline():
    context.configure(
        url=SYNC_DATABASE_URL,
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
    )

    with context.begin_transaction():
        context.run_migrations()

def run_migrations_online():
    connectable = create_engine(
        SYNC_DATABASE_URL,
        poolclass=pool.NullPool
    )

    with connectable.connect() as connection:
        context.configure(
            connection=connection,
            target_metadata=target_metadata
        )

        with context.begin_transaction():
            context.run_migrations()

if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
