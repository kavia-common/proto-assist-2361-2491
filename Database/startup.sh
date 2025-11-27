#!/usr/bin/env bash
# Database container startup with safe guards and placeholder fallback.
# Behavior:
# 1) If `postgres` exists in PATH, start it on port 5001 using a data dir.
# 2) If not, start the lightweight health server on port 5001.
# 3) Guards:
#    - If Node is missing, try nc on port 5001, else keep container alive via tail -f /dev/null.
# Notes:
# - This script is intended to be the entrypoint for preview mode.
# - IMPORTANT: We never unconditionally invoke postgres; detection is performed via `command -v postgres`.

set -euo pipefail

cat <<'BANNER'
============================================================
[Database] Startup Guard: startup.sh
- No direct postgres call unless binary detected in PATH
- Health server binds 0.0.0.0:5001 in placeholder mode
- Real Postgres uses DATA_DIR=.pgdata and port 5001
============================================================
BANNER

DB_NAME="${DB_NAME:-myapp}"
DB_USER="${DB_USER:-appuser}"
DB_PASSWORD="${DB_PASSWORD:-dbuser123}"

# In preview we standardize on 5001 per task requirement
DB_PORT="${DB_PORT:-5001}"
DB_HEALTH_PORT="${DB_HEALTH_PORT:-5001}"

echo "[Database] Startup initializing..."
echo "[Database] Desired port: ${DB_PORT} (DB) / ${DB_HEALTH_PORT} (health)"

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HEALTH_JS="${BASE_DIR}/scripts/health.js"
VIEWER_DIR="${BASE_DIR}/db_visualizer"
DATA_DIR="${DATA_DIR:-${BASE_DIR}/.pgdata}"

mkdir -p "${DATA_DIR}"

# Keep-alive helper
keep_alive() {
  echo "[Database] Entering keep-alive mode (no server could be started)."
  # Try to keep port 5001 bound if nc exists; otherwise, tail.
  if command -v nc >/dev/null 2>&1; then
    echo "[Database] Using netcat to bind port ${DB_HEALTH_PORT}."
    while true; do
      printf "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n\r\n{\"status\":\"ok\",\"service\":\"Database\",\"mocked\":true,\"message\":\"Keep-alive placeholder (no Node, no postgres)\",\"port\":%s}\n" "${DB_HEALTH_PORT}"
    done | nc -lk -p "${DB_HEALTH_PORT}"
  else
    echo "[Database] netcat not available. Falling back to tail -f /dev/null."
    # This does not bind the port, but keeps container alive as last resort.
    tail -f /dev/null
  fi
}

start_health() {
  echo "[Database] [BRANCH] Health server path selected (postgres not found)."
  echo "[Database] Launching placeholder health server on port ${DB_HEALTH_PORT}..."
  if command -v node >/dev/null 2>&1; then
    # Prefer minimal health.js for lightweight footprint
    if [ -f "${HEALTH_JS}" ]; then
      DB_HEALTH_PORT="${DB_HEALTH_PORT}" node "${HEALTH_JS}" &
      echo $! > "${BASE_DIR}/.health_server.pid"
      echo "[Database] Health server started (health.js) PID $(cat "${BASE_DIR}/.health_server.pid")"
      wait
      return 0
    fi

    # Fallback to db_visualizer/server.js if present
    if [ -f "${VIEWER_DIR}/server.js" ]; then
      PORT="${DB_HEALTH_PORT}" node "${VIEWER_DIR}/server.js" &
      echo $! > "${BASE_DIR}/.health_server.pid"
      echo "[Database] Health server started (db_visualizer) PID $(cat "${BASE_DIR}/.health_server.pid")"
      wait
      return 0
    fi

    echo "[Database] ERROR: No health server script found (looked for scripts/health.js and db_visualizer/server.js)"
  else
    echo "[Database] WARNING: Node.js not found. Cannot start health.js."
  fi

  # Last resort: keep-alive with nc/tail
  keep_alive
}

start_postgres() {
  echo "[Database] [BRANCH] Postgres path selected (postgres detected in PATH)."
  echo "[Database] postgres detected. Starting real PostgreSQL on port ${DB_PORT} using data dir: ${DATA_DIR}"

  # Discover binaries
  PG_BIN_DIR="$(dirname "$(command -v postgres)")"
  PG_ISREADY="$(command -v pg_isready || echo "${PG_BIN_DIR}/pg_isready")"
  PSQL_BIN="$(command -v psql || echo "${PG_BIN_DIR}/psql")"
  INITDB_BIN="$(command -v initdb || echo "${PG_BIN_DIR}/initdb")"
  CREATEDB_BIN="$(command -v createdb || echo "${PG_BIN_DIR}/createdb")"

  # Initialize data dir if needed
  if [ ! -f "${DATA_DIR}/PG_VERSION" ]; then
    echo "[Database] Initializing data directory..."
    "${INITDB_BIN}" -D "${DATA_DIR}"
  fi

  # Start postgres in foreground (so container stays alive)
  echo "[Database] Starting postgres..."
  "${PG_BIN_DIR}/postgres" -D "${DATA_DIR}" -p "${DB_PORT}" &
  PG_PID=$!

  # Wait for readiness (best effort)
  echo "[Database] Waiting for Postgres to become ready..."
  for i in {1..40}; do
    if "${PG_ISREADY}" -p "${DB_PORT}" >/dev/null 2>&1; then
      echo "[Database] Postgres is ready."
      break
    fi
    sleep 1
  done

  # Create database and user (best effort)
  {
    "${CREATEDB_BIN}" -p "${DB_PORT}" "${DB_NAME}" 2>/dev/null || true
    "${PSQL_BIN}" -p "${DB_PORT}" -d postgres <<EOF
DO $$ 
BEGIN
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '${DB_USER}') THEN
    CREATE ROLE ${DB_USER} WITH LOGIN PASSWORD '${DB_PASSWORD}';
  END IF;
  ALTER ROLE ${DB_USER} WITH PASSWORD '${DB_PASSWORD}';
END
$$;
GRANT ALL PRIVILEGES ON DATABASE ${DB_NAME} TO ${DB_USER};
\c ${DB_NAME}
GRANT USAGE, CREATE ON SCHEMA public TO ${DB_USER};
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO ${DB_USER};
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO ${DB_USER};
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON FUNCTIONS TO ${DB_USER};
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TYPES TO ${DB_USER};
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO ${DB_USER};
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO ${DB_USER};
EOF
  } || echo "[Database] Non-fatal: Failed to fully configure DB/user."

  # Apply SQL migrations if available
  MIGRATIONS_DIR="${BASE_DIR}/sql"
  if [ -d "${MIGRATIONS_DIR}" ]; then
    echo "[Database] Applying SQL migrations from ${MIGRATIONS_DIR}..."
    # Apply in lexical order: 001_*.sql, 002_*.sql, etc.
    for f in $(ls "${MIGRATIONS_DIR}"/*.sql 2>/dev/null | sort); do
      echo "  - Running $(basename "$f")"
      "${PSQL_BIN}" -v ON_ERROR_STOP=1 -p "${DB_PORT}" -d "${DB_NAME}" -f "$f" \
        || { echo "[Database] ERROR applying migration: $f"; kill ${PG_PID}; exit 1; }
    done
    echo "[Database] Migrations applied successfully."
  else
    echo "[Database] No migrations directory found at ${MIGRATIONS_DIR} (skipping)."
  fi

  # Write connection helpers
  echo "psql postgresql://${DB_USER}:${DB_PASSWORD}@localhost:${DB_PORT}/${DB_NAME}" > "${BASE_DIR}/db_connection.txt"

  mkdir -p "${VIEWER_DIR}"
  cat > "${VIEWER_DIR}/postgres.env" <<EOF
export POSTGRES_URL="postgresql://localhost:${DB_PORT}/${DB_NAME}"
export POSTGRES_USER="${DB_USER}"
export POSTGRES_PASSWORD="${DB_PASSWORD}"
export POSTGRES_DB="${DB_NAME}"
export POSTGRES_PORT="${DB_PORT}"
EOF

  echo "[Database] PostgreSQL running. PID ${PG_PID}. Listening on port ${DB_PORT}."
  wait ${PG_PID}
}

# Main decision branch:
if command -v postgres >/dev/null 2>&1; then
  start_postgres
else
  echo "[Database] postgres not found on PATH."
  echo "[Database] To run a real database locally, see Database/README.md."
  # Do not crash the container even if health server cannot start.
  set +e
  start_health
fi
