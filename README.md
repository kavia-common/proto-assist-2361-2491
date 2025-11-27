# proto-assist-2361-2491

Database container note:
- The Database container no longer invokes `postgres` directly in preview unless the binary exists.
- The entrypoint is Database/startup.sh, which will:
  - If postgres is present, start it on port 5001 with a local data directory.
  - Otherwise, start a health server on port 5001 via scripts/health.js.
  - If Node is missing, it attempts an nc-based listener on 5001 or a tail keep-alive as last resort.
- Preview start path used by Procfile: bash ./Database/server.sh (which delegates to startup.sh).
- For environments that bypass startup.sh, you can use Database/server.sh or Database/index.js to ensure port 5001 is bound.
- See Database/README.md for instructions to run a real PostgreSQL locally and the connection string used by BackendAPI.