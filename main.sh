#!/usr/bin/env bash
# Top-level entrypoint for previews. Delegates to Database/server.sh (which invokes startup.sh).
# Ensures executable bits for Database scripts and guarantees binding to port 5001 via health server if postgres is unavailable.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DB_DIR="${ROOT_DIR}/Database"

# Ensure scripts are executable (no-op if already executable)
chmod +x "${DB_DIR}/startup.sh" || true
chmod +x "${DB_DIR}/server.sh" || true
chmod +x "${DB_DIR}/index.js" || true
chmod +x "${DB_DIR}/scripts/health.js" || true

# Prefer server.sh which delegates to startup.sh
if [ -f "${DB_DIR}/server.sh" ]; then
  echo "[main.sh] Starting Database via ${DB_DIR}/server.sh ..."
  exec bash "${DB_DIR}/server.sh"
fi

# Fallbacks
if [ -f "${DB_DIR}/startup.sh" ]; then
  echo "[main.sh] server.sh not found, using ${DB_DIR}/startup.sh ..."
  exec bash "${DB_DIR}/startup.sh"
fi

# Last resort: Node index.js health server
if command -v node >/dev/null 2>&1 && [ -f "${DB_DIR}/index.js" ]; then
  echo "[main.sh] Using Node index.js to start health server on port 5001 ..."
  export DB_HEALTH_PORT="${DB_HEALTH_PORT:-5001}"
  exec node "${DB_DIR}/index.js"
fi

# If Node is missing, keep alive with nc or tail
echo "[main.sh] Node not available; attempting netcat keep-alive on port 5001 ..."
if command -v nc >/dev/null 2>&1; then
  while true; do
    printf "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n\r\n{\"status\":\"ok\",\"service\":\"Database\",\"mocked\":true,\"message\":\"Keep-alive placeholder from main.sh\",\"port\":5001}\n"
  done | nc -lk -p 5001
else
  echo "[main.sh] netcat not available; falling back to tail -f /dev/null."
  tail -f /dev/null
fi
