For preview environments:

- Do not call `postgres` directly at any time.
- All startup paths route through Database/server.sh -> Database/startup.sh.
- If `postgres` is detected on PATH, startup.sh will run it; otherwise it will start a Node health server on port 5001.
- If Node is unavailable, a no-op long-running fallback (nc if present, else tail -f /dev/null) is used.

Use one of the following entry commands to ensure a health server on port 5001:
  - bash ./main.sh            (root-level; delegates to Database/server.sh)
  - bash ./Database/server.sh (delegates to Database/startup.sh)
  - bash ./Database/startup.sh
  - node ./Database/index.js  (Node health server)

This repository sets:
- Root Procfile -> web: bash ./main.sh
- Database/Procfile -> web: bash ./server.sh

These paths ensure the preview binds to port 5001 without requiring a postgres binary.
