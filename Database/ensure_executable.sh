#!/usr/bin/env bash
# Utility to ensure scripts are executable in environments that strip file modes.
set -euo pipefail
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
chmod +x "${BASE_DIR}/startup.sh" || true
chmod +x "${BASE_DIR}/server.sh" || true
chmod +x "${BASE_DIR}/index.js" || true
chmod +x "${BASE_DIR}/scripts/health.js" || true
echo "[Database] Executable bits ensured."
ls -l "${BASE_DIR}/startup.sh" "${BASE_DIR}/server.sh" "${BASE_DIR}/index.js" "${BASE_DIR}/scripts/health.js" 2>/dev/null || true
