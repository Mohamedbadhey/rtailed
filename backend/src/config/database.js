const dns = require('dns');
const mysql = require('mysql2/promise');

// Prefer IPv4 first to avoid IPv6-only endpoints causing ECONNREFUSED
try {
  if (typeof dns.setDefaultResultOrder === 'function') {
    dns.setDefaultResultOrder(process.env.DNS_RESULT_ORDER || 'ipv4first');
  }
} catch (_) {}

const toBool = (v, def = false) => {
  if (v === undefined) return def;
  return String(v).toLowerCase() === 'true' || v === '1';
};

const pool = mysql.createPool({
  host: process.env.MYSQLHOST || process.env.DB_HOST || 'localhost',
  user: process.env.MYSQLUSER || process.env.DB_USER || 'root',
  password: process.env.MYSQLPASSWORD || process.env.DB_PASSWORD || '',
  database: process.env.MYSQLDATABASE || process.env.DB_NAME || 'retail_management',
  port: Number(process.env.MYSQLPORT || process.env.DB_PORT || 3306),
  waitForConnections: true,
  connectionLimit: Number(process.env.MYSQL_CONNECTION_LIMIT || 10),
  queueLimit: 0,
  dateStrings: true, // Return DATE/DATETIME/TIMESTAMP as 'YYYY-MM-DD HH:mm:ss' strings (no TZ conversion)
  multipleStatements: true,
  connectTimeout: Number(process.env.MYSQL_CONNECT_TIMEOUT || 10000),
  // Optional TLS (for providers that require it). Enable by setting MYSQL_SSL=true.
  ...(toBool(process.env.MYSQL_SSL) && {
    ssl: {
      // By default, do not reject unknown CA unless explicitly requested
      rejectUnauthorized: toBool(process.env.MYSQL_SSL_REJECT_UNAUTHORIZED, false),
    },
  }),
  // Set timezone to match your local timezone (affects server-side functions like NOW())
  timezone: process.env.TIMEZONE || '+03:00',
});

// NOTE:
// - With dateStrings: true, MySQL DATETIME/TIMESTAMP values are not converted to JS Date objects,
//   preventing implicit UTC serialization. The API will return the exact DB string like 'YYYY-MM-DD HH:mm:ss'.
// - Keep timezone for server-side functions (e.g., NOW()) but it will not alter returned strings.

module.exports = pool;
