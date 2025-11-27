For preview environments:

- Do not call `postgres` directly.
- Use one of the following entry commands to ensure a health server on port 5001:
  - bash ./main.sh            (root-level)
  - bash ./Database/server.sh (delegates to Database/startup.sh)
  - bash ./Database/startup.sh
  - node ./Database/index.js  (Node health server)

This repository sets:
- Root Procfile -> web: bash ./main.sh
- Database/Procfile -> web: bash ./server.sh

Both paths ensure the preview binds to port 5001 without requiring a postgres binary.
