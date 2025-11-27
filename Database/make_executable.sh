#!/usr/bin/env bash
# Utility script to ensure Database entry scripts are executable in preview environments.
set -euo pipefail
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
chmod +x "${BASE_DIR}/startup.sh" || true
chmod +x "${BASE_DIR}/server.sh" || true
chmod +x "${BASE_DIR}/index.js" || true
chmod +x "${BASE_DIR}/scripts/health.js" || true
echo "[Database] make_executable.sh: scripts marked executable."
