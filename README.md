# proto-assist-2361-2491

Database container note:
- The Database container now starts a lightweight HTTP health server on port 5001 if the `postgres` binary is not available, ensuring the preview remains healthy.
- See Database/README.md for instructions to run a real PostgreSQL locally and the connection string used by BackendAPI.