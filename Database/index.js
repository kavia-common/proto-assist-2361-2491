#!/usr/bin/env node
/**
 * Node-based entrypoint shim for environments that expect a JavaScript main.
 * Starts the lightweight health server on port 5001, never invokes `postgres` directly.
 */

// PUBLIC_INTERFACE
function main() {
  /** Starts the minimal health server to keep preview healthy on port 5001. */
  try {
    const { startHealthServer } = require('./scripts/health.js');
    process.env.DB_HEALTH_PORT = process.env.DB_HEALTH_PORT || '5001';
    console.log(`[Database] index.js starting health server on port ${process.env.DB_HEALTH_PORT} ...`);
    startHealthServer();
  } catch (e) {
    console.log('[Database] index.js fallback failed to load health server:', e && e.message);
    console.log('[Database] Keeping process alive as last resort (no Node health server).');
    // Keep the process alive even if health.js is missing
    setInterval(() => {}, 1 << 30);
  }
}

if (require.main === module) {
  main();
}

module.exports = { main };
