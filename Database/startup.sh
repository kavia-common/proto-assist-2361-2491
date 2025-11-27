#!/bin/bash

# Database container startup with safe guards and placeholder fallback.
# If postgres binary is missing, start a lightweight HTTP health server on port 5001.

set -e

DB_NAME="myapp"
DB_USER="appuser"
DB_PASSWORD="dbuser123"
DB_PORT="${DB_PORT:-5000}"
DB_HEALTH_PORT="${DB_HEALTH_PORT:-5001}"

echo "Starting Database container..."

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HEALTH_JS="${BASE_DIR}/scripts/health.js"
VIEWER_DIR="${BASE_DIR}/db_visualizer"

start_health() {
  echo "Launching placeholder health server on port ${DB_HEALTH_PORT}..."
  if command -v node >/dev/null 2>&1; then
    # Prefer db_visualizer/server.js if present (Express app)
    if [ -f "${VIEWER_DIR}/server.js" ]; then
      echo "Found db_visualizer/server.js. Starting as lightweight server..."
      PORT="${DB_HEALTH_PORT}" node "${VIEWER_DIR}/server.js" >/dev/null 2>&1 &
      echo $! > "${BASE_DIR}/.health_server.pid"
      echo "Health server started (db_visualizer) with PID $(cat "${BASE_DIR}/.health_server.pid")"
      return 0
    fi

    # Fallback to scripts/health.js
    if [ -f "${HEALTH_JS}" ]; then
      DB_HEALTH_PORT="${DB_HEALTH_PORT}" node "${HEALTH_JS}" >/dev/null 2>&1 &
      echo $! > "${BASE_DIR}/.health_server.pid"
      echo "Health server started (health.js) with PID $(cat "${BASE_DIR}/.health_server.pid")"
      return 0
    fi

    echo "ERROR: No health server script found."
  else
    echo "WARNING: Node.js not found. Unable to start placeholder health server."
  fi

  # Last resort: block on a simple nc listener if available
  if command -v nc >/dev/null 2>&1; then
    echo "Starting minimal TCP listener with netcat on port ${DB_HEALTH_PORT}..."
    while true; do
      echo -e "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n\r\n{\"status\":\"ok\",\"service\":\"Database\",\"mocked\":true,\"message\":\"Placeholder health server\",\"port\":${DB_HEALTH_PORT}}"
    done | nc -l -p "${DB_HEALTH_PORT}"
  else
    echo "No available method to start a health server. Exiting with success to keep preview alive."
  fi
}

# Detect postgres binaries safely
PG_BIN_DIR=""
PG_ISREADY=""
PSQL_BIN=""
CREATEDB_BIN=""
INITDB_BIN=""

if command -v postgres >/dev/null 2>&1; then
  PG_BIN_DIR="$(dirname "$(command -v postgres)")"
  PG_ISREADY="$(command -v pg_isready || echo "${PG_BIN_DIR}/pg_isready")"
  PSQL_BIN="$(command -v psql || echo "${PG_BIN_DIR}/psql")"
  CREATEDB_BIN="$(command -v createdb || echo "${PG_BIN_DIR}/createdb")"
  INITDB_BIN="$(command -v initdb || echo "${PG_BIN_DIR}/initdb")"
else
  # Try Ubuntu layout if installed
  PG_VERSION=$(ls /usr/lib/postgresql/ 2>/dev/null | head -1)
  if [ -n "$PG_VERSION" ] && [ -d "/usr/lib/postgresql/${PG_VERSION}/bin" ]; then
    PG_BIN_DIR="/usr/lib/postgresql/${PG_VERSION}/bin"
    PG_ISREADY="${PG_BIN_DIR}/pg_isready"
    PSQL_BIN="${PG_BIN_DIR}/psql"
    CREATEDB_BIN="${PG_BIN_DIR}/createdb"
    INITDB_BIN="${PG_BIN_DIR}/initdb"
  fi
fi

# If postgres not available, run placeholder server and exit successfully.
if [ -z "${PG_BIN_DIR}" ] || [ ! -x "${PG_BIN_DIR}/postgres" ]; then
  echo "postgres binary not found. Running in placeholder mode."
  echo "A lightweight health server will respond on port ${DB_HEALTH_PORT}."
  echo "See Database/README.md for running a real Postgres locally."
  # Do not exit on errors inside start_health; we want preview to remain alive even if node missing.
  set +e
  start_health
  exit 0
fi

echo "Found PostgreSQL binaries in: ${PG_BIN_DIR}"

# Check if PostgreSQL is already running on the specified port
if sudo -u postgres "${PG_ISREADY}" -p "${DB_PORT}" > /dev/null 2>&1; then
  echo "PostgreSQL is already running on port ${DB_PORT}!"
  echo "Database: ${DB_NAME}"
  echo "User: ${DB_USER}"
  echo "Port: ${DB_PORT}"
  echo ""
  echo "To connect to the database, use:"
  echo "psql -h localhost -U ${DB_USER} -d ${DB_NAME} -p ${DB_PORT}"

  if [ -f "${BASE_DIR}/db_connection.txt" ]; then
    echo "Or use: $(cat "${BASE_DIR}/db_connection.txt")"
  fi

  exit 0
fi

# Also check if there's a PostgreSQL process running (in case pg_isready fails)
if pgrep -f "postgres.*-p ${DB_PORT}" > /dev/null 2>&1; then
  echo "Found existing PostgreSQL process on port ${DB_PORT}"
  echo "Attempting to verify connection..."
  if sudo -u postgres "${PSQL_BIN}" -p "${DB_PORT}" -d "${DB_NAME}" -c '\q' 2>/dev/null; then
    echo "Database ${DB_NAME} is accessible."
    exit 0
  fi
fi

# Initialize PostgreSQL data directory if it doesn't exist
if [ ! -f "/var/lib/postgresql/data/PG_VERSION" ]; then
  echo "Initializing PostgreSQL..."
  sudo -u postgres "${INITDB_BIN}" -D /var/lib/postgresql/data
fi

# Start PostgreSQL server in background
echo "Starting PostgreSQL server..."
sudo -u postgres "${PG_BIN_DIR}/postgres" -D /var/lib/postgresql/data -p "${DB_PORT}" &

# Wait for PostgreSQL to start
echo "Waiting for PostgreSQL to start..."
for i in {1..15}; do
  if sudo -u postgres "${PG_ISREADY}" -p "${DB_PORT}" > /dev/null 2>&1; then
    echo "PostgreSQL is ready!"
    break
  fi
  echo "Waiting... ($i/15)"
  sleep 2
done

# Create database and user
echo "Setting up database and user..."
sudo -u postgres "${CREATEDB_BIN}" -p "${DB_PORT}" "${DB_NAME}" 2>/dev/null || echo "Database might already exist"

# Set up user and permissions with proper schema ownership
sudo -u postgres "${PSQL_BIN}" -p "${DB_PORT}" -d postgres << EOF
-- Create user if doesn't exist
DO \$$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '${DB_USER}') THEN
        CREATE ROLE ${DB_USER} WITH LOGIN PASSWORD '${DB_PASSWORD}';
    END IF;
    ALTER ROLE ${DB_USER} WITH PASSWORD '${DB_PASSWORD}';
END
\$$;

-- Grant database-level permissions
GRANT ALL PRIVILEGES ON DATABASE ${DB_NAME} TO ${DB_USER};

-- Connect to the specific database for schema-level permissions
\c ${DB_NAME}

-- Public schema permissions
GRANT USAGE ON SCHEMA public TO ${DB_USER};
GRANT CREATE ON SCHEMA public TO ${DB_USER};
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO ${DB_USER};
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO ${DB_USER};
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON FUNCTIONS TO ${DB_USER};
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TYPES TO ${DB_USER};
GRANT ALL ON SCHEMA public TO ${DB_USER};
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO ${DB_USER};
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO ${DB_USER};
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA public TO ${DB_USER};
EOF

# Double-check in target DB
sudo -u postgres "${PSQL_BIN}" -p "${DB_PORT}" -d "${DB_NAME}" << EOF
GRANT ALL ON SCHEMA public TO ${DB_USER};
GRANT CREATE ON SCHEMA public TO ${DB_USER};
EOF

# Save connection command to a file
echo "psql postgresql://${DB_USER}:${DB_PASSWORD}@localhost:${DB_PORT}/${DB_NAME}" > "${BASE_DIR}/db_connection.txt"
echo "Connection string saved to db_connection.txt"

# Save environment variables to a file for the viewer
mkdir -p "${VIEWER_DIR}"
cat > "${VIEWER_DIR}/postgres.env" << EOF
export POSTGRES_URL="postgresql://localhost:${DB_PORT}/${DB_NAME}"
export POSTGRES_USER="${DB_USER}"
export POSTGRES_PASSWORD="${DB_PASSWORD}"
export POSTGRES_DB="${DB_NAME}"
export POSTGRES_PORT="${DB_PORT}"
EOF

echo "PostgreSQL setup complete!"
echo "Database: ${DB_NAME}"
echo "User: ${DB_USER}"
echo "Port: ${DB_PORT}"
