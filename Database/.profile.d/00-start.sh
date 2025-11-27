#!/usr/bin/env bash
# Preview environment hook to ensure our guarded entrypoint is used.
# If the platform attempts to run a default database command, we route through .start.
set -euo pipefail

START_FILE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/.start"
if [ -f "${START_FILE}" ]; then
  chmod +x "${START_FILE}" || true
  export DATABASE_PREVIEW_START="${START_FILE}"
  echo "[Database] .profile.d/00-start.sh set DATABASE_PREVIEW_START=${DATABASE_PREVIEW_START}"
fi
