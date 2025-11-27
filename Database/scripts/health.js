#!/usr/bin/env node
/**
 * Lightweight health server for Database container placeholder mode.
 * Serves HTTP 200 on / and /health to indicate the DB service is mocked in this environment.
 * Port: 5001
 */

// PUBLIC_INTERFACE
function startHealthServer() {
  /** Starts an HTTP server that returns JSON describing the mocked DB status. */
  const http = require('http');

  const PORT = process.env.DB_HEALTH_PORT || 5001;
  const payload = {
    status: 'ok',
    service: 'Database',
    mocked: true,
    message: 'PostgreSQL is not available in this preview. A placeholder health server is running.',
    ports: {
      health: PORT
    },
    docs: 'See Database/README.md for instructions to run a real PostgreSQL instance locally.'
  };

  const server = http.createServer((req, res) => {
    if (req.url === '/' || req.url === '/health') {
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify(payload));
    } else {
      res.writeHead(404, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ error: 'Not found' }));
    }
  });

  server.listen(PORT, '0.0.0.0', () => {
    console.log(`Database placeholder health server listening on http://0.0.0.0:${PORT}`);
  });
}

if (require.main === module) {
  startHealthServer();
}

module.exports = { startHealthServer };
