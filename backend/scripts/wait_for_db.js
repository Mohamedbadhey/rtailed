#!/usr/bin/env node
/* Wait for MySQL to be reachable before starting the API (Nixpacks-friendly)
 * - Resolves DB host to IPv4 and probes TCP 3306 repeatedly
 * - Does NOT fail the deployment if DB is still starting; it just waits up to a cap
 */
const net = require('net');
const dns = require('dns').promises;

(async () => {
  const rawHost = process.env.MYSQLHOST || process.env.DB_HOST || 'localhost';
  const port = Number(process.env.MYSQLPORT || process.env.DB_PORT || 3306);
  const timeoutMs = Number(process.env.DB_WAIT_TIMEOUT_MS || 5000);
  const maxWaitMs = Number(process.env.DB_WAIT_MAX_MS || 120000); // 2 minutes
  const delayMs = Number(process.env.DB_WAIT_INTERVAL_MS || 1500);

  let host = rawHost;
  try {
    const a4 = await dns.lookup(rawHost, { family: 4 });
    host = a4.address;
    console.log(`[wait-for-db] Resolved ${rawHost} -> ${host} (IPv4)`);
  } catch (e) {
    console.log(`[wait-for-db] IPv4 lookup failed for ${rawHost}: ${e.message}. Using host as-is.`);
  }

  const start = Date.now();
  let attempts = 0;

  async function probe() {
    attempts++;
    return new Promise((resolve) => {
      const socket = net.createConnection({ host, port, family: 4 });
      const onDone = (ok, why) => {
        socket.removeAllListeners();
        try { socket.destroy(); } catch (_) {}
        resolve({ ok, why });
      };
      socket.once('connect', () => onDone(true, 'connect'));
      socket.once('error', (err) => onDone(false, err.code || err.message));
      socket.setTimeout(timeoutMs, () => onDone(false, 'TIMEOUT'));
    });
  }

  while (Date.now() - start < maxWaitMs) {
    const { ok, why } = await probe();
    if (ok) {
      const secs = ((Date.now() - start) / 1000).toFixed(1);
      console.log(`[wait-for-db] ✅ MySQL ${host}:${port} is reachable after ${attempts} attempts (${secs}s).`);
      process.exit(0);
    }
    const elapsed = ((Date.now() - start) / 1000).toFixed(1);
    console.log(`[wait-for-db] Attempt ${attempts} failed (${why}). Elapsed ${elapsed}s. Retrying in ${delayMs}ms...`);
    await new Promise(r => setTimeout(r, delayMs));
  }

  console.warn(`[wait-for-db] ⚠️ Gave up waiting after ${(maxWaitMs/1000).toFixed(1)}s. Continuing to start API; internal retry logic will handle DB readiness.`);
  process.exit(0);
})();
