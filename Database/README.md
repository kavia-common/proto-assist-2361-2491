# Database Container

This container provides the PostgreSQL data store for the Proto Assistant platform. In this preview environment, the `postgres` binary may not be available. To keep the environment healthy, the container starts a lightweight HTTP health server instead of failing.

## Preview Mode (Placeholder)

- Listens on TCP port 5001.
- Returns HTTP 200 with JSON indicating the database is mocked.
- No real database is started.

Health endpoint:
- GET http://localhost:5001/
- GET http://localhost:5001/health

If Node.js is available, the health server is provided by:
- Either db_visualizer/server.js (Express app) listening on the specified port
- Or scripts/health.js (minimal HTTP server)

If Node.js is not available, the script attempts a very minimal TCP listener (if `nc` exists).

## Real PostgreSQL Setup (Local Development)

If you have PostgreSQL installed locally, you can run the real database.

Environment defaults used by scripts:
- DB_NAME: myapp
- DB_USER: appuser
- DB_PASSWORD: dbuser123
- DB_PORT: 5000

Steps:
1) Ensure PostgreSQL is installed and `postgres`, `psql`, `pg_isready`, and `createdb` are on PATH.
2) Run the startup script:
   ./startup.sh
   - It will initialize a data directory (if needed)
   - Start PostgreSQL on port 5000
   - Create database and user with appropriate privileges
   - Save a connection string to db_connection.txt
   - Save environment variables to db_visualizer/postgres.env

To connect with psql:
psql -h localhost -U appuser -d myapp -p 5000
or:
$(cat db_connection.txt)

To populate from the provided dump:
PGPASSWORD="dbuser123" psql -h localhost -p 5000 -U appuser -d postgres < database_backup.sql

## Connection details used by BackendAPI

The BackendAPI is expected to use a PostgreSQL connection string like:
postgresql://appuser:dbuser123@localhost:5000/myapp

In containerized or cloud environments, use the appropriate host and port.

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
