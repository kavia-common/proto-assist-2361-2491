#!/usr/bin/env bash
set -euo pipefail
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"
chmod +x "${BASE_DIR}/.start" || true
chmod +x "${BASE_DIR}/server.sh" || true
chmod +x "${BASE_DIR}/startup.sh" || true
chmod +x "${BASE_DIR}/index.js" || true
chmod +x "${BASE_DIR}/scripts/health.js" || true
chmod +x "${BASE_DIR}/.profile.d/00-start.sh" || true
chmod +x "${BASE_DIR}/bin/postgres" || true
echo "[Database] mark_all_executable.sh: updated executable permissions."
