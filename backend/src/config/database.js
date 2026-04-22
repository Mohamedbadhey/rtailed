const mysql = require('mysql2/promise');

// Helper to pick the first defined env var from a list
function pickEnv(keys, fallback) {
  for (const k of keys) {
    if (process.env[k] && String(process.env[k]).trim() !== '') return process.env[k];
  }
  return fallback;
}

// Parse MySQL-style URLs like mysql://user:pass@host:port/db
function parseMysqlUrl(u) {
  try {
    const p = new URL(u);
    return {
      host: p.hostname,
      port: p.port ? parseInt(p.port, 10) : 3306,
      user: decodeURIComponent(p.username || ''),
      password: decodeURIComponent(p.password || ''),
      database: p.pathname ? p.pathname.replace(/^\//, '') : undefined,
    };
  } catch (_) {
    return null;
  }
}

const urlEnv = pickEnv(['DATABASE_URL', 'JAWSDB_URL', 'CLEARDB_DATABASE_URL', 'MYSQL_PUBLIC_URL', 'MYSQL_URL'], null);
const parsed = urlEnv ? parseMysqlUrl(urlEnv) : null;

const host = (parsed && parsed.host) || pickEnv(['DB_HOST', 'MYSQLHOST', 'MYSQL_HOST'], 'localhost');
const port = (parsed && parsed.port) || parseInt(pickEnv(['DB_PORT', 'MYSQLPORT', 'MYSQL_PORT'], '3306'), 10);
const user = (parsed && parsed.user) || pickEnv(['DB_USER', 'MYSQLUSER', 'MYSQL_USER'], 'root');
const password = (parsed && parsed.password) || pickEnv(['DB_PASSWORD', 'MYSQLPASSWORD', 'MYSQL_PASSWORD'], '');
const database = (parsed && parsed.database) || pickEnv(['DB_NAME', 'MYSQLDATABASE', 'MYSQL_DATABASE'], 'retail_management');

// Optional: log resolved target (without sensitive values)
console.log(`🗄️ DB target => host=${host} port=${port} db=${database} user=${user}`);

const pool = mysql.createPool({
  host,
  port,
  user,
  password,
  database,
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0,
  dateStrings: true, // Return DATETIME as 'YYYY-MM-DD HH:mm:ss'
  multipleStatements: true,
  timezone: process.env.TIMEZONE || '+03:00',
  enableKeepAlive: true,
  keepAliveInitialDelay: 0,
  charset: 'utf8mb4',
});

module.exports = pool;
