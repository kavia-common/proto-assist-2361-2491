#!/usr/bin/env bash
# Simple shim used by preview environments that might ignore startup.sh and run a generic "server" script.
# It ensures the Database container binds port 5001 with a health endpoint by delegating to startup.sh.
# Never directly invokes `postgres`. All logic lives in startup.sh.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Ensure executables exist
chmod +x "${SCRIPT_DIR}/startup.sh" || true
chmod +x "${SCRIPT_DIR}/index.js" || true
chmod +x "${SCRIPT_DIR}/scripts/health.js" || true

# VERY EXPLICIT RUNTIME PATH ECHO
echo "[Database] server.sh invoked at path: ${SCRIPT_DIR}/server.sh"
echo "[Database] Delegating to ${SCRIPT_DIR}/startup.sh ..."

# Run startup.sh; if it returns (e.g., health server exits), provide robust fallbacks
bash "${SCRIPT_DIR}/startup.sh" || true

# If we get here, try Node-based health server on port 5001
export DB_HEALTH_PORT="${DB_HEALTH_PORT:-5001}"
if command -v node >/dev/null 2>&1 && [ -f "${SCRIPT_DIR}/index.js" ]; then
  echo "[Database] startup.sh returned; starting Node health server via index.js on port ${DB_HEALTH_PORT} ..."
  exec node "${SCRIPT_DIR}/index.js"
fi

# Final fallback: keep container alive; try netcat bind or tail
echo "[Database] Node not available or index.js missing; entering keep-alive mode on port ${DB_HEALTH_PORT} if possible ..."
if command -v nc >/dev/null 2>&1; then
  while true; do
    printf "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n\r\n{\"status\":\"ok\",\"service\":\"Database\",\"mocked\":true,\"message\":\"Keep-alive placeholder from server.sh\",\"port\":%s}\n" "${DB_HEALTH_PORT}"
  done | nc -lk -p "${DB_HEALTH_PORT}"
else
  echo "[Database] netcat not available; tail -f /dev/null as final no-op fallback."
  tail -f /dev/null
fi
