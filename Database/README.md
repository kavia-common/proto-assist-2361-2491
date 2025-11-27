# Database Container

This container provides the PostgreSQL data store for the Proto Assistant platform. In preview environments, the `postgres` binary may not be available. To keep the environment healthy, we DO NOT call `postgres` directly unless it exists. Instead, we start a lightweight HTTP health server on port 5001.

## Preview Mode (Placeholder)

- Always binds TCP port 5001.
- Returns HTTP 200 with JSON indicating the database is mocked.
- No real database is started unless `postgres` is actually installed.

Health endpoint:
- GET http://localhost:5001/
- GET http://localhost:5001/health

Startup behavior:
1) Entry: ./startup.sh (preferred). Some previews may use server.sh or index.js; both delegate to the same behavior.
2) Check `command -v postgres`.
   - If present: start postgres on port 5001, initialize data dir as needed.
   - If not present: start health server (scripts/health.js) on port 5001.
3) If Node.js is missing, the script attempts a minimal TCP listener via `nc` (if available). As a last resort it will keep the process alive without binding a port.

If Node.js is available, the health server is provided by:
- scripts/health.js (minimal HTTP server) listening on the specified port.
- db_visualizer/server.js can also be used as a fallback.

## Quick start (Preview)

- Recommended:
  ./startup.sh

- If your environment ignores startup.sh:
  - bash server.sh
  - or: node index.js

In all cases the service will bind to port 5001.

## Real PostgreSQL Setup (Local Development)

If you have PostgreSQL installed locally, you can run the real database.

Environment defaults used by scripts:
- DB_NAME: myapp
- DB_USER: appuser
- DB_PASSWORD: dbuser123
- DB_PORT: 5001 (preview requirement)

Steps:
1) Ensure PostgreSQL is installed and `postgres`, `psql`, `pg_isready`, and `createdb` are on PATH.
2) Run the startup script:
   ./startup.sh
   - Initializes a data directory if needed (Database/.pgdata)
   - Starts PostgreSQL on port 5001
   - Creates database and user with appropriate privileges
   - Applies SQL migrations from Database/sql in lexical order (001_init.sql, 002_indexes.sql, 003_seed.sql)
   - Saves a connection string to db_connection.txt
   - Saves environment variables to db_visualizer/postgres.env

To connect with psql:
psql -h localhost -U appuser -d myapp -p 5001
or:
$(cat db_connection.txt)

### Database migrations (plain SQL)

This project uses plain SQL files—no external migration tooling.

- Location: Database/sql/
  - 001_init.sql     — creates tables, constraints, and extensions (safe IF NOT EXISTS).
  - 002_indexes.sql  — creates indexes for common queries.
  - 003_seed.sql     — optional seed data for local development.

How they are applied:
- Database/startup.sh detects if `postgres` is available.
- If yes, it starts PostgreSQL, ensures DB and user exist, then sequentially applies all .sql files in Database/sql using psql with ON_ERROR_STOP=1.
- If `postgres` is not available, the container runs a placeholder health server and no migrations are applied.

Manual application (if DB is already running):
PGPASSWORD="dbuser123" psql -h localhost -p 5001 -U appuser -d myapp -f Database/sql/001_init.sql
PGPASSWORD="dbuser123" psql -h localhost -p 5001 -U appuser -d myapp -f Database/sql/002_indexes.sql
PGPASSWORD="dbuser123" psql -h localhost -p 5001 -U appuser -d myapp -f Database/sql/003_seed.sql

To populate from the provided dump (alternative to migrations):
PGPASSWORD="dbuser123" psql -h localhost -p 5001 -U appuser -d postgres < database_backup.sql

## Connection details used by BackendAPI

The BackendAPI is expected to use a PostgreSQL connection string like:
postgresql://appuser:dbuser123@localhost:5001/myapp

Environment variables commonly used:
- DATABASE_URL or POSTGRES_URL
- POSTGRES_USER
- POSTGRES_PASSWORD
- POSTGRES_DB
- POSTGRES_PORT

Confirm the BackendAPI container’s configuration to set the correct variable names.

## db_visualizer helper

A minimal database viewer exists in db_visualizer/. To point it at the local PostgreSQL instance:

source db_visualizer/postgres.env
cd db_visualizer && npm install && npm start

Note: In the preview, we only use it as a simple HTTP server if `postgres` is not present.

## Notes

- This preview does not manage persistence or backups automatically.
- Real backups can be created with backup_db.sh and restored with restore_db.sh (when a real DB is running).
- The preview health server is intentionally minimal and does not expose any data.
