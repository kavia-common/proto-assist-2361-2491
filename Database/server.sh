#!/usr/bin/env bash
# Simple shim used by preview environments that might ignore startup.sh and run a generic "server" script.
# It ensures the Database container binds port 5001 with a health endpoint.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "[Database] server.sh invoked. Delegating to startup.sh..."
exec "${SCRIPT_DIR}/startup.sh"
