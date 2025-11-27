#!/usr/bin/env bash
# Simple shim used by preview environments that might ignore startup.sh and run a generic "server" script.
# It ensures the Database container binds port 5001 with a health endpoint by delegating to startup.sh.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Ensure startup.sh is executable
chmod +x "${SCRIPT_DIR}/startup.sh" || true
echo "[Database] server.sh invoked. Delegating to startup.sh..."
exec "${SCRIPT_DIR}/startup.sh"
