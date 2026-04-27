const mysql = require('mysql2/promise');
const dns = require('dns');

// Prefer IPv4 first to avoid IPv6-only endpoints causing ECONNREFUSED on some hosts
try {
  if (typeof dns.setDefaultResultOrder === 'function') {
    dns.setDefaultResultOrder(process.env.DNS_RESULT_ORDER || 'ipv4first');
  }
} catch (_) {}

let pool = null; // lazily created

function parseBool(v, def = false) {
  if (v === undefined || v === null) return def;
  const s = String(v).trim().toLowerCase();
  return s === 'true' || s === '1' || s === 'yes';
}

function buildPoolConfigFromEnv() {
  const url = process.env.DATABASE_URL || process.env.MYSQL_URL || process.env.JAWSDB_URL || '';
  /** @type {import('mysql2').PoolOptions | string} */
  let config;

  if (url) {
    // mysql://user:pass@host:port/db?ssl=true
    try {
      const u = new URL(url);
      const sslParam = u.searchParams.get('ssl');
      const sslEnabled = parseBool(sslParam, parseBool(process.env.MYSQL_SSL));
      config = {
        host: u.hostname,
        port: Number(u.port || 3306),
        user: decodeURIComponent(u.username || ''),
        password: decodeURIComponent(u.password || ''),
        database: (u.pathname || '').replace(/^\//, '') || undefined,
        waitForConnections: true,
        connectionLimit: Number(process.env.MYSQL_CONNECTION_LIMIT || 10),
        queueLimit: 0,
        dateStrings: true,
        multipleStatements: true,
        connectTimeout: Number(process.env.MYSQL_CONNECT_TIMEOUT || 10000),
        enableKeepAlive: true,
        keepAliveInitialDelay: Number(process.env.MYSQL_KEEPALIVE_DELAY || 1000),
        ...(sslEnabled && {
          ssl: {
            rejectUnauthorized: parseBool(process.env.MYSQL_SSL_REJECT_UNAUTHORIZED, false),
          },
        }),
        timezone: process.env.TIMEZONE || '+03:00',
      };
    } catch (_) {
      // If URL parsing fails, fall back to discrete env vars below
    }
  }

  if (!config) {
    config = {
      host: process.env.MYSQLHOST || process.env.DB_HOST || 'localhost',
      user: process.env.MYSQLUSER || process.env.DB_USER || 'root',
      password: process.env.MYSQLPASSWORD || process.env.DB_PASSWORD || '',
      database: process.env.MYSQLDATABASE || process.env.DB_NAME || 'retail_management',
      port: Number(process.env.MYSQLPORT || process.env.DB_PORT || 3306),
      waitForConnections: true,
      connectionLimit: Number(process.env.MYSQL_CONNECTION_LIMIT || 10),
      queueLimit: 0,
      dateStrings: true, // Return DATE/DATETIME/TIMESTAMP as strings
      multipleStatements: true,
      connectTimeout: Number(process.env.MYSQL_CONNECT_TIMEOUT || 10000),
      enableKeepAlive: true,
      keepAliveInitialDelay: Number(process.env.MYSQL_KEEPALIVE_DELAY || 1000),
      ...(parseBool(process.env.MYSQL_SSL) && {
        ssl: {
          rejectUnauthorized: parseBool(process.env.MYSQL_SSL_REJECT_UNAUTHORIZED, false),
        },
      }),
      timezone: process.env.TIMEZONE || '+03:00',
    };
  }
  return config;
}

function ensurePool() {
  if (!pool) {
    const cfg = buildPoolConfigFromEnv();
    pool = mysql.createPool(cfg);
  }
  return pool;
}

// Retry helper for transient network/DB startup issues (Railway cold starts etc.)
const TRANSIENT_CODES = new Set([
  'ECONNREFUSED',
  'PROTOCOL_CONNECTION_LOST',
  'ECONNRESET',
  'ETIMEDOUT',
  'EHOSTUNREACH',
  'ENOTFOUND',
]);

function isTransient(err) {
  if (!err) return false;
  if (err.code && TRANSIENT_CODES.has(err.code)) return true;
  const msg = String(err.message || '');
  if (/Server has gone away|Lost connection|This socket has been ended|read ECONNRESET|write ECONNRESET/i.test(msg)) return true;
  return false;
}

async function withRetry(fn, opts = {}) {
  const {
    retries = Number(process.env.DB_RETRY_ATTEMPTS || 8),
    minDelay = Number(process.env.DB_RETRY_MIN_DELAY_MS || 300),
    maxDelay = Number(process.env.DB_RETRY_MAX_DELAY_MS || 2000),
  } = opts;

  let attempt = 0;
  let lastErr;
  while (attempt <= retries) {
    try {
      return await fn();
    } catch (err) {
      lastErr = err;
      if (!isTransient(err) || attempt === retries) {
        throw err;
      }
      const backoff = Math.min(maxDelay, Math.floor(minDelay * Math.pow(1.6, attempt)));
      const jitter = Math.floor(Math.random() * Math.min(250, backoff));
      const delay = backoff + jitter;
      await new Promise((r) => setTimeout(r, delay));
      attempt += 1;
    }
  }
  throw lastErr;
}

async function query(sql, params = []) {
  const p = ensurePool();
  return withRetry(() => p.query(sql, params));
}

async function execute(sql, params = []) {
  const p = ensurePool();
  return withRetry(() => p.execute(sql, params));
}

async function getConnection() {
  const p = ensurePool();
  return withRetry(() => p.getConnection());
}

async function closePool(timeoutMs = 2000) {
  if (!pool) return;
  const p = pool;
  pool = null;
  try {
    await Promise.race([
      p.end(),
      new Promise((resolve) => setTimeout(resolve, timeoutMs)),
    ]);
  } catch (_) {}
}

module.exports = {
  query,
  execute,
  getConnection,
  closePool,
  getPool: ensurePool,
};
